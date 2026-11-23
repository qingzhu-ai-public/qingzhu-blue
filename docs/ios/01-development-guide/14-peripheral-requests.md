---
title: 13　让模拟温度计接收指令并回复
slug: peripheral-requests
order: 140
---

# 13　让模拟温度计接收指令并回复

手机 A 发来一条 §01§。手机 B 检查命令、准备新温度，再把读数交给 A。对于以后主动上报的版本，还要记录谁订阅了。

## 一次写入和一次读取是两个请求

外设从 `peripheralManager(_:didReceiveWrite:)` 拿到请求数组。先查是不是本项目的特征、值是否是 `01`、偏移是否有效。成功时先更新模拟温度，再对这组写请求使用第一个请求调用 `respond(to:withResult:)` 回应。遇到不支持的情况返回相应 ATT 错误。

客户端接着发起读。`peripheralManager(_:didReceiveRead:)` 收到 `CBATTRequest`。先检查特征和 `offset`。有效时将从偏移开始的字节写入 `request.value`，再调用 `respond(to: request, withResult: .success)`。客户端才能从读取回调拿到这些字节。

## 外设主动上报的版本怎么接

把相应特征声明为 `.notify` 或 `.indicate`，中心端开始订阅后，外设从 `didSubscribeTo` 取得对应的 `CBCentral`，取消时走 `didUnsubscribeFrom`。数据变化时调用下面方法。

```swift
let enqueued = manager.updateValue(data, for: notifyingCharacteristic,
                                   onSubscribedCentrals: [subscribedCentral])
```

`enqueued` 为 false 时，等待 `peripheralManagerIsReady(toUpdateSubscribers:)` 再送这笔数据。每个中心端的 `maximumUpdateValueLength` 限制单次可发送数据长度。指定接收列表可以控制哪些订阅者收到这次值，也可按 API 使用 nil 向全部订阅者发送。

**动手验证**　先用现成 MVP 对照一轮读写。接入支持通知的版本，再分别记录订阅、发送与解除订阅。

**一句话记住**　读写是对请求作答，订阅后上报是外设主动发给等着的人。

## 自查题

1. **外设提交响应时，用哪一次的 request？** 用系统这次回调交给你的对象，保留本次请求的上下文。
2. **updateValue 返回 true 等于页面收到数据吗？** 它表示这次数据交给系统发送，界面更新由中心端的数据回调确认。

[Apple CBPeripheralManager 文档](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager)

[上一章](#ios/development-guide/peripheral) · [正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/two-device-lab)
