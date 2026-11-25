import CoreBluetooth
import Foundation
import Combine

// 从端（教学路线）：CBPeripheralManager 提供教学 GATT 服务。
//
// 平台边界（Apple 官方）：startAdvertising 只支持 LocalName 和 ServiceUUIDs 两个键，
// iPhone 发不出 BTHome 的 Service Data 广播。所以 iOS 的「传感器角色」走教学 GATT：
// 主端连上来写 01，从端按当前温度返回 BTHome 帧。
// 要当标准 BTHome 广播源，请用 Android bthome-mvp / ESP32 / Shelly。
final class SensorPeripheral: NSObject, ObservableObject {
    @Published private(set) var status = "等待启动"
    @Published private(set) var isActive = false
    @Published var temperature: Double = 25.0 {
        didSet { if waveEnabled && !applyingWave { waveEnabled = false } }
    }
    @Published var waveEnabled = false {
        didSet { waveEnabled ? startWave() : stopWave() }
    }

    private var applyingWave = false

    private var manager: CBPeripheralManager?
    private var service: CBMutableService?
    private var waveTimer: Timer?
    private var phase = 0.0

    var framePreview: String {
        Bthome.hex(DemoProtocol.sampleBytes(Int16((temperature * 100).rounded())))
    }

    func start() {
        guard !isActive else { return }
        isActive = true
        status = "正在等待蓝牙授权和系统状态"
        manager = CBPeripheralManager(delegate: self, queue: nil)
    }

    func stop() {
        stopWave()
        waveEnabled = false
        if let manager, manager.state == .poweredOn {
            manager.stopAdvertising()
            manager.removeAllServices()
        }
        manager?.delegate = nil
        manager = nil
        service = nil
        isActive = false
        status = "已停止"
    }

    private func startWave() {
        stopWave()
        phase = 0
        waveTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.phase += 0.05
            self.applyingWave = true
            self.temperature = ((23 + 3 * sin(self.phase)) * 100).rounded() / 100
            self.applyingWave = false
        }
    }

    private func stopWave() {
        waveTimer?.invalidate()
        waveTimer = nil
    }
}

extension SensorPeripheral: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral === manager else { return }
        guard peripheral.state == .poweredOn else {
            status = DemoProtocol.unavailable(peripheral.state)
            if service != nil { stop() }
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
            status = "添加服务失败 · " + error.localizedDescription
            isActive = false
            return
        }
        // 只发名字 + 服务 UUID（iOS 仅支持这两个键）。
        peripheral.startAdvertising([
            CBAdvertisementDataLocalNameKey: "QZ-BTHome",
            CBAdvertisementDataServiceUUIDsKey: [DemoProtocol.service],
        ])
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        guard peripheral === manager else { return }
        if let error {
            status = "广播启动失败 · " + error.localizedDescription
            isActive = false
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
        peripheral.respond(to: request, withResult: .success)
        status = "收到指令 01，已准备新读数 " + String(format: "%.2f °C", temperature)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard peripheral === manager else { return }
        guard request.characteristic.uuid == DemoProtocol.sample else {
            peripheral.respond(to: request, withResult: .readNotPermitted)
            return
        }
        let bytes = DemoProtocol.sampleBytes(Int16((temperature * 100).rounded()))
        guard request.offset <= bytes.count else {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }
        request.value = bytes.dropFirst(request.offset)
        peripheral.respond(to: request, withResult: .success)
        status = "已返回 " + Bthome.hex(bytes)
    }
}