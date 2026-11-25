import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { access, ble } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { BTHOME_UUID, encodeBthome, hexBytes } from './BthomeProtocol';

// 广播源：鸿蒙能发真的 BTHome——AdvertiseData.serviceData（API 10）。
// iOS 的 startAdvertising 只支持名字和服务 UUID，发不出服务数据；这是鸿蒙的角色优势。
// 用 API 10 同步重载 startAdvertising(setting, advData)，配同步 stopAdvertising()，不与 API 11 混用。

export class AdvertiserState {
  phase: string = 'idle';
  status: string = '设定读数后点「开始广播」';
  temperature: number = 25.0;
  humidity: number = 50.55;
  frameHex: string = '40 02 C4 09 03 BF 13';
  budget: number = 18;
}

export class BthomeAdvertiser {
  private state: AdvertiserState = new AdvertiserState();
  private generation: number = 0;
  private advertising: boolean = false;
  private onUpdate: (state: AdvertiserState) => void;

  constructor(onUpdate: (state: AdvertiserState) => void) {
    this.onUpdate = onUpdate;
  }

  private emit(phase: string, status: string): void {
    this.state.phase = phase;
    this.state.status = status;
    const snapshot = new AdvertiserState();
    snapshot.phase = phase;
    snapshot.status = status;
    snapshot.temperature = this.state.temperature;
    snapshot.humidity = this.state.humidity;
    snapshot.frameHex = this.state.frameHex;
    snapshot.budget = this.state.budget;
    this.onUpdate(snapshot);
  }

  private paintFrame(): void {
    const frame = encodeBthome(this.state.temperature, this.state.humidity);
    this.state.frameHex = hexBytes(frame);
    // Flags 3 + UUID 列表 4 + 服务数据（len+type 2 + UUID 2 + 载荷）
    this.state.budget = 3 + 4 + (2 + 2 + frame.length);
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

  private broadcast(): void {
    const frame = encodeBthome(this.state.temperature, this.state.humidity);
    const serviceData: ble.ServiceData = { serviceUuid: BTHOME_UUID, serviceValue: frame.buffer as ArrayBuffer };
    const setting: ble.AdvertiseSetting = { interval: 1600, txPower: -7, connectable: false };
    const data: ble.AdvertiseData = {
      serviceUuids: [BTHOME_UUID], manufactureData: [], serviceData: [serviceData],
      includeDeviceName: false
    };
    ble.startAdvertising(setting, data);
    this.advertising = true;
    this.paintFrame();
  }

  async start(context: common.UIAbilityContext): Promise<void> {
    const run = await this.prepare(context);
    if (run < 0 || run !== this.generation) { return; }
    try {
      this.broadcast();
      // connectable=false：纯传感器不需要连接，省电防误连；interval 1600 slot = 1s
      this.emit('advertising', '正在广播 BTHome 帧（不可连接）');
    } catch (error) {
      this.fail('广播启动失败', error as BusinessError);
    }
  }

  // 更新读数：stopAdvertising → 改 frame → startAdvertising（D9 第 6 步）
  setReadings(temperature: number, humidity: number): void {
    this.state.temperature = temperature;
    this.state.humidity = humidity;
    if (!this.advertising) {
      this.paintFrame();
      this.emit('idle', '设定读数后点「开始广播」');
      return;
    }
    try {
      ble.stopAdvertising();
      this.advertising = false;
      this.broadcast();
      this.emit('advertising', '读数已更新并重新广播');
    } catch (error) {
      this.fail('更新广播失败', error as BusinessError);
    }
  }

  stop(): void {
    this.generation++;
    if (this.advertising) {
      this.advertising = false;
      try { ble.stopAdvertising(); } catch (error) {
        console.warn('停止广播失败 ' + (error as BusinessError).code);
      }
    }
    // 保留滑杆读数：停止/重启广播不重置用户设定
    const temperature = this.state.temperature;
    const humidity = this.state.humidity;
    this.state = new AdvertiserState();
    this.state.temperature = temperature;
    this.state.humidity = humidity;
    this.paintFrame();
    this.emit('idle', this.state.status);
  }

  private fail(message: string, error: BusinessError): void {
    this.stop();
    this.emit('idle', message + ' · ' + (error.code ? String(error.code) + ' ' : '') + error.message);
  }
}