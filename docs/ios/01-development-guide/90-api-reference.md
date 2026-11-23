---
title: iOS 蓝牙 API 速查
slug: api-reference
order: 900
---

# iOS 蓝牙 API 速查

先按要做的动作找系统调用，再到正文看参数和回调。表里的方法名采用 Swift 调用写法。正式接入配件时，请结合 Xcode 当前 SDK 的头文件和 Apple 文档核对可用版本。

## 中心端

| 要做什么 | 调用或属性 | 在哪里看结果 |
| --- | --- | --- |
| 判断授权 | `CBManager.authorization` | 授权枚举，见[第 02 章](#ios/development-guide/permissions) |
| 启动蓝牙管理器 | `CBCentralManager(delegate:queue:)` | `centralManagerDidUpdateState` |
| 找设备 | `scanForPeripherals(withServices:options:)` | `centralManager(_:didDiscover:advertisementData:rssi:)`，见[第 03 章](#ios/development-guide/scanning) |
| 停止扫描 | `stopScan()` | App 结束扫描窗口，保留已有设备 |
| 连接 | `connect(_:options:)` | `didConnect` 或 `didFailToConnect`，见[第 05 章](#ios/development-guide/connect) |
| 取消或断开 | `cancelPeripheralConnection(_:)` | `didDisconnectPeripheral` 等会话事件，App 及时禁用操作 |
| 按系统标识取回设备 | `retrievePeripherals(withIdentifiers:)` | 同步返回设备对象数组 |
| 查系统已连接的设备 | `retrieveConnectedPeripherals(withServices:)` | 同步返回对象数组，见[第 11 章](#ios/development-guide/reconnect) |
| 找服务 | `discoverServices(_:)` | `peripheral(_:didDiscoverServices:)` |
| 找特征 | `discoverCharacteristics(_:for:)` | `peripheral(_:didDiscoverCharacteristicsFor:error:)`，见[第 06 章](#ios/development-guide/services-characteristics) |
| 读特征 | `readValue(for:)` | 特征版本的 `didUpdateValueFor`，见[第 07 章](#ios/development-guide/read-and-decode) |
| 有响应写 | `writeValue(_:for:type:)` 传 `.withResponse` | `didWriteValueFor` |
| 无响应写 | 同一方法传 `.withoutResponse` | 用 `canSendWriteWithoutResponse` 和 `peripheralIsReady(toSendWriteWithoutResponse:)` 控制发送，见[第 08 章](#ios/development-guide/write) |
| 订阅或解除 | `setNotifyValue(_:for:)` | `didUpdateNotificationStateFor`，值在 `didUpdateValueFor`，见[第 09 章](#ios/development-guide/notification) |
| 找描述符 | `discoverDescriptors(for:)` | `didDiscoverDescriptorsFor` |
| 读写描述符 | `readValue(for:)` 或 `writeValue(_:for:)` | 对应的描述符重载回调，见[第 10 章](#ios/development-guide/descriptors) |
| 获取单次写入上限 | `maximumWriteValueLength(for:)` | 同步返回 Int，见[第 15 章](#ios/development-guide/packet-flow) |

[Apple CBCentralManager](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager) · [Apple CBPeripheral](https://developer.apple.com/documentation/corebluetooth/cbperipheral)

## 外设端

| 要做什么 | 调用或属性 | 在哪里看结果 |
| --- | --- | --- |
| 创建外设管理器 | `CBPeripheralManager(delegate:queue:)` | `peripheralManagerDidUpdateState` |
| 注册服务 | `add(_:)` | `didAdd` |
| 开始广播 | `startAdvertising(_:)` | `peripheralManagerDidStartAdvertising` |
| 结束广播或移除服务 | `stopAdvertising()` 或 `removeAllServices()` | 由 App 更新状态，见[第 12 章](#ios/development-guide/peripheral) |
| 回应读写 | `respond(to:withResult:)` | 请求来自 `didReceiveRead` 或 `didReceiveWrite`，读响应先填 request.value |
| 主动更新值 | `updateValue(_:for:onSubscribedCentrals:)` | false 时等 `peripheralManagerIsReady(toUpdateSubscribers:)` |
| 确认谁订阅了 | `didSubscribeTo` 和 `didUnsubscribeFrom` | 在外设委托中更新订阅者，见[第 13 章](#ios/development-guide/peripheral-requests) |
| 查看接收端更新长度 | `CBCentral.maximumUpdateValueLength` | 同步读取该中心端的限制 |

[Apple CBPeripheralManager](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager)

## 扩展入口

- 后台恢复使用恢复标识与 `willRestoreState`。见[第 17 章](#ios/development-guide/background)。
- 系统选择配件使用 `ASAccessorySession.activate(on:eventHandler:)` 和 `showPicker(for:completionHandler:)`。iOS 18 起可用。见[第 21 章](#ios/development-guide/accessory-setup)。
- L2CAP 外设发布 `publishL2CAPChannel(withEncryption:)`，中心端取得 PSM 后调用 `openL2CAPChannel(_:)`。两端分别处理 `didOpen`。见[第 23 章](#ios/development-guide/l2cap)。

## 按现象找下一步

列表空先核对权限、广播和扫描过滤。连接正常却不能请求时看服务和特征发现。写成功却没有读数时区分读回调、回包字节和解析结果。详见[排错章](#ios/development-guide/troubleshooting)与[双机实战](#ios/thermometer-mvp/two-device-check)。
