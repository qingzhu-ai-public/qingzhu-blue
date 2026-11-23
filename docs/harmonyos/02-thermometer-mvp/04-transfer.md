---
title: 传输篇　写 01，再把回包变成温湿度
slug: transfer
order: 40
---

# 传输篇　写 01，再把回包变成温湿度

A 点「请求新读数」，第一次预期显示 26.50 °C、50.55% RH 和完整原始字节。

## 本篇完整代码

按文件名展开。 [跳到讲解](#walkthrough)

<details>
<summary>Index.ets</summary>

[打开工程源码](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/harmonyos/thermometer-mvp/entry/src/main/ets/pages/Index.ets)

```typescript
import { common } from '@kit.AbilityKit';
import { ble } from '@kit.ConnectivityKit';
import { BleSession, WorkshopState } from '../bluetooth/BleSession';

@Entry
@Component
struct Index {
  @State private model: WorkshopState = new WorkshopState();
  @State private peripheralMode: boolean = false;
  private session: BleSession = new BleSession((snapshot: WorkshopState) => {
    this.model = snapshot;
  });

  onPageHide(): void {
    this.session.stop();
  }

  private begin(asPeripheral: boolean): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!context) { return; }
    if (asPeripheral) { this.session.startPeripheral(context); }
    else { this.session.scan(context); }
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Text(this.peripheralMode ? '模拟温湿度计' : '蓝牙温湿度计')
          .fontSize(28).fontWeight(FontWeight.Bold)
        Text(this.model.status).fontSize(15).fontColor('#476355')
        if (this.peripheralMode) {
          Button(this.model.phase === 'peripheral' ? '停止广播' : '启动广播')
            .enabled(this.model.phase !== 'permission')
            .onClick(() => {
              if (this.model.phase === 'peripheral') { this.session.stop(); }
              else { this.begin(true); }
            })
          Button('返回列表').onClick(() => {
            this.session.stop();
            this.peripheralMode = false;
          })
        } else if (this.model.phase === 'connecting' || this.model.phase === 'discovering' ||
          this.model.phase === 'ready' || this.model.phase === 'writing' || this.model.phase === 'reading') {
          Text(this.model.reading || '等待测量').fontSize(26)
          Text(this.model.raw).fontSize(15)
          Button('请求新读数').enabled(this.model.phase === 'ready').onClick(() => {
            this.session.requestReading();
          })
          Button('返回列表').onClick(() => { this.session.stop(); })
        } else {
          Button(this.model.phase === 'scanning' ? '停止扫描' : '开始扫描')
            .enabled(this.model.phase !== 'permission')
            .onClick(() => {
              if (this.model.phase === 'scanning') { this.session.finishScan(); }
              else { this.begin(false); }
            })
          ForEach(this.model.devices, (device: ble.ScanResult) => {
            Button('教学温湿度计 · ' + device.rssi + ' dBm')
              .onClick(() => { this.session.connect(device.deviceId); })
          }, (device: ble.ScanResult): string => device.deviceId)
          Button('模拟温湿度计').enabled(this.model.phase !== 'permission').onClick(() => {
            this.session.stop();
            this.peripheralMode = true;
          })
        }
      }
      .width('100%')
      .padding(24)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F8F4')
  }
}
```

</details>

<details>
<summary>BleSession.ets</summary>

[打开工程源码](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/harmonyos/thermometer-mvp/entry/src/main/ets/bluetooth/BleSession.ets)

```typescript
import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { access, ble, constant } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { SERVICE, SAMPLE, measureCommand, decodeFrame, hexFrame, sampleFrame } from './SensorFrame';

export class WorkshopState {
  status: string = '点「开始扫描」查找教学外设';
  phase: string = 'idle';
  devices: ble.ScanResult[] = [];
  reading: string = '';
  raw: string = '';
}

export class BleSession {
  private state: WorkshopState = new WorkshopState();
  private generation: number = 0;
  private timer: number = -1;
  private scanRegistered: boolean = false;
  private client?: ble.GattClientDevice;
  private connectionHandler?: (event: ble.BLEConnectionChangeState) => void;
  private server?: ble.GattServer;
  private advertising: boolean = false;
  private temperature: number = 2500;
  private onUpdate: (state: WorkshopState) => void;

  constructor(onUpdate: (state: WorkshopState) => void) {
    this.onUpdate = onUpdate;
  }

  private emit(phase: string, status: string): void {
    this.state.phase = phase;
    this.state.status = status;
    const snapshot = new WorkshopState();
    snapshot.phase = phase;
    snapshot.status = status;
    snapshot.devices = this.state.devices.slice();
    snapshot.reading = this.state.reading;
    snapshot.raw = this.state.raw;
    this.onUpdate(snapshot);
  }

  private async authorize(context: common.UIAbilityContext): Promise<boolean> {
    const manager = abilityAccessCtrl.createAtManager();
    const result = await manager.requestPermissionsFromUser(context, ['ohos.permission.ACCESS_BLUETOOTH']);
    return result.authResults[0] === 0;
  }

  private async prepare(context: common.UIAbilityContext): Promise<number> {
    this.stop();
    const run = this.generation;
    this.emit('permission', '正在检查蓝牙权限');
    try {
      const granted = await this.authorize(context);
      if (run !== this.generation) { return -1; }
      if (!granted) {
        this.emit('idle', '请在系统设置中允许本应用使用蓝牙');
        return -1;
      }
      if (access.getState() !== access.BluetoothState.STATE_ON) {
        this.emit('idle', '请在系统设置打开蓝牙后重试');
        return -1;
      }
      return run;
    } catch (error) {
      if (run === this.generation) { this.fail('检查权限失败', error as BusinessError); }
      return -1;
    }
  }

  private onDevices = (results: ble.ScanResult[]): void => {
    if (this.state.phase !== 'scanning') { return; }
    results.forEach((result: ble.ScanResult) => {
      const i = this.state.devices.findIndex((item: ble.ScanResult) => item.deviceId === result.deviceId);
      if (i < 0) { this.state.devices.push(result); }
      else { this.state.devices[i] = result; }
    });
    this.emit('scanning', '正在扫描，点选设备可连接');
  };

  async scan(context: common.UIAbilityContext): Promise<void> {
    const run = await this.prepare(context);
    if (run < 0 || run !== this.generation) { return; }
    try {
      ble.on('BLEDeviceFind', this.onDevices);
      this.scanRegistered = true;
      this.emit('scanning', '正在扫描教学设备');
      ble.startBLEScan([{ serviceUuid: SERVICE }]);
      this.timer = setTimeout(() => { this.finishScan(); }, 12000);
    } catch (error) {
      this.fail('扫描启动失败', error as BusinessError);
    }
  }

  finishScan(): void {
    if (this.state.phase !== 'scanning') { return; }
    this.clearTimer();
    this.stopScan();
    this.emit('picking', this.state.devices.length > 0 ? '扫描结束，可以选择设备' : '没有找到教学设备');
  }

  connect(deviceId: string): void {
    if (this.state.phase !== 'scanning' && this.state.phase !== 'picking') { return; }
    this.finishScan();
    const run = this.generation;
    try {
      const client = ble.createGattClientDevice(deviceId);
      this.client = client;
      this.connectionHandler = (event: ble.BLEConnectionChangeState): void => {
        if (run !== this.generation || event.deviceId !== deviceId) { return; }
        if (event.state === constant.ProfileConnectionState.STATE_CONNECTED && this.state.phase === 'connecting') {
          this.clearTimer();
          this.discover(client, run);
        } else if (event.state === constant.ProfileConnectionState.STATE_DISCONNECTED) {
          this.stop();
          this.emit('idle', '设备已断开，请重新扫描');
        }
      };
      client.on('BLEConnectionStateChange', this.connectionHandler);
      this.emit('connecting', '正在连接教学设备');
      client.connect();
      this.deadline(run, 12000, '连接等待超时，请重新扫描');
    } catch (error) {
      this.fail('发起连接失败', error as BusinessError);
    }
  }

  private characteristic?: ble.BLECharacteristic;

  private async discover(client: ble.GattClientDevice, run: number): Promise<void> {
    this.emit('discovering', '已连接，正在查找读写特征');
    this.deadline(run, 10000, '服务发现超时');
    try {
      const services = await client.getServices();
      if (run !== this.generation) { return; }
      const service = services.find((item: ble.GattService) => item.serviceUuid.toLowerCase() === SERVICE);
      const target = service?.characteristics.find((item: ble.BLECharacteristic) =>
        item.characteristicUuid.toLowerCase() === SAMPLE);
      this.clearTimer();
      if (!target) {
        this.stop();
        this.emit('idle', '找不到教学特征，请核对外设协议');
        return;
      }
      this.characteristic = target;
      this.emit('ready', '已就绪，可以请求新读数');
    } catch (error) {
      if (run === this.generation) { this.fail('服务发现失败', error as BusinessError); }
    }
  }

  async requestReading(): Promise<void> {
    const client = this.client;
    const target = this.characteristic;
    if (this.state.phase !== 'ready' || !client || !target) { return; }
    const run = this.generation;
    const command: ble.BLECharacteristic = {
      serviceUuid: target.serviceUuid,
      characteristicUuid: target.characteristicUuid,
      characteristicValue: measureCommand(),
      descriptors: []
    };
    try {
      this.emit('writing', '正在写入 01');
      this.deadline(run, 10000, '写入超时');
      await client.writeCharacteristicValue(command, ble.GattWriteType.WRITE);
      if (run !== this.generation) { return; }
      this.emit('reading', '写入成功，正在读取');
      this.deadline(run, 10000, '读取超时');
      const response = await client.readCharacteristicValue(target);
      if (run !== this.generation) { return; }
      const reading = decodeFrame(response.characteristicValue);
      this.state.raw = hexFrame(response.characteristicValue);
      this.state.reading = reading;
      this.clearTimer();
      this.emit('ready', '读数已更新');
    } catch (error) {
      if (run === this.generation) { this.fail('请求失败，阶段 ' + this.state.phase, error as BusinessError); }
    }
  }

  async startPeripheral(context: common.UIAbilityContext): Promise<void> {
    const run = await this.prepare(context);
    if (run < 0 || run !== this.generation) { return; }
    this.temperature = 2500;
    try {
      const server = ble.createGattServer();
      this.server = server;
      const characteristic: ble.BLECharacteristic = {
        serviceUuid: SERVICE, characteristicUuid: SAMPLE, characteristicValue: sampleFrame(2500),
        descriptors: [], properties: { read: true, write: true }
      };
      const service: ble.GattService = {
        serviceUuid: SERVICE, isPrimary: true, characteristics: [characteristic], includeServices: []
      };
      server.on('characteristicWrite', this.onWrite);
      server.on('characteristicRead', this.onRead);
      server.addService(service);
      ble.startAdvertising({ interval: 160, txPower: 0, connectable: true },
        { serviceUuids: [SERVICE], manufactureData: [], serviceData: [], includeDeviceName: false });
      this.advertising = true;
      this.emit('peripheral', '已发起广播，请用另一台手机扫描');
    } catch (error) {
      this.fail('外设启动失败', error as BusinessError);
    }
  }

  private onWrite = (request: ble.CharacteristicWriteRequest): void => {
    const server = this.server;
    if (!server || !request.needRsp) { return; }
    const value = new Uint8Array(request.value);
    const matches = request.characteristicUuid.toLowerCase() === SAMPLE;
    let status = 0;
    if (!matches || request.isPrepared) { status = 6; }
    else if (request.offset !== 0) { status = 7; }
    else if (value.length !== 1 || value[0] !== 1) { status = 13; }
    else { this.temperature = this.temperature === 2500 ? 2650 : 2500; }
    try {
      server.sendResponse({ deviceId: request.deviceId, transId: request.transId,
        status: status, offset: request.offset, value: new ArrayBuffer(0) });
      this.emit('peripheral', status === 0 ? '收到 01，已准备读数' : '写请求未通过检查');
    } catch (error) {
      this.fail('回应写请求失败', error as BusinessError);
    }
  };

  private onRead = (request: ble.CharacteristicReadRequest): void => {
    const server = this.server;
    if (!server) { return; }
    const value = sampleFrame(this.temperature);
    const status = request.characteristicUuid.toLowerCase() !== SAMPLE ? 2 :
      (request.offset < 0 || request.offset > value.byteLength ? 7 : 0);
    try {
      server.sendResponse({ deviceId: request.deviceId, transId: request.transId, status: status,
        offset: request.offset, value: status === 0 ? value.slice(request.offset) : new ArrayBuffer(0) });
      if (status === 0) { this.emit('peripheral', '已返回 ' + hexFrame(value)); }
    } catch (error) {
      this.fail('回应读请求失败', error as BusinessError);
    }
  };

  private deadline(run: number, delay: number, message: string): void {
    this.clearTimer();
    this.timer = setTimeout(() => {
      if (run === this.generation) {
        this.stop();
        this.emit('idle', message);
      }
    }, delay);
  }

  private clearTimer(): void {
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
  }

  private cleanup(action: () => void): void {
    try { action(); } catch (error) {
      console.warn('清理蓝牙资源失败 ' + (error as BusinessError).code);
    }
  }

  private stopScan(): void {
    if (!this.scanRegistered) { return; }
    this.scanRegistered = false;
    this.cleanup(() => { ble.stopBLEScan(); });
    this.cleanup(() => { ble.off('BLEDeviceFind', this.onDevices); });
  }

  stop(): void {
    this.generation++;
    this.clearTimer();
    this.stopScan();
    const client = this.client;
    const handler = this.connectionHandler;
    this.client = undefined;
    this.connectionHandler = undefined;
    this.characteristic = undefined;
    if (client) {
      if (handler) { this.cleanup(() => { client.off('BLEConnectionStateChange', handler); }); }
      this.cleanup(() => { client.disconnect(); });
      this.cleanup(() => { client.close(); });
    }
    if (this.advertising) {
      this.advertising = false;
      this.cleanup(() => { ble.stopAdvertising(); });
    }
    const server = this.server;
    this.server = undefined;
    if (server) {
      this.cleanup(() => { server.off('characteristicWrite', this.onWrite); });
      this.cleanup(() => { server.off('characteristicRead', this.onRead); });
      this.cleanup(() => { server.close(); });
    }
    this.state = new WorkshopState();
    this.emit('idle', this.state.status);
  }

  private fail(message: string, error: BusinessError): void {
    this.stop();
    this.emit('idle', message + ' · ' + (error.code ? String(error.code) + ' ' : '') + error.message);
  }
}
```

</details>

<details>
<summary>SensorFrame.ets</summary>

[打开工程源码](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/harmonyos/thermometer-mvp/entry/src/main/ets/bluetooth/SensorFrame.ets)

```typescript
export const SERVICE: string = '476cdf45-6063-43a1-b8e2-8c1fbed00601';
export const SAMPLE: string = '476cdf45-6063-43a1-b8e2-8c1fbed00602';

export function measureCommand(): ArrayBuffer {
  return new Uint8Array([0x01]).buffer;
}

export function sampleFrame(temperature: number): ArrayBuffer {
  return new Uint8Array([0x40, 0x02, temperature & 0xff, (temperature >> 8) & 0xff,
    0x03, 0xbf, 0x13]).buffer;
}

export function decodeFrame(value: ArrayBuffer): string {
  const data = new Uint8Array(value);
  if (data.length !== 7 || data[0] !== 0x40 || data[1] !== 0x02 || data[4] !== 0x03) {
    throw new Error('回包格式不符');
  }
  const view = new DataView(value);
  const temperature = view.getInt16(2, true) / 100;
  const humidity = view.getUint16(5, true) / 100;
  return temperature.toFixed(2) + ' °C · ' + humidity.toFixed(2) + '% RH';
}

export function hexFrame(value: ArrayBuffer): string {
  return Array.from(new Uint8Array(value)).map((b: number) =>
    b.toString(16).padStart(2, '0').toUpperCase()).join(' ');
}
```

</details>

<a id="walkthrough"></a>

## 对着代码讲重点

写 01 → B 切换模拟温度并回应 → A 发起读取 → 按约定拆出温湿度。

### A 发给 B 的是哪一条指令

`measureCommand()` 生成单字节 `01`，放进 `command.characteristicValue`。指定相同的服务和特征 UUID，然后调用有响应写。等待 `writeCharacteristicValue` 的 Promise 完成后，再调用 `readCharacteristicValue`。按钮在 writing 和 reading 阶段保持禁用。

### B 收到指令后怎样回

`onWrite` 核对目标、偏移、写类型与命令值，保存新的模拟温度。对于需要回应的请求，`sendResponse` 使用这个请求的 deviceId 和 transId。`onRead` 随后将温湿度按协议编码，用同样的响应接口交给 A。

### 从 5A 0A 算出 26.50

`40 02 5A 0A 03 BF 13` 是首次读取预期的内容。`5A 0A` 是低字节在前的 2650。`decodeFrame` 用 DataView 读取有符号温度，无符号湿度分别除以 100。先验字段和长度，通过后才更新读数与原始字节。

**动手试一次**　只在 B 把 2650 改成 2700 后重跑。确认 A 显示 27.00 °C，字节变成 8C 0A。

**一句话记住**　等写回应再读，按双方约定把字节换成数字。

**自查题**　Promise 已经完成但结果仍为空怎么办？先分清完成的是写还是读，再检查读结果的字节和格式。

继续读[双机验收篇](#harmonyos/thermometer-mvp/two-phone-check)。
