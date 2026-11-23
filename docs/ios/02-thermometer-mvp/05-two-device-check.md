---
title: 双机验收篇　一台 iPhone 模拟外设，另一台验证收发
slug: two-device-check
order: 50
---

# 双机验收篇　一台 iPhone 模拟外设，另一台验证收发

准备两台已装示例 App 的 iPhone。手机 B 模拟温湿度计，手机 A 负责找设备并请求读数。保持两端在前台。

## 本篇完整代码

按文件名展开。 [跳到讲解](#walkthrough)

<details>
<summary>Info.plist</summary>

[打开工程中的文件](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/ios/thermometer-mvp/Thermometer/Info.plist)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key><string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key><string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>蓝牙温湿度计</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>查找附近教学设备，连接并读取温湿度，或模拟温湿度计供另一台手机连接。</string>
    <key>UILaunchScreen</key><dict/>
</dict>
</plist>
```

</details>

<details>
<summary>ThermometerApp.swift</summary>

[打开工程中的文件](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/ios/thermometer-mvp/Thermometer/ThermometerApp.swift)

```swift
import SwiftUI

@main
struct ThermometerApp: App {
    var body: some Scene {
        WindowGroup { ThermometerView() }
    }
}

struct ThermometerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var central = SensorCentral()
    @StateObject private var peripheral = SensorPeripheral()
    @State private var isPeripheral = false

    var body: some View {
        NavigationStack {
            List {
                if isPeripheral {
                    Section("模拟温湿度计") {
                        Text(peripheral.status)
                        Button(peripheral.isActive ? "停止广播" : "启动广播") {
                            if peripheral.isActive { peripheral.stop() }
                            else { peripheral.start() }
                        }
                    }
                    Button("返回列表") {
                        peripheral.stop()
                        isPeripheral = false
                    }
                } else if let device = central.selected {
                    Section(device.name) {
                        Text(central.status)
                        if !central.reading.isEmpty { Text(central.reading).font(.title2) }
                        if !central.raw.isEmpty { Text(central.raw).monospaced() }
                        Button("请求新读数") { central.requestReading() }
                            .disabled(!central.canRequest)
                    }
                    Button("返回列表") { central.stop() }
                } else {
                    Section("扫描") {
                        Text(central.status)
                        Button(central.isScanning ? "停止扫描" : "开始扫描") {
                            if central.isScanning { central.finishScan() }
                            else { central.scan() }
                        }
                    }
                    Section("发现的设备") {
                        ForEach(central.devices) { device in
                            Button {
                                central.connect(device)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(device.name)
                                    Text("信号 \(device.rssi) dBm")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Button("模拟温湿度计") {
                        central.stop()
                        isPeripheral = true
                    }
                }
            }
            .navigationTitle("蓝牙温湿度计")
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                central.stop()
                peripheral.stop()
            }
        }
    }
}
```

</details>

<details>
<summary>SensorPeripheral.swift</summary>

[打开工程中的文件](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/ios/thermometer-mvp/Thermometer/SensorPeripheral.swift)

```swift
import CoreBluetooth
import Foundation
import Combine

final class SensorPeripheral: NSObject, ObservableObject {
    @Published private(set) var status = "等待启动广播"
    @Published private(set) var isActive = false

    private var manager: CBPeripheralManager?
    private var service: CBMutableService?
    private var temperature: Int16 = 2500

    func start() {
        guard !isActive else { return }
        isActive = true
        status = "正在等待蓝牙授权和系统状态"
        temperature = 2500
        manager = CBPeripheralManager(delegate: self, queue: nil)
    }

    func stop() {
        finish("广播和教学服务已停止")
    }

    private func finish(_ message: String) {
        if let manager, manager.state == .poweredOn {
            manager.stopAdvertising()
            manager.removeAllServices()
        }
        manager?.delegate = nil
        manager = nil
        service = nil
        isActive = false
        status = message
    }
}

extension SensorPeripheral: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral === manager else { return }
        guard peripheral.state == .poweredOn else {
            status = DemoProtocol.unavailable(peripheral.state)
            if service != nil { finish(status) }
            return
        }
        guard service == nil else { return }
        let sample = CBMutableCharacteristic(type: DemoProtocol.sample,
                                             properties: [.read, .write],
                                             value: nil,
                                             permissions: [.readable, .writeable])
        let service = CBMutableService(type: DemoProtocol.service, primary: true)
        service.characteristics = [sample]
        self.service = service
        status = "正在添加教学服务"
        peripheral.add(service)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService,
                           error: Error?) {
        guard peripheral === manager, service.uuid == DemoProtocol.service else { return }
        if let error {
            finish("添加服务失败 · " + error.localizedDescription)
            return
        }
        peripheral.startAdvertising([
            CBAdvertisementDataLocalNameKey: "QZ-Sensor",
            CBAdvertisementDataServiceUUIDsKey: [DemoProtocol.service]
        ])
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        guard peripheral === manager else { return }
        if let error {
            finish("广播启动失败 · " + error.localizedDescription)
        } else {
            status = "正在广播，等待另一台手机连接"
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard peripheral === manager, let request = requests.first else { return }
        guard requests.count == 1, request.characteristic.uuid == DemoProtocol.sample,
              request.value == DemoProtocol.measure else {
            peripheral.respond(to: request, withResult: .requestNotSupported)
            return
        }
        guard request.offset == 0 else {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }
        temperature = temperature == 2500 ? 2650 : 2500
        peripheral.respond(to: request, withResult: .success)
        status = "收到指令 01，已准备新读数"
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard peripheral === manager else { return }
        guard request.characteristic.uuid == DemoProtocol.sample else {
            peripheral.respond(to: request, withResult: .readNotPermitted)
            return
        }
        let bytes = DemoProtocol.sampleBytes(temperature)
        guard request.offset <= bytes.count else {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }
        request.value = Data(bytes.dropFirst(request.offset))
        peripheral.respond(to: request, withResult: .success)
        status = "已返回 " + DemoProtocol.hex(bytes)
    }
}
```

</details>

<details>
<summary>DemoProtocol.swift</summary>

[打开工程中的文件](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/ios/thermometer-mvp/Thermometer/DemoProtocol.swift)

```swift
import Foundation
import CoreBluetooth

enum DemoProtocol {
    static let service = CBUUID(string: "476CDF45-6063-43A1-B8E2-8C1FBED00601")
    static let sample = CBUUID(string: "476CDF45-6063-43A1-B8E2-8C1FBED00602")
    static let measure = Data([0x01])

    static func sampleBytes(_ temperature: Int16) -> Data {
        let bits = UInt16(bitPattern: temperature)
        return Data([0x40, 0x02, UInt8(truncatingIfNeeded: bits), UInt8(bits >> 8),
                     0x03, 0xBF, 0x13])
    }

    static func decode(_ data: Data) -> String? {
        let bytes = Array(data)
        // 教学特征的固定格式。只接收本示例的温度和湿度对象。
        guard bytes.count == 7, bytes[0] == 0x40, bytes[1] == 0x02, bytes[4] == 0x03 else {
            return nil
        }
        let temperature = Int16(bitPattern: littleEndian(bytes[2], bytes[3]))
        let humidity = littleEndian(bytes[5], bytes[6])
        return String(format: "%.2f °C · %.2f%% RH",
                      locale: Locale(identifier: "en_US_POSIX"),
                      Double(temperature) / 100, Double(humidity) / 100)
    }

    static func hex(_ data: Data) -> String {
        data.map { String(format: "%02X", Int($0)) }.joined(separator: " ")
    }

    private static func littleEndian(_ low: UInt8, _ high: UInt8) -> UInt16 {
        UInt16(low) | (UInt16(high) << 8)
    }

    static func unavailable(_ state: CBManagerState) -> String {
        switch state {
        case .poweredOff: return "请在系统设置开启蓝牙"
        case .unauthorized: return "请在设置中允许本 App 使用蓝牙"
        case .unsupported: return "当前设备不支持此蓝牙功能"
        default: return "正在等待蓝牙系统"
        }
    }
}
```

</details>

<a id="walkthrough"></a>

## 对着代码讲重点

启动外设 → 等蓝牙状态 → 注册服务 → 开始广播 → 接收手机 A 的读写。

### 准备好特征以后再广播

点「启动广播」会创建 `CBPeripheralManager`。它是外设一侧与系统蓝牙交互的入口。等 `peripheralManagerDidUpdateState` 报告 `.poweredOn`，再建一个可读、可写的特征并加入主服务。

`CBMutableCharacteristic` 的 `properties` 告诉手机 A 支持哪些操作，`permissions` 描述允许的访问方式。`value: nil` 让手机 B 在收到请求时计算并返回值。调用 `add` 以后要等 `didAdd`。确认服务注册成功才执行 `startAdvertising`，这样对端扫到设备并来连接时，服务已经存在。

### 广播里实际有什么

这个项目传给 `startAdvertising` 的字典是设备名称 `QZ-Sensor` 和教学服务 UUID。iPhone 上的这一接口只接收名称和服务 UUID 两种应用自定义字段。温湿度由连接后的教学特征返回。[Apple 广播方法说明](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager/startadvertising%28_%3A%29)

### 按顺序操作并对照两端

| 操作 | 手机 A 预期看到 | 手机 B 预期看到 |
| --- | --- | --- |
| B 启动广播，A 开始扫描 | QZ-Sensor 或教学温湿度计 | 正在广播 |
| A 点设备 | 正在连接，随后可以请求读数 | 保持广播状态提示 |
| A 点请求 | 分别看到 26.50 °C、50.55% RH 和原始字节 | 返回原始字节 |
| A 再点一次 | 温度变为 25.00 °C | 返回第二组字节 |
| A 点返回列表 | 详情关闭，回到扫描界面 | 外设仍可供下一次练习 |
| B 点停止广播 | A 重新扫描时不再发现本次模拟外设 | 广播和教学服务已停止 |

停止外设这一步用 `stopAdvertising` 和 `removeAllServices`。已连接时关闭手机 B 的蓝牙，可以额外验证 A 的断开或读取失败处理。单独停止广播只影响新的发现，iOS 外设 API 没在这里主动断开一条指定中心设备连接。

### 如果没有跑通，先看最后一个状态

B 没出现正在广播，查它的蓝牙授权和服务注册结果。B 已广播而 A 没搜到，检查两端是否保持前台、服务 UUID 是否相同。能连上却按钮仍灰着，看设备是否提供了可读写的特征。写成功却没出读数，分别看 A 是否收到了读取错误，以及 B 是否显示返回字节。

**动手试一次**　跑通后让 A 返回列表，再让 B 停止。A 重新扫描一轮，观察列表和等待结束后的状态。

**一句话记住**　先让设备准备好接待，再用两端的状态确认数据到底走到了哪一步。

**自查题**　为什么服务注册成功以后才广播？广播一出现，对端就可能来连接，服务需要提前准备好。

[回到综合实战目录](#ios/thermometer-mvp/overview)
