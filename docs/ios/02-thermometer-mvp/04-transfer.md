---
title: 传输篇　写一条指令，再读一组温湿度
slug: transfer
order: 40
---

# 传输篇　写一条指令，再读一组温湿度

手机 A 点「请求新读数」。它发出 01，等写成功再读，第一次预期显示 26.50 °C 和 50.55% RH。

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

按按钮 → 写 01 → 手机 B 应答 → 手机 A 发起读 → 解析回包 → 更新界面。

### 先写入，再等系统回调

`requestReading()` 只在 ready 状态接收操作，找到连接中的设备和特征后，进入 writing 并禁用按钮。

```swift
peripheral.writeValue(DemoProtocol.measure, for: characteristic, type: .withResponse)
```

第一项是实际发送的数据，`Data([0x01])`。第二项是手机 B 的可写特征。`.withResponse` 要求外设回应这次写入。方法返回后，App 等 `didWriteValueFor` 的 error 判断结果。

### 手机 B 准备数据，手机 A 再读

`SensorPeripheral.didReceiveWrite` 检查目标 UUID、指令值和偏移。教学外设在内存里把温度从 2500 切换成 2650，再调用 `respond(to:withResult:)` 回应写入成功。再次测量会切回 2500。真实设备在什么时候完成测量，由设备协议约定。

手机 A 在 `didWriteValueFor` 看到写成功才进入 reading，调用 `readValue(for:)`。手机 B 的 `didReceiveRead` 把 `sampleBytes` 生成的字节放到 `request.value`，再向系统提交读响应。`didUpdateValueFor` 把结果带回手机 A。项目只在等待读取、并且特征正确时处理这个回调。

### 把字节翻成数字

第一次回包是 `40 02 5A 0A 03 BF 13`。`40` 是教学帧使用的 BTHome v2 明文头，`02` 表示温度，`03` 表示湿度。`5A 0A` 按低字节在前组合为 `0A5A`，十进制是 2650，除以 100 得到 26.50。`BF 13` 同理得到 50.55%。温度按有符号 16 位整数解释，湿度按无符号整数解释。

`DemoProtocol.decode` 检查固定帧长度和字段。它只覆盖这套教学帧。解析成功后保存 `reading` 和 `raw`，SwiftUI 显示两者。回到 ready 后，按钮重新可点。[BTHome v2 字节格式](https://bthome.io/format/)

**动手试一次**　把手机 B 的模拟温度 2650 改成 2700，重新运行手机 B，再从手机 A 连接并请求。对照 27.00 °C 和回包里的 `8C 0A`。

**一句话记住**　等写成功后再读，把收到的字节按约定换算成屏幕数字。

**自查题**　写回调成功就可以更新温度了吗？要等读取回调带回字节，并且解析成功。

继续读[双机验收篇](#ios/thermometer-mvp/two-device-check)。
