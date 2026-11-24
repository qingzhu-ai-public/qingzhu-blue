---
title: 平台接口地图 从概念到各端 API
order: 15
summary: 扫描连接读写订阅在各端 API 的对照表，Web Bluetooth 与桌面方案的能力边界。
tags: 跨平台, 速查
updated: 2026-11-24
---

# 平台接口地图　从概念到各端 API

前面十几篇讲的都是蓝牙本身：广播、连接、GATT、订阅、安全。这些概念在任何平台都一样，变的只是 API 的名字和形状。这一篇把通用概念映射到各端接口，帮你选平台，也帮你在跨平台开发时对上号——Android 同事说的 `discoverServices`，和 iOS 同事说的 `discoverServices(_:)`，和网页里的 `getPrimaryServices()`，是同一件事。

## 一张对照表

以「手机连温度计」这条链路为例，每行是一个通用步骤，各列是平台入口。记不住没关系，收藏这张表，写代码时按行查。

| 通用步骤 | Android | iOS | Web Bluetooth | Python（桌面） |
|---|---|---|---|---|
| 扫描 | `BluetoothLeScanner.startScan()` | `CBCentralManager.scanForPeripherals(...)` | `navigator.bluetooth.requestDevice()`（用户在弹窗里选） | `BleakScanner.discover()` |
| 连接 | `device.connectGatt()` | `central.connect(peripheral)` | `device.gatt.connect()` | `BleakClient(device).connect()` |
| 发现服务 | `gatt.discoverServices()` | `peripheral.discoverServices(...)` | `server.getPrimaryServices()` | 连接时自动完成 |
| 读特征 | `gatt.readCharacteristic()` | `peripheral.readValue(for:)` | `characteristic.readValue()` | `client.read_gatt_char()` |
| 写特征 | `gatt.writeCharacteristic()` | `peripheral.writeValue(...)` | `characteristic.writeValueWithResponse()` 等 | `client.write_gatt_char()` |
| 订阅 | `setCharacteristicNotification()` + 写 CCCD | `peripheral.setNotifyValue(true, for:)` | `characteristic.startNotifications()` | `client.start_notify()` |
| 断开 | `gatt.disconnect()` + `close()` | `central.cancelPeripheralConnection()` | `device.gatt.disconnect()` | `client.disconnect()` |

HarmonyOS、Flutter、React Native 的对应关系在本站各平台课程的 API 速查里，形状和上表一致：HarmonyOS 走 `ble.startBLEScan` 和 `GattClientDevice`，Flutter 常用 flutter_reactive_ble，React Native 常用 react-native-ble-manager。

订阅那一行值得多看一眼。Android 要你做两件事（本地登记 + 写 CCCD），iOS 的 `setNotifyValue` 一个调用把两件事都做了，Web 和 bleak 也是一个调用。**API 形状不同，协议动作相同**：空口上都是往 CCCD 写 `01 00`。懂了协议层，换平台只是换语法。

## 各平台的能力边界

选平台前先知道谁能做什么，避免选型返工。

| 平台 | Central（连设备） | Peripheral（当设备） | 后台 | 主要限制 |
|---|---|---|---|---|
| Android | 完整 | 支持（GATT Server + Advertiser） | 前台服务保活 | 厂商策略差异大，权限按版本分化 |
| iOS | 完整 | 支持（CBPeripheralManager） | 声明蓝牙后台模式，行为受限 | 拿不到 MAC；经典蓝牙要走 MFi |
| HarmonyOS | 完整 | 支持 | 长时任务约束 | 生态较新，资料以官方文档为准 |
| Flutter / RN | 靠原生桥接，完整 | 库支持较弱 | 取决于原生层 | 多一层桥接，排障要会看原生日志 |
| Web Bluetooth | 支持 | 不支持 | 不支持 | 只有 Chrome/Edge 系；iOS 上所有浏览器都不支持 |
| 桌面（bleak 等） | 支持 | bleak 只做客户端 | 桌面程序自己控制 | 各系统后端行为有差异 |

Web Bluetooth 单独说几句，因为它最容易被误解。网页可以直接连 BLE 设备，但有几个硬条件：页面必须 HTTPS；必须由用户手势触发 `requestDevice()`，设备由用户在浏览器弹窗里挑选，网页拿不到任意扫描列表；桌面和 Android 的 Chrome/Edge 支持，**iOS 上不支持**（所有 iOS 浏览器都用 WebKit，Safari 没实现）。做「网页配置工具」「浏览器里读传感器」这类场景很合适，做常驻后台采集就不行。[MDN Web Bluetooth](https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API) · [Chrome 官方教程](https://developer.chrome.google.cn/docs/capabilities/bluetooth)

桌面侧，Python 的 [bleak](https://github.com/hbldh/bleak) 是写验证脚本和自动化测试的顺手工具，Windows/macOS/Linux 一套代码；Rust 有 [btleplug](https://github.com/deviceplug/btleplug)，Linux 原生栈是 [BlueZ](https://github.com/bluez/bluez)。给外设写固件侧测试时，用 bleak 十行代码就能模拟一个客户端，比再写一个 App 快得多。

## 怎么选学习路线

- 目标做手机 App：Android 或 iOS 起步，资料最全。本站 [Android 课程](#android)（30 章）和 [iOS 课程](#ios)（24 章）都从装第一个 App 讲起。
- 目标鸿蒙设备：[HarmonyOS 课程](#harmonyos)，ArkTS 一套走完。
- 已有原生能力想跨端：[Flutter](#flutter) 或 [React Native](#react-native)，两门课都有「原生桥接」章。
- 只想快速验证设备协议：桌面 bleak 或 Web Bluetooth，不用建移动工程。
- 要做设备固件端：从 ESP32 或 nRF 开发板入手，参考[学习资源索引](#bluetooth/lab/resources)里的固件侧条目。

## 一句话总结

**协议只有一套，API 各端各样；扫描、连接、发现、读写、订阅五个动作在任何平台都能对上号，选型先看能力边界再看语法。**

## 面试题

1. Android 订阅要两步，iOS 只要一步，空口上的差别是什么？
2. 网页能不能拿到附近的 BLE 扫描列表？为什么？
3. 一套 BLE 采集方案要求 iOS 用户在 Safari 里直接使用，可行吗？
4. 想给外设固件写个自动化测试客户端，最省事的路线是什么？

### 参考答案

1. 没有差别。都是本地登记接收加向 CCCD 写开启值，iOS 把两步封装进一个调用。
2. 不能。Web Bluetooth 只允许用户手势触发选择弹窗，由用户挑选单台设备授权，网页拿不到任意扫描列表，这是隐私设计。
3. 不可行。iOS 上所有浏览器都基于 WebKit，Safari 未实现 Web Bluetooth。要么做原生 App，要么换平台。
4. 桌面 Python + bleak，几十行脚本完成扫描、连接、读写、订阅，跨三大桌面系统。

## 参考

[MDN Web Bluetooth API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API) · [Chrome Bluetooth 教程](https://developer.chrome.google.cn/docs/capabilities/bluetooth) · [bleak 文档](https://bleak.readthedocs.io/)