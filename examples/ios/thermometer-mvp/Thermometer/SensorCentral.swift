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
