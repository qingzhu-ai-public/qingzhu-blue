import CoreBluetooth
import Foundation
import Combine

// 连接路线：连上教学服务 → 写 01 请求新读数 → 读回 BTHome 帧。
// 与 Android bthome-mvp 的 SensorClient 走同一套 UUID 和指令，可跨平台互连。
final class SensorClient: NSObject, ObservableObject {
    private enum Stage {
        case idle, connecting, discovering, ready, writing, reading
    }

    @Published private(set) var status = ""
    @Published private(set) var reading = ""
    @Published private(set) var raw = ""
    @Published private(set) var canRequest = false

    private var manager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private var stage = Stage.idle
    private var timeout: DispatchWorkItem?

    func connect(_ device: BthomeScanner.Device) {
        stop()
        peripheral = device.peripheral
        device.peripheral.delegate = self
        status = "正在连接 " + device.name
        stage = .connecting
        // 复用扫描时的 manager 状态不行（扫描器持有自己的），这里新建一个。
        manager = CBCentralManager(delegate: self, queue: nil)
        scheduleTimeout(12, message: "连接超时")
    }

    func requestReading() {
        guard stage == .ready, let peripheral, let characteristic else { return }
        move(to: .writing, "正在写入 01")
        peripheral.writeValue(DemoProtocol.measure, for: characteristic, type: .withResponse)
        scheduleTimeout(10, message: "写入超时")
    }

    func stop() {
        timeout?.cancel()
        timeout = nil
        if let manager, manager.state == .poweredOn {
            manager.stopScan()
            if let peripheral { manager.cancelPeripheralConnection(peripheral) }
        }
        peripheral?.delegate = nil
        manager?.delegate = nil
        manager = nil
        peripheral = nil
        characteristic = nil
        stage = .idle
        canRequest = false
        reading = ""
        raw = ""
        status = ""
    }

    private func move(to next: Stage, _ message: String) {
        timeout?.cancel()
        timeout = nil
        stage = next
        status = message
        canRequest = next == .ready
    }

    private func fail(_ message: String, error: Error? = nil) {
        let detail = error.map { " · " + $0.localizedDescription } ?? ""
        move(to: .idle, message + detail)
        if let manager, let peripheral { manager.cancelPeripheralConnection(peripheral) }
    }

    private func scheduleTimeout(_ seconds: Double, message: String) {
        let expected = stage
        let task = DispatchWorkItem { [weak self] in
            guard let self, self.stage == expected else { return }
            self.fail(message)
        }
        timeout = task
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: task)
    }
}

extension SensorClient: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central === manager else { return }
        if central.state == .poweredOn, stage == .connecting, let peripheral {
            central.connect(peripheral, options: nil)
        } else if central.state != .poweredOn {
            fail(DemoProtocol.unavailable(central.state))
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard central === manager, peripheral === self.peripheral else { return }
        move(to: .discovering, "已连接，正在查找教学服务")
        peripheral.discoverServices([DemoProtocol.service])
        scheduleTimeout(10, message: "发现服务超时")
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        guard peripheral === self.peripheral else { return }
        fail("连接失败", error: error)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        guard peripheral === self.peripheral else { return }
        fail("设备已断开", error: error)
    }
}

extension SensorClient: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral === self.peripheral, stage == .discovering else { return }
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
        guard peripheral === self.peripheral, stage == .discovering else { return }
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
        guard characteristic === self.characteristic, stage == .writing else { return }
        guard error == nil else { fail("写入失败", error: error); return }
        move(to: .reading, "写入成功，正在读取")
        peripheral.readValue(for: characteristic)
        scheduleTimeout(10, message: "读取超时")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard characteristic === self.characteristic, stage == .reading else { return }
        guard error == nil, let data = characteristic.value else {
            fail("读取失败", error: error)
            return
        }
        raw = Bthome.hex(data)
        guard let frame = Bthome.parse(data) else {
            fail("读数格式不符")
            return
        }
        reading = frame.display
        move(to: .ready, "读数已更新")
    }
}