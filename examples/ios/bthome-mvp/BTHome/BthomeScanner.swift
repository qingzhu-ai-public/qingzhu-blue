import CoreBluetooth
import Foundation
import Combine

// 主端扫描：只收 BTHome v2（0xFCD2）与教学服务两类广播。
// BTHome 设备扫到即解析，不连接；教学服务设备可以点进去走连接路线。
final class BthomeScanner: NSObject, ObservableObject {
    struct Device: Identifiable {
        let peripheral: CBPeripheral
        let name: String
        let rssi: Int
        var reading: String
        var raw: String
        var connectable: Bool
        var lastSeen: Date
        var online: Bool

        var id: UUID { peripheral.identifier }
    }

    @Published private(set) var devices: [Device] = []
    @Published private(set) var status = "点「开始扫描」查找 BTHome 设备"
    @Published private(set) var isScanning = false

    private var manager: CBCentralManager?
    private var ticker: Timer?
    private let offlineAfter: TimeInterval = 10

    func start() {
        stop()
        status = "正在等待蓝牙授权和系统状态"
        // queue: nil → 回调在主队列，直接驱动 SwiftUI。
        manager = CBCentralManager(delegate: self, queue: nil)
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
        if let manager, manager.state == .poweredOn { manager.stopScan() }
        manager?.delegate = nil
        manager = nil
        isScanning = false
        devices = []
        status = "点「开始扫描」查找 BTHome 设备"
    }

    private func beginScan() {
        guard let manager, manager.state == .poweredOn else { return }
        // 带服务 UUID 过滤：BTHome 的 FCD2 + 教学服务。后台扫描也必须带 UUID（C9）。
        manager.scanForPeripherals(withServices: [Bthome.uuid, DemoProtocol.service], options: nil)
        isScanning = true
        status = "正在扫描 BTHome 与教学设备"
        // 没有新广播也要每秒刷一次，才能把超时设备标离线。
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshOnline()
        }
    }

    private func refreshOnline() {
        let now = Date()
        devices = devices.map { device in
            var copy = device
            copy.online = now.timeIntervalSince(device.lastSeen) < offlineAfter
            return copy
        }
    }
}

extension BthomeScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central === manager else { return }
        if central.state == .poweredOn {
            beginScan()
        } else {
            isScanning = false
            status = DemoProtocol.unavailable(central.state)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard central === manager else { return }
        // 服务数据字典：key 是 CBUUID，value 是 UUID 之后的字节。
        let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data]
        let bthomeBytes = serviceData?[Bthome.uuid]
        let frame = bthomeBytes.flatMap { Bthome.parse($0) }
        if let frame, frame.encrypted { return }              // 本课不处理加密

        let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let connectable = serviceUUIDs.contains(DemoProtocol.service)
        // 既不是 BTHome 也不是教学设备 → 忽略（过滤兜底）。
        guard frame != nil || connectable else { return }

        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? peripheral.name ?? "未知设备"
        let device = Device(
            peripheral: peripheral,
            name: name,
            rssi: RSSI.intValue,
            reading: frame?.display ?? "教学设备（可连接）",
            raw: bthomeBytes.map { Bthome.hex($0) } ?? "",
            connectable: connectable,
            lastSeen: Date(),
            online: true
        )
        // 按 identifier 合并：同一台设备只留最新一条（C3：identifier 不是 MAC）。
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
        } else {
            devices.append(device)
        }
    }
}