---
title: 扫描篇　让教学设备出现在列表
slug: scanning
order: 20
---

# 扫描篇　让教学设备出现在列表

让手机 B 启动广播。手机 A 点「开始扫描」后，看到 QZ-Sensor 或「教学温湿度计」，以及一行信号强度。连接和读取留到后面。

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
<summary>SensorCentral.swift</summary>

[打开工程中的文件](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/ios/thermometer-mvp/Thermometer/SensorCentral.swift)

```swift
import CoreBluetooth
import Foundation
import Combine

final class SensorCentral: NSObject, ObservableObject {
    struct Device: Identifiable {
        let peripheral: CBPeripheral
        let name: String
        let rssi: Int

        var id: UUID { peripheral.identifier }
    }

    private enum Stage {
        case idle, waiting, scanning, picking, connecting, discovering, ready, writing, reading
    }

    @Published private(set) var devices: [Device] = []
    @Published private(set) var status = "点「开始扫描」查找教学温湿度计"
    @Published private(set) var reading = ""
    @Published private(set) var raw = ""
    @Published private(set) var canRequest = false
    @Published private(set) var isScanning = false
    @Published private(set) var selected: Device?

    private var manager: CBCentralManager?
    private var characteristic: CBCharacteristic?
    private var stage = Stage.idle
    private var timeout: DispatchWorkItem?

    func scan() {
        stop()
        devices = []
        move(to: .waiting, "正在等待蓝牙授权和系统状态")
        // queue: nil 使委托回调在主队列执行。
        manager = CBCentralManager(delegate: self, queue: nil)
    }

    func finishScan() {
        guard stage == .scanning else { return }
        manager?.stopScan()
        move(to: .picking, devices.isEmpty ? "没有发现教学外设" : "扫描结束，可以选中一台设备")
    }

    func connect(_ device: Device) {
        guard stage == .scanning || stage == .picking, let manager, manager.state == .poweredOn else {
            return
        }
        manager.stopScan()
        selected = device
        device.peripheral.delegate = self
        move(to: .connecting, "正在连接", seconds: 12)
        manager.connect(device.peripheral, options: nil)
    }

    func requestReading() {
        guard stage == .ready, let peripheral = selected?.peripheral, let characteristic else {
            return
        }
        move(to: .writing, "正在写入 01", seconds: 10)
        peripheral.writeValue(DemoProtocol.measure, for: characteristic, type: .withResponse)
    }

    func stop() {
        finishSession(keepSelection: false, message: "点「开始扫描」查找教学温湿度计")
    }

    private func finishSession(keepSelection: Bool, message: String) {
        move(to: .idle, message)
        if let manager, manager.state == .poweredOn {
            manager.stopScan()
            if let peripheral = selected?.peripheral {
                manager.cancelPeripheralConnection(peripheral)
            }
        }
        selected?.peripheral.delegate = nil
        manager?.delegate = nil
        manager = nil
        characteristic = nil
        if !keepSelection {
            selected = nil
            devices = []
            reading = ""
            raw = ""
        }
    }

    private func fail(_ message: String, error: Error? = nil) {
        let detail = error.map { " · " + $0.localizedDescription } ?? ""
        finishSession(keepSelection: selected != nil, message: message + detail)
    }

    private func move(to next: Stage, _ message: String, seconds: Double? = nil) {
        timeout?.cancel()
        timeout = nil
        stage = next
        status = message
        isScanning = next == .scanning
        canRequest = next == .ready
        guard let seconds else { return }
        let task = DispatchWorkItem { [weak self] in
            guard let self, self.stage == next else { return }
            if next == .scanning { self.finishScan() }
            else { self.fail(message + "超时") }
        }
        timeout = task
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: task)
    }
}

extension SensorCentral: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central === manager else { return }
        if central.state == .poweredOn, stage == .waiting {
            move(to: .scanning, "正在扫描教学设备", seconds: 12)
            central.scanForPeripherals(withServices: [DemoProtocol.service], options: nil)
        } else if central.state != .poweredOn {
            let message = DemoProtocol.unavailable(central.state)
            if stage == .waiting { status = message }
            else { fail(message) }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard central === manager, stage == .scanning else { return }
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let device = Device(peripheral: peripheral, name: advertisedName ?? "教学温湿度计",
                            rssi: RSSI.intValue)
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
        } else {
            devices.append(device)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard central === manager, peripheral === selected?.peripheral, stage == .connecting else {
            return
        }
        move(to: .discovering, "已连接，正在查找读写特征", seconds: 10)
        peripheral.discoverServices([DemoProtocol.service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        guard central === manager, peripheral === selected?.peripheral else { return }
        fail("连接失败", error: error)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        guard central === manager, peripheral === selected?.peripheral else { return }
        fail("设备已断开", error: error)
    }
}

extension SensorCentral: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral === selected?.peripheral, stage == .discovering else { return }
        guard error == nil, let service = peripheral.services?.first(where: {
            $0.uuid == DemoProtocol.service
        }) else {
            fail("找不到教学服务", error: error)
            return
        }
        peripheral.discoverCharacteristics([DemoProtocol.sample], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard peripheral === selected?.peripheral, stage == .discovering else { return }
        guard error == nil, let sample = service.characteristics?.first(where: {
            $0.uuid == DemoProtocol.sample && $0.properties.contains([.read, .write])
        }) else {
            fail("找不到可读写的特征", error: error)
            return
        }
        characteristic = sample
        move(to: .ready, "已就绪，可以请求新读数")
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard peripheral === selected?.peripheral, characteristic === self.characteristic,
              stage == .writing else { return }
        guard error == nil else { fail("写入失败", error: error); return }
        move(to: .reading, "写入成功，正在读取", seconds: 10)
        peripheral.readValue(for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard peripheral === selected?.peripheral, characteristic === self.characteristic,
              stage == .reading else { return }
        guard error == nil, let data = characteristic.value else {
            fail("读取失败", error: error)
            return
        }
        raw = DemoProtocol.hex(data)
        guard let value = DemoProtocol.decode(data) else {
            fail("读数格式不符")
            return
        }
        reading = value
        move(to: .ready, "读数已更新")
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

点扫描 → 等系统授权和蓝牙就绪 → 启动扫描 → 收到设备 → 列表多一行。

### 从按钮找到授权入口

在 `ThermometerApp.swift` 找「开始扫描」。首次点击调用 `central.scan()`，它创建 `CBCentralManager(delegate: self, queue: nil)`。manager 是 App 与系统蓝牙交互的入口。delegate 是接收系统回调的对象。这里 self 就是 `SensorCentral`，`queue: nil` 让委托回调在主队列执行。

`Info.plist` 里的 `NSBluetoothAlwaysUsageDescription` 是系统权限弹窗要显示的用途说明。iOS 会在需要时由系统处理授权。App 从 `centralManagerDidUpdateState` 判断是否可以扫描。若 status 显示未授权，可以到设置给 App 开蓝牙权限。蓝牙关闭时，要在系统设置打开蓝牙开关。[Apple Core Bluetooth 文档](https://developer.apple.com/documentation/corebluetooth)

### 等到蓝牙可用再开始

在 `centralManagerDidUpdateState` 里找这两行。

```swift
move(to: .scanning, "正在扫描教学设备", seconds: 12)
central.scanForPeripherals(withServices: [DemoProtocol.service], options: nil)
```

`.poweredOn` 表示系统蓝牙现在可用。第一行先更新页面状态并安排 12 秒计时。第二行请系统只找带有教学服务 UUID 的外设。UUID 可以理解为双方约定的编号，这里用它筛选设备。`options: nil` 使用默认扫描选项。

### 系统找到设备以后，让列表多一行

`didDiscover` 收到 `peripheral`、广播字段和 RSSI。peripheral 代表这台设备，点连接时还要用它。RSSI 表示信号强度。项目优先显示广播名称，没收到名称时显示「教学温湿度计」。

列表用 `peripheral.identifier` 判断是不是已经见过，已有就更新，没有就加入。它是 iOS 提供的标识。SwiftUI 读取 `@Published` 的设备数组，数组变了就刷新列表。当前实验只关心教学服务，普通传感器的其他广播数据不属于这个扫描结果。

### 停止以后，还可以点列表

点击「停止扫描」或 12 秒到期都会进入 `finishScan()`，调用 `stopScan()`。阶段从 scanning 变成 picking，列表还留着，可以选一台设备。重新点击扫描会新建会话并清空上一轮列表。

**动手试一次**　把这次 `move` 的 12 改成 5，重新运行。观察按钮何时恢复成「开始扫描」，并确认已发现的设备还在。

**一句话记住**　先等系统允许使用蓝牙，再让它找设备，找到后从回调接收。

**自查题**　调用 scanForPeripherals 后下一行能直接拿到设备吗？扫描结果从 `didDiscover` 陆续回来。

继续读[连接篇](#ios/thermometer-mvp/connection)。
