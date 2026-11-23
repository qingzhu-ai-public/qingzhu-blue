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
