---
title: React Native 蓝牙 API 速查
slug: api-reference
order: 90
---

# React Native 蓝牙 API 速查

按「要做什么」查一条调用，接着确认结果从哪来、由谁收尾。

| 调用 | 结果从哪来 | 何时收尾 |
|---|---|---|
| `start(options)`、`checkState()` | 初始化；读取当前蓝牙状态 | 持续状态可监听 `onDidUpdateState` |
| `scan({serviceUUIDs, seconds})` | 启动调用完成后，设备从 `onDiscoverPeripheral` 来 | `stopScan()`，移除监听 |
| `connect(peripheralId)` | 等连接完成；额外监听断开 | `disconnect(peripheralId)` |
| `retrieveServices(peripheralId)` | `Promise<PeripheralInfo>`；检查特征属性 | 下一次连接重新发现 |
| `write(id, service, characteristic, data)` | 有响应写入完成 | 超时时主动终止当前会话 |
| `read(id, service, characteristic)` | `Promise<number[]>`；拿业务数据 | 会话变化时忽略结果 |
| `startNotification(id, service, characteristic)` | 上报从 `onDidUpdateValueForCharacteristic` 来 | `stopNotification(...)`，移除监听 |
| `requestMTU(id, mtu)`、`requestConnectionPriority(id, priority)` | Android 专用；记录实际结果 | 只在需要时调用 |

权限、设备标识、后台限制跟着系统走。设备 ID 只用在当前系统内定位，跨手机识别硬件需要协议提供稳定标识。配套实战里使用相同的服务 UUID 和特征 UUID，让 Android 和 iOS 能对接同一个外设。

[插件完整 API](https://innoveit.github.io/react-native-ble-manager/methods/) · [实战项目](#react-native/thermometer-mvp/overview)
