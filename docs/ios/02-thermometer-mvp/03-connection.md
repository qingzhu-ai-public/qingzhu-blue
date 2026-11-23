---
title: 连接篇　找到可以读写的入口
slug: connection
order: 30
---

# 连接篇　找到可以读写的入口

手机 A 点设备列表中的 QZ-Sensor。先看到正在连接，随后出现「已就绪」，「请求新读数」按钮变为可点。

## 本篇完整代码

按文件名展开。 [跳到讲解](#walkthrough)

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

点设备 → 建立连接 → 发现服务 → 发现特征 → 打开请求按钮。

### 把选中的设备交给系统

SwiftUI 的设备按钮把选中的 `Device` 交给 `central.connect(device)`。`Device` 保存了扫描回调带回的 `CBPeripheral`。连接前先停扫，再保存选中项，并把 `SensorCentral` 设置为这个设备的 delegate。之后服务发现、读写等回调都由它接收。

```swift
manager.connect(device.peripheral, options: nil)
```

第一项是要连接的设备，第二项为默认连接选项。系统完成后调用 `didConnect`，失败走 `didFailToConnect`。项目给这次连接设了 12 秒等待，到期会结束会话并清理。

### 系统说连上了，再问设备有什么功能

服务是一组功能，特征是组里的具体操作入口。想读温湿度，先找到温湿度服务，再找它下面可读写的那一项。

在 `didConnect` 里调用 `discoverServices([DemoProtocol.service])`。收到 `didDiscoverServices` 后，从结果里找同一个服务编号，再调用 `discoverCharacteristics([DemoProtocol.sample], for: service)`。服务和特征都按 DemoProtocol 里的 UUID 查。

`didDiscoverCharacteristicsFor` 要同时看到目标编号和 `.read`、`.write` 两种能力。通过检查后，`move(to: .ready, ...)` 把 `canRequest` 改成 true。SwiftUI 读到这个状态，便点亮请求按钮。[Apple Core Bluetooth 中心端示例](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/PerformingCommonCentralRoleTasks/PerformingCommonCentralRoleTasks.html)

### 返回列表时结束连接

「返回列表」调用 `central.stop()`。会话停扫、取消连接，清空选中设备。旧回调会被 manager、peripheral 和阶段检查拦截。遇到失败时详情会保留失败说明，读数按钮保持禁用，可以返回后重试。

**动手试一次**　先连通一次，再在连接尚未完成时返回列表。观察旧回调是否会重新打开详情。服务没找到时，回看手机 B 的服务添加状态。

**一句话记住**　连上设备以后，还要找到双方约定的读写入口。

**自查题**　为什么连接成功时按钮还是灰的？App 还在发现服务与特征，通过读写能力检查才能接收下一次请求。

继续读[传输篇](#ios/thermometer-mvp/transfer)。
