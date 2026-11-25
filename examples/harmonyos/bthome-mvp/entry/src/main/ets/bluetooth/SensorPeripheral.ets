import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { access, ble } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { DEMO_SERVICE, DEMO_CHAR, demoFrame, hexBytes } from './BthomeProtocol';

// 教学 GATT 从端：写 01 换温度（25.00 ↔ 26.50 交替），读特征回 BTHome 格式帧。
// 服务/特征 UUID 与 Android/iOS bthome-mvp 一致：鸿蒙从端可被 Android/iPhone 连接，反之亦然。
// 这是教学协议（非 BTHome 标准）；要当标准 BTHome 广播源用 BthomeAdvertiser。

export class PeripheralState {
  phase: string = 'idle';
  status: string = '点「启动广播」让另一台手机连接';
  temperature: number = 2500;
  frameHex: string = '40 02 C4 09 03 BF 13';
  writes: number = 0;
}

export class SensorPeripheral {
  private state: PeripheralState = new PeripheralState();
  private generation: number = 0;
  private server?: ble.GattServer;
  private advertising: boolean = false;
  private onUpdate: (state: PeripheralState) => void;

  constructor(onUpdate: (state: PeripheralState) => void) {
    this.onUpdate = onUpdate;
  }

  private emit(phase: string, status: string): void {
    this.state.phase = phase;
    this.state.status = status;
    const snapshot = new PeripheralState();
    snapshot.phase = phase;
    snapshot.status = status;
    snapshot.temperature = this.state.temperature;
    snapshot.frameHex = hexBytes(new Uint8Array(demoFrame(this.state.temperature)));
    snapshot.writes = this.state.writes;
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

  async start(context: common.UIAbilityContext): Promise<void> {
    const run = await this.prepare(context);
    if (run < 0 || run !== this.generation) { return; }
    this.state.temperature = 2500;
    this.state.writes = 0;
    try {
      const server = ble.createGattServer();
      this.server = server;
      const characteristic: ble.BLECharacteristic = {
        serviceUuid: DEMO_SERVICE, characteristicUuid: DEMO_CHAR,
        characteristicValue: demoFrame(this.state.temperature),
        descriptors: [], properties: { read: true, write: true }
      };
      const service: ble.GattService = {
        serviceUuid: DEMO_SERVICE, isPrimary: true, characteristics: [characteristic], includeServices: []
      };
      server.on('characteristicWrite', this.onWrite);
      server.on('characteristicRead', this.onRead);
      server.addService(service);
      ble.startAdvertising({ interval: 160, txPower: 0, connectable: true },
        { serviceUuids: [DEMO_SERVICE], manufactureData: [], serviceData: [], includeDeviceName: false });
      this.advertising = true;
      this.emit('peripheral', '已发起广播，请用另一台手机扫描连接');
    } catch (error) {
      this.fail('外设启动失败', error as BusinessError);
    }
  }

  private onWrite = (request: ble.CharacteristicWriteRequest): void => {
    const server = this.server;
    if (!server || !request.needRsp) { return; }
    const value = new Uint8Array(request.value);
    const matches = request.characteristicUuid.toLowerCase() === DEMO_CHAR;
    let status = 0;
    if (!matches || request.isPrepared) { status = 6; }
    else if (request.offset !== 0) { status = 7; }
    else if (value.length !== 1 || value[0] !== 1) { status = 13; }
    else {
      // 收到 01：温度交替 25.00 / 26.50（D9 验收第 5 项）
      this.state.temperature = this.state.temperature === 2500 ? 2650 : 2500;
      this.state.writes++;
    }
    try {
      server.sendResponse({ deviceId: request.deviceId, transId: request.transId,
        status: status, offset: request.offset, value: new ArrayBuffer(0) });
      this.emit('peripheral', status === 0 ? '收到 01，已准备新读数' : '写请求未通过检查');
    } catch (error) {
      this.fail('回应写请求失败', error as BusinessError);
    }
  };

  private onRead = (request: ble.CharacteristicReadRequest): void => {
    const server = this.server;
    if (!server) { return; }
    const value = demoFrame(this.state.temperature);
    const status = request.characteristicUuid.toLowerCase() !== DEMO_CHAR ? 2 :
      (request.offset < 0 || request.offset > value.byteLength ? 7 : 0);
    try {
      server.sendResponse({ deviceId: request.deviceId, transId: request.transId, status: status,
        offset: request.offset, value: status === 0 ? value.slice(request.offset) : new ArrayBuffer(0) });
      if (status === 0) {
        this.emit('peripheral', '已返回 ' + hexBytes(new Uint8Array(value)));
      }
    } catch (error) {
      this.fail('回应读请求失败', error as BusinessError);
    }
  };

  stop(): void {
    this.generation++;
    if (this.advertising) {
      this.advertising = false;
      try { ble.stopAdvertising(); } catch (error) {
        console.warn('停止广播失败 ' + (error as BusinessError).code);
      }
    }
    const server = this.server;
    this.server = undefined;
    if (server) {
      try { server.off('characteristicWrite', this.onWrite); } catch (error) {
        console.warn('注销写回调失败 ' + (error as BusinessError).code);
      }
      try { server.off('characteristicRead', this.onRead); } catch (error) {
        console.warn('注销读回调失败 ' + (error as BusinessError).code);
      }
      try { server.close(); } catch (error) {
        console.warn('关闭 GATT 服务失败 ' + (error as BusinessError).code);
      }
    }
    this.state = new PeripheralState();
    this.emit('idle', this.state.status);
  }

  private fail(message: string, error: BusinessError): void {
    this.stop();
    this.emit('idle', message + ' · ' + (error.code ? String(error.code) + ' ' : '') + error.message);
  }
}