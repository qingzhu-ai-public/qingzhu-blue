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
