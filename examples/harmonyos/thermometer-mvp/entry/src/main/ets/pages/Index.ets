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
