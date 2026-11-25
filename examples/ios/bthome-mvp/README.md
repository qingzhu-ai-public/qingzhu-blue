# BTHome 温湿度计 · iOS MVP

与 [Android bthome-mvp](../../android/bthome-mvp/) 同一个项目：扫描 [BTHome v2](https://bthome.io/format/) 明文广播，扫到即显示温湿度；连接教学 GATT 服务主动请求新读数；第二台 iPhone 运行同一个 App 可模拟教学外设。教学服务的 UUID 和指令与 Android 版完全一致，**两台不同平台的手机可以互连**。

- [交互原型](https://qingzhu-ai-public.github.io/qingzhu-blue/examples/ios/bthome-mvp/prototype/index.html)
- [配套课程：C11 综合实战 BTHome](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/ios/11-project-temp.html)

## iOS 平台边界（先读这个）

Apple 官方文档写明：`CBPeripheralManager.startAdvertising` **只支持** `CBAdvertisementDataLocalNameKey` 和 `CBAdvertisementDataServiceUUIDsKey` 两个键。iPhone 发不出 BTHome 的 Service Data（0xFCD2）广播，所以：

- **接收端（主端）**：iPhone 完全胜任。扫描 FCD2，从 `advertisementData[CBAdvertisementDataServiceDataKey]` 取字节解析。真实 BTHome 设备（Shelly、小米、ESP32/ESPHome）或运行 Android bthome-mvp 的手机都能当广播源。
- **传感器端（从端）**：iPhone 只能走**教学 GATT 路线**（自定义服务，非 BTHome 标准）。要当标准 BTHome 广播源，用 Android bthome-mvp、ESP32 或 Shelly。

## 在真机上运行

在支持所需 iOS SDK 的 Mac 上用 Xcode 打开 `BTHome.xcodeproj`。示例最低 iOS 16。选择 BTHome target，设置签名团队和可用的 Bundle Identifier，再选真机运行。

1. 手机 A 点「开始扫描」。附近有 BTHome 设备时，列表直接显示温湿度与原始字节。
2. 手机 B 点「模拟温湿度计（教学服务）」→「启动广播」。手机 A 列表出现 `QZ-BTHome`（标「可连接」）。
3. 手机 A 点这一条 → 等「已就绪」→ 点「请求新读数（写 01）」。预期显示手机 B 滑杆上的温度与 `50.55%` 湿度，以及原始字节。
4. 手机 B 拖滑杆到 -5.5，手机 A 再请求，验证显示 `-5.50 °C`（符号扩展）。
5. 手机 B 点「停止广播」，手机 A 再请求，验证断开提示。

DEBUG 构建启动时会在控制台打印协议层自检结果（官方样例、零下、未知 ID、截断、越界、编码往返等 13 项），不连真机也能验证解析器。

## 工程结构

```
BTHome/
├── BthomeProtocol.swift    协议层：对象 ID 表 / parse / encode / 教学 UUID / 自检（纯 Swift）
├── BthomeScanner.swift     主端：扫描 FCD2 + 教学服务，按 identifier 合并，10s 标离线
├── SensorClient.swift      连接路线：connect → 发现 → 写 01 → 读回 BTHome 帧
├── SensorPeripheral.swift  从端：教学 GATT 服务 + 滑杆/正弦波数据源
├── BthomeApp.swift         SwiftUI：角色切换、扫描列表、连接面板、从端面板
└── Info.plist              蓝牙权限两键 + bluetooth-central/peripheral 后台模式
```

## 按开发顺序学习

| 步骤 | 对应课程 |
| --- | --- |
| 协议与对象 ID 表 | [C11 第 1–2 步](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/ios/11-project-temp.html#format) |
| 解析器与自检 | [C11 第 4 步](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/ios/11-project-temp.html#parser) |
| 主端扫描 | [C11 第 5 步](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/ios/11-project-temp.html#scanner) + C3 |
| 从端与平台边界 | [C11 第 6 步](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/ios/11-project-temp.html#advertiser) |
| 连接路线 | [C11 第 8 步](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/ios/11-project-temp.html#connect) + C4–C7 |
| 双机验收 | [C11 第 9 步](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/ios/11-project-temp.html#accept) |

MVP 进后台会停掉会话（简化）。产品级后台与状态恢复见课程 C9；标准 1809/2A1C 健康温度计路线见 [thermometer-mvp](../thermometer-mvp/)。