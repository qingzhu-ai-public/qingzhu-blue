import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { access, ble, constant } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { DEMO_SERVICE, DEMO_CHAR, measureCommand, parseBthome, displayReading, hexBytes,
  BthomeReading } from './BthomeProtocol';

// 教学 GATT 中心：扫描教学服务 → 连接 → 发现 → 写 01 → 读帧 → parseBthome。
// 串行 Promise 链：等上一步成功再发下一步（D4 串行规则）；迟到回调按会话编号丢弃（D8）。
// 对端可以是鸿蒙 SensorPeripheral、Android/iOS bthome-mvp 的模拟外设——三端互连。

export class ClientState {
  phase: string = 'idle';
  status: string = '点「开始扫描」查找教学外设';
  devices: ble.ScanResult[] = [];
  reading: string = '';
  raw: string = '';
}

export class SensorClient {
  private state: ClientState = new ClientState();
  private generation: number = 0;
  private timer: number = -1;
  private scanRegistered: boolean = false;
  private client?: ble.GattClientDevice;
  private connectionHandler?: (event: ble.BLEConnectionChangeState) => void;
  private characteristic?: ble.BLECharacteristic;
  private onUpdate: (state: ClientState) => void;

  constructor(onUpdate: (state: ClientState) => void) {
    this.onUpdate = onUpdate;
  }

  private emit(phase: string, status: string): void {
    this.state.phase = phase;
    this.state.status = status;
    const snapshot = new ClientState();
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
      if (i < 0) { this.state.devices.push(result); } else { this.state.devices[i] = result; }
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
      ble.startBLEScan([{ serviceUuid: DEMO_SERVICE }]);
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
    this.finishScan(); // 单路扫描：进连接流程前先 stopBLEScan（D4）
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

  private async discover(client: ble.GattClientDevice, run: number): Promise<void> {
    this.emit('discovering', '已连接，正在查找读写特征');
    this.deadline(run, 10000, '服务发现超时');
    try {
      const services = await client.getServices();
      if (run !== this.generation) { return; }
      const service = services.find((item: ble.GattService) => item.serviceUuid.toLowerCase() === DEMO_SERVICE);
      const target = service?.characteristics.find((item: ble.BLECharacteristic) =>
        item.characteristicUuid.toLowerCase() === DEMO_CHAR);
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
      const payload = new Uint8Array(response.characteristicValue);
      const reading: BthomeReading = parseBthome(payload);
      this.state.raw = hexBytes(payload);
      this.state.reading = displayReading(reading);
      this.clearTimer();
      this.emit('ready', '读数已更新');
    } catch (error) {
      if (run === this.generation) { this.fail('请求失败，阶段 ' + this.state.phase, error as BusinessError); }
    }
  }

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

  private stopScan(): void {
    if (!this.scanRegistered) { return; }
    this.scanRegistered = false;
    try { ble.stopBLEScan(); } catch (error) {
      console.warn('停止扫描失败 ' + (error as BusinessError).code);
    }
    try { ble.off('BLEDeviceFind', this.onDevices); } catch (error) {
      console.warn('注销扫描回调失败 ' + (error as BusinessError).code);
    }
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
      if (handler) {
        try { client.off('BLEConnectionStateChange', handler); } catch (error) {
          console.warn('注销连接回调失败 ' + (error as BusinessError).code);
        }
      }
      try { client.disconnect(); } catch (error) {
        console.warn('断开连接失败 ' + (error as BusinessError).code);
      }
      try { client.close(); } catch (error) {
        console.warn('关闭客户端失败 ' + (error as BusinessError).code);
      }
    }
    this.state = new ClientState();
    this.emit('idle', this.state.status);
  }

  private fail(message: string, error: BusinessError): void {
    this.stop();
    this.emit('idle', message + ' · ' + (error.code ? String(error.code) + ' ' : '') + error.message);
  }
}