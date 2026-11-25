import { common } from '@kit.AbilityKit';
import { ble } from '@kit.ConnectivityKit';
import { BthomeScanner, ScannerState, SensorEntry } from '../bluetooth/BthomeScanner';
import { BthomeAdvertiser, AdvertiserState } from '../bluetooth/BthomeAdvertiser';
import { SensorPeripheral, PeripheralState } from '../bluetooth/SensorPeripheral';
import { SensorClient, ClientState } from '../bluetooth/SensorClient';
import { selfTest } from '../bluetooth/BthomeProtocol';

// 四个角色页 + 协议自检面板。同一时刻只跑一个角色（单射频，D4）；切页即停上一个会话。
@Entry
@Component
struct Index {
  @State private role: string = 'scanner';
  @State private scannerModel: ScannerState = new ScannerState();
  @State private advertiserModel: AdvertiserState = new AdvertiserState();
  @State private peripheralModel: PeripheralState = new PeripheralState();
  @State private clientModel: ClientState = new ClientState();
  @State private report: string[] = [];
  @State private tempC: number = 2500;
  @State private humC: number = 5055;
  private scanner: BthomeScanner = new BthomeScanner((snapshot: ScannerState) => {
    this.scannerModel = snapshot;
  });
  private advertiser: BthomeAdvertiser = new BthomeAdvertiser((snapshot: AdvertiserState) => {
    this.advertiserModel = snapshot;
  });
  private peripheral: SensorPeripheral = new SensorPeripheral((snapshot: PeripheralState) => {
    this.peripheralModel = snapshot;
  });
  private client: SensorClient = new SensorClient((snapshot: ClientState) => {
    this.clientModel = snapshot;
  });

  onPageHide(): void {
    this.stopAll();
  }

  private stopAll(): void {
    this.scanner.stop();
    this.advertiser.stop();
    this.peripheral.stop();
    this.client.stop();
  }

  private switchRole(next: string): void {
    if (this.role === next) { return; }
    this.stopAll();
    this.role = next;
  }

  private context(): common.UIAbilityContext | undefined {
    return this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
  }

  @Builder
  roleTabs() {
    Row({ space: 8 }) {
      Button('接收器').fontSize(13).backgroundColor(this.role === 'scanner' ? '#E8590C' : '#EADFD3')
        .fontColor(this.role === 'scanner' ? '#FFFFFF' : '#7C7166')
        .onClick(() => { this.switchRole('scanner'); })
      Button('广播源').fontSize(13).backgroundColor(this.role === 'advertiser' ? '#E8590C' : '#EADFD3')
        .fontColor(this.role === 'advertiser' ? '#FFFFFF' : '#7C7166')
        .onClick(() => { this.switchRole('advertiser'); })
      Button('教学从端').fontSize(13).backgroundColor(this.role === 'peripheral' ? '#E8590C' : '#EADFD3')
        .fontColor(this.role === 'peripheral' ? '#FFFFFF' : '#7C7166')
        .onClick(() => { this.switchRole('peripheral'); })
      Button('教学中心').fontSize(13).backgroundColor(this.role === 'client' ? '#E8590C' : '#EADFD3')
        .fontColor(this.role === 'client' ? '#FFFFFF' : '#7C7166')
        .onClick(() => { this.switchRole('client'); })
      Button('自检').fontSize(13).backgroundColor(this.role === 'selftest' ? '#E8590C' : '#EADFD3')
        .fontColor(this.role === 'selftest' ? '#FFFFFF' : '#7C7166')
        .onClick(() => { this.switchRole('selftest'); })
    }
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Text('BTHome 温湿度计 · 鸿蒙').fontSize(26).fontWeight(FontWeight.Bold)
        this.roleTabs()
        if (this.role === 'scanner') {
          Text(this.scannerModel.status).fontSize(15).fontColor('#476355')
          Button(this.scannerModel.phase === 'scanning' ? '停止扫描' : '开始扫描')
            .enabled(this.scannerModel.phase !== 'permission')
            .onClick(() => {
              if (this.scannerModel.phase === 'scanning') { this.scanner.stop(); }
              else {
                const context = this.context();
                if (context) { this.scanner.start(context); }
              }
            })
          Text('好帧 ' + this.scannerModel.frames + ' · 坏帧 ' + this.scannerModel.badFrames)
            .fontSize(13).fontColor('#7C7166')
          ForEach(this.scannerModel.devices, (entry: SensorEntry) => {
            Column({ space: 4 }) {
              Text(entry.deviceId + (entry.online ? '' : '（离线）')).fontSize(13).fontColor('#7C7166')
              Text(entry.fault ? '故障：' + entry.fault : entry.reading)
                .fontSize(19).fontWeight(FontWeight.Bold)
                .fontColor(entry.fault ? '#B04A35' : '#1E7268')
              Text(entry.raw + ' · ' + entry.rssi + ' dBm').fontSize(12).fontColor('#A79B8D')
            }
            .width('100%').padding(12).backgroundColor('#FFFFFF').borderRadius(12)
            .alignItems(HorizontalAlign.Start)
          }, (entry: SensorEntry): string => entry.deviceId)
        } else if (this.role === 'advertiser') {
          Text(this.advertiserModel.status).fontSize(15).fontColor('#476355')
          Text('温度 ' + (this.tempC / 100).toFixed(2) + ' °C').fontSize(15)
          Slider({ value: this.tempC, min: -4000, max: 8500, step: 50 })
            .onChange((value: number, mode: SliderChangeMode) => {
              this.tempC = value;
              if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                this.advertiser.setReadings(this.tempC / 100, this.humC / 100);
              }
            })
          Text('湿度 ' + (this.humC / 100).toFixed(2) + ' %').fontSize(15)
          Slider({ value: this.humC, min: 0, max: 10000, step: 5 })
            .onChange((value: number, mode: SliderChangeMode) => {
              this.humC = value;
              if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                this.advertiser.setReadings(this.tempC / 100, this.humC / 100);
              }
            })
          Text('当前帧 ' + this.advertiserModel.frameHex).fontSize(14).fontFamily('monospace')
          Text('广播预算 ' + this.advertiserModel.budget + ' / 31 字节')
            .fontSize(13).fontColor(this.advertiserModel.budget <= 31 ? '#1E7268' : '#B04A35')
          Button(this.advertiserModel.phase === 'advertising' ? '停止广播' : '开始广播')
            .enabled(this.advertiserModel.phase !== 'permission')
            .onClick(() => {
              if (this.advertiserModel.phase === 'advertising') { this.advertiser.stop(); }
              else {
                const context = this.context();
                if (context) {
                  this.advertiser.setReadings(this.tempC / 100, this.humC / 100);
                  this.advertiser.start(context);
                }
              }
            })
          Text('connectable=false · interval 1600 slot=1s · 鸿蒙能发真的 BTHome 服务数据，iOS 不行')
            .fontSize(12.5).fontColor('#A79B8D')
        } else if (this.role === 'peripheral') {
          Text(this.peripheralModel.status).fontSize(15).fontColor('#476355')
          Text('当前温度 ' + (this.peripheralModel.temperature / 100).toFixed(2) + ' °C')
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor('#1E7268')
          Text('教学帧 ' + this.peripheralModel.frameHex).fontSize(14).fontFamily('monospace')
          Text('已响应写 01：' + this.peripheralModel.writes + ' 次').fontSize(13).fontColor('#7C7166')
          Button(this.peripheralModel.phase === 'peripheral' ? '停止广播' : '启动广播')
            .enabled(this.peripheralModel.phase !== 'permission')
            .onClick(() => {
              if (this.peripheralModel.phase === 'peripheral') { this.peripheral.stop(); }
              else {
                const context = this.context();
                if (context) { this.peripheral.start(context); }
              }
            })
          Text('写 01 温度交替 25.00/26.50；湿度固定 50.55%。Android/iPhone 也能连这个从端')
            .fontSize(12.5).fontColor('#A79B8D')
        } else if (this.role === 'client') {
          Text(this.clientModel.status).fontSize(15).fontColor('#476355')
          if (this.clientModel.phase === 'connecting' || this.clientModel.phase === 'discovering' ||
            this.clientModel.phase === 'ready' || this.clientModel.phase === 'writing' ||
            this.clientModel.phase === 'reading') {
            Text(this.clientModel.reading || '等待测量').fontSize(24).fontColor('#1E7268')
            Text(this.clientModel.raw).fontSize(14).fontFamily('monospace')
            Button('请求新读数（写 01）').enabled(this.clientModel.phase === 'ready')
              .onClick(() => { this.client.requestReading(); })
            Button('返回列表').onClick(() => { this.client.stop(); })
          } else {
            Button(this.clientModel.phase === 'scanning' ? '停止扫描' : '开始扫描')
              .enabled(this.clientModel.phase !== 'permission')
              .onClick(() => {
                if (this.clientModel.phase === 'scanning') { this.client.finishScan(); }
                else {
                  const context = this.context();
                  if (context) { this.client.scan(context); }
                }
              })
            ForEach(this.clientModel.devices, (device: ble.ScanResult) => {
              Button('教学温湿度计 · ' + device.rssi + ' dBm')
                .onClick(() => { this.client.connect(device.deviceId); })
            }, (device: ble.ScanResult): string => device.deviceId)
          }
        } else {
          Text('协议层 13 项自检：不碰蓝牙，离线验证对象表/边界/坏帧/AD 提取').fontSize(14).fontColor('#7C7166')
          Button('跑 13 项自检').onClick(() => { this.report = selfTest(); })
          ForEach(this.report, (line: string) => {
            Text(line).fontSize(14).fontFamily('monospace')
              .fontColor(line.startsWith('PASS') ? '#1E7268' : '#B04A35')
          }, (line: string): string => line)
        }
      }
      .width('100%')
      .padding(24)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FAF3EC')
  }
}