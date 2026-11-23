---
title: iOS 蓝牙开发指南 · 正文目录
slug: overview
order: 0
---

# iOS 蓝牙开发指南 · 正文目录

第一次做 iOS 蓝牙，从第 00 章开始。每章先做一件能看到结果的事，再对照系统调用和回调，最后用操作或自查题验证。

## 第一篇　让 iPhone 找到第一台设备

| 章节 | 这一章做什么 |
| --- | --- |
| [00　先把第一个 App 装到 iPhone 上](#ios/development-guide/first-app) | 准备 Mac、Xcode 和 iPhone。建一个 SwiftUI 工程，完成签名，把带「查找设备」按钮的页面跑在真机上。 |
| [01　温度计怎么让手机发现自己](#ios/development-guide/advertising) | 从「它还没连上，为什么就能出现在列表里」讲起。先认识 BLE 广播和扫描，再分清谁是中心设备、谁是外设。 |
| [02　为什么点查找设备会弹出权限提示](#ios/development-guide/permissions) | 在 Xcode 填写蓝牙用途说明，创建 `CBCentralManager`，等 `centralManagerDidUpdateState` 告诉 App 当前能不能扫描。分别试一次允许、拒绝和关闭蓝牙。 |
| [03　把附近的设备显示在列表里](#ios/development-guide/scanning) | 用 `scanForPeripherals` 开始扫描，从 `didDiscover` 拿到设备、广播数据和信号强度，离开页面或完成选择时用 `stopScan` 停下。 |
| [04　只显示要找的温度计](#ios/development-guide/scan-filters) | 用广播里的服务 UUID 筛选设备，处理未广播名称和重复条目。认识 `CBPeripheral.identifier`，学会区分 App 看到的设备标识和硬件地址。 |

## 第二篇　连上温度计，让数字动起来

| 章节 | 这一章做什么 |
| --- | --- |
| [05　点一台设备，等它真的连上](#ios/development-guide/connect) | 用 `connect` 发起连接，等 `didConnect` 再继续。给「连接中」加取消按钮，区分连接失败、用户取消和连接后断开。 |
| [06　连上之后，去哪里找温度](#ios/development-guide/services-characteristics) | 把外设的服务理解成一组功能，把特征理解成其中可读写的数据项。按协议给的 UUID，先用 `discoverServices` 找到服务，再用 `discoverCharacteristics` 找到温度特征。 |
| [07　点一次读取，把字节变成温度](#ios/development-guide/read-and-decode) | 调用 `readValue(for:)`，从 `didUpdateValueFor` 拿到结果。照示例协议把 `Data` 里的字节换算成摄氏度，解释读数错一位时怎样检查单位和字节顺序。 |
| [08　从手机给温度计发一条指令](#ios/development-guide/write) | 把新间隔按协议编码，用 `writeValue` 写入设备的配置特征。理解两种写入方式、写回调和设备的业务应答。 |
| [09　打开自动更新，让温度计主动发读数](#ios/development-guide/notification) | 从手动刷新过渡到订阅。说明 Notify、Indicate 和设备上的订阅配置各管什么，再用 `setNotifyValue` 开关订阅。区分订阅状态回调和数据回调，并解释 Indicate 的确认由谁发。 |
| [10　读一项设备说明，认识描述符](#ios/development-guide/descriptors) | 用 `discoverDescriptors` 找到特征旁的信息，读取协议指定的描述符，再说明可写描述符的操作。用「显示名称」作例子，回顾订阅配置为何走专门的 API。 |
| [11　设备走远了，回来时怎么接上](#ios/development-guide/reconnect) | 让 App 显示断线原因，演示重新扫描、按标识找回设备以及查找系统已连接的设备。重连后按需要重新发现服务和恢复订阅。 |

## 第三篇　用两台 iPhone 做完整练习

| 章节 | 这一章做什么 |
| --- | --- |
| [12　让另一台 iPhone 扮演温度计](#ios/development-guide/peripheral) | 用 `CBPeripheralManager` 建立外设端，添加服务和特征，再用 `startAdvertising` 开始广播。在第一台手机上确认能扫到它。 |
| [13　让模拟温度计接收指令并回复](#ios/development-guide/peripheral-requests) | 在外设端接收读写请求，用 `respond(to:withResult:)` 回应。等另一台手机订阅后，用 `updateValue` 上报读数，遇到发送队列暂满时等待可发送回调。 |
| [14　把一次操作从扫描走到读数](#ios/development-guide/two-device-lab) | 用同一个实战 App 先验收扫描、连接和读写，再逐项模拟失败。 |

## 第四篇　接入真实设备后遇到的问题

| 章节 | 这一章做什么 |
| --- | --- |
| [15　发不完的一条消息，怎样拆开来发](#ios/development-guide/packet-flow) | 用 `maximumWriteValueLength(for:)` 查询当前写入方式允许的长度。认识分包、重组和流控，并用 `canSendWriteWithoutResponse` 判断何时可以继续写。 |
| [16　连上了，为什么读一项值却报权限错误](#ios/development-guide/pairing-security) | 从「能连上，但读取某一项报错」讲起。区分 App 的蓝牙授权、蓝牙连接、系统配对和设备协议自己的认证。 |
| [17　切到后台，温度还能更新吗](#ios/development-guide/background) | 分开测试前台、锁屏、后台、系统终止和用户强退。说明后台模式、状态保存与恢复（`willRestoreState`）和各版本的唤醒条件。 |
| [18　接两台设备，怎样不把回调认错](#ios/development-guide/multi-device) | 把连接状态、等待结果的命令和超时分别记到每台设备名下。处理重复点击、取消和断开后迟到的回调。 |
| [19　搜不到、连不上、收不到，从哪里查](#ios/development-guide/troubleshooting) | 按故障出现的那一步排查。记录授权状态、广播、回调顺序和错误域，区分 `CBError` 与 `CBATTError`。需要时再看 PacketLogger 或外部抓包。 |
| [20　发版前，怎样在真机上测一遍](#ios/development-guide/testing) | 用两端日志验收权限拒绝、短时断连、前后台切换、重复连接和多设备通信。记录 iPhone、iOS 和外设固件版本，测量扫描耗时、吞吐和耗电。 |

## 第五篇　遇到其他类型的配件，走哪条路

| 章节 | 这一章做什么 |
| --- | --- |
| [21　想用系统弹窗让用户选配件](#ios/development-guide/accessory-setup) | 用 AccessorySetupKit 找到并授权指定配件，再交给 Core Bluetooth 通信。把系统选配件和 App 收发数据的两段流程接起来。 |
| [22　接到一台经典蓝牙设备，先问厂商什么](#ios/development-guide/classic-bluetooth) | 从串口秤、耳机和 MFi 配件的常见接入问题讲起。确认设备支持的协议，再对照 Core Bluetooth 的 GATT over BR/EDR、系统蓝牙功能或 External Accessory 的适用范围。 |
| [23　设备文档只给了 PSM，怎么传数据](#ios/development-guide/l2cap) | 认识 BLE L2CAP 通道。外设发布通道后，中心端按 PSM 打开它，再通过输入和输出流收发。对照前面按特征读写的做法。 |

## 查阅和动手

- [iOS 蓝牙 API 速查](#ios/development-guide/api-reference)
- [按现象排查](#ios/development-guide/troubleshooting)
- [温湿度计综合实战](#ios/thermometer-mvp/overview)
