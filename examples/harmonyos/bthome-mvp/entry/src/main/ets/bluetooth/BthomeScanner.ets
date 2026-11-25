import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { access, ble } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { BTHOME_UUID, BTHOME_UUID16, extractServiceData, parseBthome, displayReading, hexBytes,
  BthomeReading } from './BthomeProtocol';

// 接收器：只收 FCD2 服务数据广播，不连接。扫到即解码上屏；坏帧显示故障原因。
// 手解原始 AD（extractServiceData），API 10 起全版本可跑，不依赖 API 22 的 serviceDataMap。

export class SensorEntry {
  deviceId: string = '';
  rssi: number = 0;
  reading: string = '';
  raw: string = '';
  fault: string = '';
  lastSeen: number = 0;
  online: boolean = true;
}

export class ScannerState {
  phase: string = 'idle';
  status: string = '点「开始扫描」接收 BTHome 广播';
  devices: SensorEntry[] = [];
  frames: number = 0;
  badFrames: number = 0;
}

export class BthomeScanner {
  private state: ScannerState = new ScannerState();
  private generation: number = 0;
  private registered: boolean = false;
  private ticker: number = -1;
  private onUpdate: (state: ScannerState) => void;

  constructor(onUpdate: (state: ScannerState) => void) {
    this.onUpdate = onUpdate;
  }

  private emit(phase: string, status: string): void {
    this.state.phase = phase;
    this.state.status = status;
    const snapshot = new ScannerState();
    snapshot.phase = phase;
    snapshot.status = status;
    snapshot.devices = this.state.devices.slice();
    snapshot.frames = this.state.frames;
    snapshot.badFrames = this.state.badFrames;
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
    const now = Date.now();
    results.forEach((result: ble.ScanResult) => {
      const payload = extractServiceData(result.data, BTHOME_UUID16);
      if (payload === null) { return; } // 不是 FCD2 服务数据，忽略
      this.state.frames++;
      const entry = new SensorEntry();
      entry.deviceId = result.deviceId;
      entry.rssi = result.rssi;
      entry.raw = hexBytes(payload);
      entry.lastSeen = now;
      entry.online = true;
      try {
        const reading: BthomeReading = parseBthome(payload);
        entry.reading = displayReading(reading);
      } catch (error) {
        // 坏帧：显示故障原因，不硬显示数字（D9 验收第 6 项）
        this.state.badFrames++;
        entry.fault = (error as Error).message;
      }
      // 按 deviceId 会话内合并；虚拟 MAC 别持久化（D3）
      const i = this.state.devices.findIndex((item: SensorEntry) => item.deviceId === result.deviceId);
      if (i < 0) { this.state.devices.push(entry); } else { this.state.devices[i] = entry; }
    });
    this.emit('scanning', '正在接收 FCD2 广播');
  };

  async start(context: common.UIAbilityContext): Promise<void> {
    const run = await this.prepare(context);
    if (run < 0 || run !== this.generation) { return; }
    try {
      ble.on('BLEDeviceFind', this.onDevices);
      this.registered = true;
      this.emit('scanning', '正在接收 FCD2 广播');
      ble.startBLEScan([{ serviceUuid: BTHOME_UUID }]);
      this.ticker = setInterval(() => { this.markOffline(); }, 1000);
    } catch (error) {
      this.fail('扫描启动失败', error as BusinessError);
    }
  }

  private markOffline(): void {
    if (this.state.phase !== 'scanning') { return; }
    const now = Date.now();
    let changed = false;
    this.state.devices.forEach((entry: SensorEntry) => {
      if (entry.online && now - entry.lastSeen > 10000) {
        entry.online = false;
        changed = true;
      }
    });
    if (changed) { this.emit('scanning', '正在接收 FCD2 广播'); }
  }

  stop(): void {
    this.generation++;
    if (this.ticker >= 0) { clearInterval(this.ticker); this.ticker = -1; }
    if (this.registered) {
      this.registered = false;
      try { ble.stopBLEScan(); } catch (error) {
        console.warn('停止扫描失败 ' + (error as BusinessError).code);
      }
      try { ble.off('BLEDeviceFind', this.onDevices); } catch (error) {
        console.warn('注销扫描回调失败 ' + (error as BusinessError).code);
      }
    }
    this.state = new ScannerState();
    this.emit('idle', this.state.status);
  }

  private fail(message: string, error: BusinessError): void {
    this.stop();
    this.emit('idle', message + ' · ' + (error.code ? String(error.code) + ' ' : '') + error.message);
  }
}