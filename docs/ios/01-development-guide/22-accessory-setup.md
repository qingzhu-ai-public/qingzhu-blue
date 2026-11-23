---
title: 21　想用系统弹窗让用户选配件
slug: accessory-setup
order: 220
---

# 21　想用系统弹窗让用户选配件

产品只想让用户选择自家温度计。用户点「添加温度计」后，可以在系统界面选中配件，然后回到 App 继续收发。

## 配件选择属于安装流程

iOS 18 起可使用 AccessorySetupKit。先设置 `NSAccessorySetupKitSupports` 和配件使用的蓝牙发现信息。用 `ASDiscoveryDescriptor` 填服务或协议规定的匹配条件，再把名称、图片和 descriptor 用于 `ASPickerDisplayItem`。准备了多款配件时，可以给每款单独配置。

## 接住系统返回的配件

1. 持有 `ASAccessorySession` 并通过 `activate(on:eventHandler:)` 接收事件。
2. 等待会话激活后，调用 `showPicker(for:completionHandler:)` 展示配件选择器。区分用户选中、取消和失败。收到 `accessoryAdded` 事件时保存配件。
3. 需要接着显示 App 界面时，可以等 `pickerDidDismiss`。取得 `ASAccessory.bluetoothIdentifier`，用该标识取回对应 CBPeripheral，再照连接篇连接。
4. 后续服务发现、读、写和订阅依然走 Core Bluetooth。在低于 iOS 18 的目标上，按产品需要提供另一套入口。

**动手验证**　先在支持的设备上添加一次，再分别测试取消、移除后重新添加。核对回到 App 时是否使用选择结果对应的标识。

**一句话记住**　系统弹窗帮用户选并授权配件，后续蓝牙通信仍由 App 接上。

## 自查题

1. **选完设备能跳过服务发现吗？** 已授权的设备仍需由 App 建立连接并找到读写入口。
2. **什么时候用自己的扫描页？** 可根据平台版本和产品所需发现能力选择，先确定要接的配件如何被识别。

[Apple AccessorySetupKit 接入步骤](https://developer.apple.com/documentation/accessorysetupkit/discovering-and-configuring-accessories)

[上一章](#ios/development-guide/testing) · [正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/classic-bluetooth)
