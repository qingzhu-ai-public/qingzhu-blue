---
title: 09　打开自动更新，让温度计主动发读数
slug: notification
order: 100
---

# 09　打开自动更新，让温度计主动发读数

手动刷新时，手机问一次，温度计回一次。打开自动更新后，温度计有新数据就主动发给手机。

## Notify、Indicate 和 CCCD 各做什么

Notify 是外设主动发数据的方式。Indicate 也由外设发起，手机的蓝牙协议栈会回一条 ATT 确认，表示收到了这次指示。这个确认和 App 是否显示或存储数据是两个阶段。

CCCD 是外设特征上记录订阅状态的配置。对支持通知或指示的特征，iPhone App 通过 Core Bluetooth 开关订阅。系统处理设备侧配置，应用使用下面的 API。

```swift
peripheral.setNotifyValue(true, for: sample)  // 开启
peripheral.setNotifyValue(false, for: sample) // 关闭时调用
```

上面是两个按钮各自的动作。特征只支持 Indicate 时仍使用同一 API。如果同时支持通知和指示，Apple 文档说明此调用会启用通知。要演示 Indicate，选择仅暴露 Indicate 的特征。

## 开关成功和收到首条数据要分开观察

`didUpdateNotificationStateFor` 返回订阅动作的结果。检查 error 和 `characteristic.isNotifying`，通过后再显示已订阅。实际数据在 `didUpdateValueFor`，外设决定何时发送。打开订阅后如需立即填充页面，可按设备协议另外读一次当前值。

**动手验证**　用支持通知的外设先订阅，再让外设发两条值。取消订阅后，触发第三次变化，检查页面是否停止更新。当前温湿度计 MVP 使用主动读取。本章实验需要支持相应属性的特征。

**一句话记住**　订阅是请外设以后主动告诉你，Indicate 另有手机蓝牙系统的签收。

## 自查题

1. **iOS App 需要自己写 CCCD 吗？** 订阅使用 setNotifyValue。
2. **收到 Indicate 确认代表手机界面更新了吗？** 只确认手机蓝牙协议栈收到该指示。

[Apple setNotifyValue 方法](https://developer.apple.com/documentation/corebluetooth/cbperipheral/setnotifyvalue%28_%3Afor%3A%29)

[上一章](#ios/development-guide/write) · [正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/descriptors)
