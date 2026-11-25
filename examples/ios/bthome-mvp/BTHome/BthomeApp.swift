import SwiftUI

@main
struct BthomeApp: App {
    init() {
        #if DEBUG
        // 协议层自检：官方样例 + 边界用例，结果打印到控制台。
        for line in BthomeSelfTest.run() { print("[BthomeSelfTest] " + line) }
        #endif
    }

    var body: some Scene {
        WindowGroup { RootView() }
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var scanner = BthomeScanner()
    @StateObject private var client = SensorClient()
    @StateObject private var peripheral = SensorPeripheral()
    @State private var isPeripheral = false
    @State private var selected: BthomeScanner.Device?

    var body: some View {
        NavigationStack {
            List {
                if isPeripheral {
                    peripheralScreen
                } else if let device = selected {
                    detailScreen(device)
                } else {
                    scanScreen
                }
            }
            .navigationTitle("BTHome 温湿度计")
        }
        .onChange(of: scenePhase) { phase in
            // MVP 简化：进后台停掉会话。产品级后台/恢复见课程 C9。
            if phase == .background {
                scanner.stop()
                client.stop()
                peripheral.stop()
                selected = nil
            }
        }
    }

    private var scanScreen: some View {
        Group {
            Section("扫描") {
                Text(scanner.status)
                Button(scanner.isScanning ? "停止扫描" : "开始扫描") {
                    if scanner.isScanning { scanner.stop() } else { scanner.start() }
                }
            }
            Section("发现的设备") {
                if scanner.devices.isEmpty {
                    Text("暂无设备。BTHome 传感器扫到即显示读数；教学设备可点进去连接。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(scanner.devices) { device in
                    Button {
                        if device.connectable {
                            scanner.stop()
                            selected = device
                            client.connect(device)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(device.name).font(.headline)
                                Spacer()
                                Text(device.online ? "在线" : "离线")
                                    .font(.caption)
                                    .foregroundStyle(device.online ? .green : .secondary)
                            }
                            Text(device.reading).font(.title3)
                            HStack {
                                Text("信号 \(device.rssi) dBm")
                                if device.connectable { Text("· 可连接") }
                            }
                            .font(.caption).foregroundStyle(.secondary)
                            if !device.raw.isEmpty {
                                Text(device.raw).font(.caption).monospaced()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(!device.connectable)
                }
            }
            Button("模拟温湿度计（教学服务）") {
                scanner.stop()
                isPeripheral = true
            }
        }
    }

    private func detailScreen(_ device: BthomeScanner.Device) -> some View {
        Group {
            Section(device.name) {
                Text(client.status)
                if !client.reading.isEmpty { Text(client.reading).font(.title2) }
                if !client.raw.isEmpty { Text(client.raw).monospaced() }
                Button("请求新读数（写 01）") { client.requestReading() }
                    .disabled(!client.canRequest)
            }
            Button("返回列表") {
                client.stop()
                selected = nil
            }
        }
    }

    private var peripheralScreen: some View {
        Group {
            Section("模拟温湿度计") {
                Text(peripheral.status)
                Text("当前帧 " + peripheral.framePreview)
                    .font(.caption).monospaced()
                Button(peripheral.isActive ? "停止广播" : "启动广播") {
                    if peripheral.isActive { peripheral.stop() } else { peripheral.start() }
                }
            }
            Section("数据源") {
                Toggle("正弦波（自动变化）", isOn: $peripheral.waveEnabled)
                VStack(alignment: .leading) {
                    Text(String(format: "温度 %.2f °C", peripheral.temperature))
                    Slider(value: $peripheral.temperature, in: -40...85, step: 0.01)
                }
                Text("湿度固定 50.55%（与 Android 教学帧一致）。拖滑杆验证零下与边界值。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("平台边界") {
                Text("iOS 的 startAdvertising 只支持名字和服务 UUID，发不出 BTHome 服务数据广播。本机只能当教学 GATT 从端；标准 BTHome 广播源请用 Android bthome-mvp、ESP32 或 Shelly。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button("返回列表") {
                peripheral.stop()
                isPeripheral = false
            }
        }
    }
}