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
