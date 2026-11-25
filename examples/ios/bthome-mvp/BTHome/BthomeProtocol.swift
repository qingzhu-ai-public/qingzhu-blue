import Foundation
import CoreBluetooth

// BTHome v2 协议层：纯 Swift，不碰 CoreBluetooth 对象，方便自检。
// 规范：https://bthome.io/format/
enum Bthome {
    /// v2 服务数据 UUID。广播字节里按小端写作 D2 FC。
    static let uuid = CBUUID(string: "FCD2")

    struct Obj {
        let id: UInt8
        let label: String
        let len: Int
        let signed: Bool
        let factor: Double
        let unit: String
        let min: Double
        let max: Double
    }

    /// 对象 ID 表：解析器需要的全部信息。未登记的 ID 一律停止解析。
    static let objects: [Obj] = [
        Obj(id: 0x00, label: "序号", len: 1, signed: false, factor: 1,     unit: "",   min: 0,   max: 255),
        Obj(id: 0x01, label: "电量", len: 1, signed: false, factor: 1,     unit: "%",  min: 0,   max: 100),
        Obj(id: 0x02, label: "温度", len: 2, signed: true,  factor: 0.01,  unit: "°C", min: -40, max: 85),
        Obj(id: 0x03, label: "湿度", len: 2, signed: false, factor: 0.01,  unit: "%",  min: 0,   max: 100),
        Obj(id: 0x0C, label: "电压", len: 2, signed: false, factor: 0.001, unit: "V",  min: 0,   max: 65.535),
    ]

    static func obj(_ id: UInt8) -> Obj? { objects.first { $0.id == id } }

    struct Measurement {
        let obj: Obj
        let value: Double
        var inRange: Bool { value >= obj.min && value <= obj.max }
        var text: String {
            String(format: "%.2f %@", locale: Locale(identifier: "en_US_POSIX"), value, obj.unit)
        }
    }

    struct Frame {
        let version: Int
        let encrypted: Bool
        let trigger: Bool
        let measurements: [Measurement]
        let unsupportedId: UInt8?

        var display: String {
            var parts = measurements.filter { $0.obj.id != 0x00 }.map { m in
                m.obj.label + " " + m.text + (m.inRange ? "" : "（越界）")
            }
            if parts.isEmpty { parts = ["无可显示的读数"] }
            if let id = unsupportedId {
                parts.append(String(format: "遇到未支持的对象 0x%02X", id))
            }
            return parts.joined(separator: " · ")
        }
    }

    /// 输入是服务数据里 UUID 之后的字节（iOS 从 advertisementData[CBAdvertisementDataServiceDataKey] 取）。
    static func parse(_ data: Data) -> Frame? {
        let bytes = Array(data)
        guard bytes.count >= 2 else { return nil }
        let info = bytes[0]
        let encrypted = info & 0x01 != 0
        let trigger = info & 0x04 != 0
        let version = Int(info >> 5)
        guard version == 2 else { return nil }              // 只处理 v2
        if encrypted {
            return Frame(version: 2, encrypted: true, trigger: trigger,
                         measurements: [], unsupportedId: nil)  // 密文不解析
        }
        var out: [Measurement] = []
        var i = 1
        var lastId = -1
        var unsupported: UInt8?
        while i < bytes.count {
            let id = bytes[i]
            guard let o = obj(id) else { unsupported = id; break }   // 不认识就停
            if Int(id) < lastId { break }                            // 必须升序
            guard i + 1 + o.len <= bytes.count else { break }        // 截断包不越界读
            let raw = readLE(bytes, i + 1, o.len, o.signed)
            out.append(Measurement(obj: o, value: Double(raw) * o.factor))
            lastId = Int(id)
            i += 1 + o.len
        }
        guard !out.isEmpty else { return nil }
        return Frame(version: 2, encrypted: false, trigger: trigger,
                     measurements: out, unsupportedId: unsupported)
    }

    /// 编码：对象 ID 升序 + 小端 + 倍率。返回 nil 表示没有可编码的对象。
    static func encode(_ values: [(id: UInt8, value: Double)]) -> Data? {
        var out = Data([0x40])                               // v2，不加密，定时广播
        for item in values.sorted(by: { $0.id < $1.id }) {
            guard let o = obj(item.id) else { continue }
            let raw = Int((item.value / o.factor).rounded())
            let bits = o.signed ? Int(UInt16(bitPattern: Int16(clamping: raw))) : raw
            out.append(o.id)
            for k in 0..<o.len { out.append(UInt8(truncatingIfNeeded: bits >> (8 * k))) }
        }
        return out.count > 1 ? out : nil
    }

    private static func readLE(_ b: [UInt8], _ off: Int, _ len: Int, _ signed: Bool) -> Int {
        var v = 0
        for k in 0..<len { v |= Int(b[off + k]) << (8 * k) }
        if signed {
            if len == 1 && v & 0x80 != 0 { v -= 0x100 }
            if len == 2 && v & 0x8000 != 0 { v -= 0x10000 }
        }
        return v
    }

    static func hex(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    static func data(hex: String) -> Data {
        var out = Data()
        for part in hex.split(whereSeparator: { $0 == " " || $0 == "," }) {
            if let byte = UInt8(part, radix: 16) { out.append(byte) }
        }
        return out
    }
}

// 教学 GATT 服务：与 Android bthome-mvp 的 DemoProtocol 完全一致，可跨平台互连。
// 注意：这不是 BTHome 标准的一部分，只为练习连接/读写路线。
enum DemoProtocol {
    static let service = CBUUID(string: "476CDF45-6063-43A1-B8E2-8C1FBED00601")
    static let sample = CBUUID(string: "476CDF45-6063-43A1-B8E2-8C1FBED00602")
    static let measure = Data([0x01])

    /// 与 Android DemoProtocol.sample 相同的帧：温度 sint16 + 固定湿度 50.55%。
    static func sampleBytes(_ temperature: Int16) -> Data {
        let bits = UInt16(bitPattern: temperature)
        return Data([0x40, 0x02, UInt8(truncatingIfNeeded: bits), UInt8(bits >> 8),
                     0x03, 0xBF, 0x13])
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

// 官方样例自检：不连真机也能验证协议层。App 启动时（DEBUG）跑一遍并打印。
enum BthomeSelfTest {
    static func run() -> [String] {
        var report: [String] = []
        func check(_ name: String, _ ok: Bool) {
            report.append((ok ? "PASS " : "FAIL ") + name)
        }
        let official = Bthome.parse(Bthome.data(hex: "40 02 C4 09 03 BF 13"))
        check("官方样例 v2", official?.version == 2 && official?.encrypted == false)
        check("温度 25.00", abs((official?.measurements.first?.value ?? 0) - 25.0) < 0.001)
        check("湿度 50.55", abs((official?.measurements.last?.value ?? 0) - 50.55) < 0.001)
        let negative = Bthome.parse(Bthome.data(hex: "40 02 DA FD"))
        check("零下 -5.50", abs((negative?.measurements.first?.value ?? 0) + 5.5) < 0.001)
        let unknown = Bthome.parse(Bthome.data(hex: "40 02 C4 09 53 0C 48 65 6C 6C 6F"))
        check("未知 ID 即停", unknown?.measurements.count == 1 && unknown?.unsupportedId == 0x53)
        check("首对象未知整帧无效", Bthome.parse(Bthome.data(hex: "40 53 0C 48 69")) == nil)
        let outOfRange = Bthome.parse(Bthome.data(hex: "40 03 A2 28"))
        check("越界保留并标记", outOfRange?.measurements.first?.inRange == false)
        check("v1 拒绝", Bthome.parse(Bthome.data(hex: "00 02 C4 09")) == nil)
        check("加密标记", Bthome.parse(Bthome.data(hex: "41 02 C4 09"))?.encrypted == true)
        check("截断不崩", Bthome.parse(Bthome.data(hex: "40 02 C4")) == nil)
        let encoded = Bthome.encode([(id: 0x03, value: 50.55), (id: 0x02, value: 25.0)])
        check("编码升序", encoded == Bthome.data(hex: "40 02 C4 09 03 BF 13"))
        let roundTrip = Bthome.parse(Bthome.encode([(id: 0x02, value: -5.5)]) ?? Data())
        check("负值往返", abs((roundTrip?.measurements.first?.value ?? 0) + 5.5) < 0.001)
        check("教学帧兼容", Bthome.parse(DemoProtocol.sampleBytes(2650))?.display.contains("26.50") == true)
        return report
    }
}