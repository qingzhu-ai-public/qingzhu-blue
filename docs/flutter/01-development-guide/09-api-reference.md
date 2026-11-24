---
title: Flutter 蓝牙 API 速查
slug: api-reference
order: 90
---

# Flutter 蓝牙 API 速查

按「要做什么」查一条调用，接着确认结果从哪来、由谁收尾。

| 调用 | 结果从哪来 | 何时收尾 |
|---|---|---|
| `statusStream` | 监听 `BleStatus`；等 ready 再扫描 | 取消订阅 |
| `scanForDevices(withServices: [...])` | `Stream<DiscoveredDevice>`；按 ID 更新列表 | 取消扫描订阅 |
| `connectToDevice(id: ...)` | `Stream<ConnectionStateUpdate>`；等 connected | 取消连接订阅 |
| `resolveSingle(characteristic)` | `Future<Characteristic>`；确认属性 | 断开后丢弃旧对象 |
| `writeCharacteristicWithResponse(characteristic, value: [...])` | `Future<void>`；等待写确认 | 超时走断开流程 |
| `readCharacteristic(characteristic)` | `Future<List<int>>`；得到业务字节 | 会话变化时忽略结果 |
| `subscribeToCharacteristic(characteristic)` | `Stream<List<int>>`；外设上报 | 取消对应订阅 |
| `requestMtu(deviceId: ..., mtu: ...)` | `Future<int>`；以返回值为准 | iOS 不接受 App 指定的 MTU |

权限、设备标识、后台限制跟着系统走。设备 ID 只用在当前系统内定位，跨手机识别硬件需要协议提供稳定标识。配套实战里使用相同的服务 UUID 和特征 UUID，让 Android 和 iOS 能对接同一个外设。

[插件完整 API](https://pub.dev/documentation/flutter_reactive_ble/latest/flutter_reactive_ble/FlutterReactiveBle-class.html) · [实战项目](#flutter/thermometer-mvp/overview)
