---
title: 18　接两台设备，怎样不把回调认错
slug: multi-device
order: 190
---

# 18　接两台设备，怎样不把回调认错

页面上同时显示客厅和卧室温度。两台设备都能在同一时间回消息，App 必须知道哪条读数属于哪台。

## 给每台设备单独记状态

用 `peripheral.identifier` 作为当前 App 的会话索引。每个会话保留自己的 CBPeripheral、特征、连接阶段、等待中的命令和计时器。下面是结构关系，字段类型可按需要加上。

```swift
var sessions: [UUID: DeviceSession] = [:]
// 回调先按 peripheral.identifier 找到 session，再处理该设备的事件。
```

回调要核对当前连接和操作阶段。重连或取消时作废等待任务。若对端协议允许并发操作，业务回包还要带两端都认识的请求号。只靠「先来的算第一条」遇到主动上报就容易串线。

## 从一台设备的队列开始

先让每台设备同一时刻只执行一条会等待结果的指令。写成功、读成功或超时后，才取下一条。不同设备的队列独立。界面从各设备自己的状态更新，更新动作在约定的队列或线程执行。

**动手验证**　用两台可识别的外设给出不同读数，同时发起一次读取，再断开其中一台。另一台的任务应独立继续。

**一句话记住**　每台设备有自己的状态和队列，先认清设备，再认回包。

## 自查题

1. **只有一份全局当前特征会有什么问题？** 第二台连接可能覆盖第一台的特征，后续操作和回调会串到错误设备。
2. **请求号什么时候有用？** 它可以帮助区分同类业务回应，以及设备主动上报与请求结果。

[Apple CBPeripheralDelegate 文档](https://developer.apple.com/documentation/corebluetooth/cbperipheraldelegate)

[上一章](#ios/development-guide/background) · [正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/troubleshooting)
