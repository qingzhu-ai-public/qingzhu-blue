---
title: 23　设备文档只给了 PSM，怎么传数据
slug: l2cap
order: 240
---

# 23　设备文档只给了 PSM，怎么传数据

外设文档说长数据走 L2CAP，并给出一个 PSM。这个编号用来找指定通道，接下来会得到输入和输出流。

## 外设先发布，中心端用 PSM 打开

外设调用 `publishL2CAPChannel(withEncryption:)`，系统从 `didPublishL2CAPChannel` 返回分配的 PSM。外设要通过约定方式把 PSM 告诉中心端，例如读一个协议规定的 GATT 特征。对于第三方设备，以其文档给出的 PSM 发现规则为准。

```swift
// 已连接且取得协议提供的 PSM
peripheral.openL2CAPChannel(psm)
```

中心端等 `peripheral(_:didOpen:error:)`，外设端等 `peripheralManager(_:didOpen:error:)`。检查错误和通道对象，再处理 `inputStream` 和 `outputStream`。打开流并处理可读、可写、错误和结束事件。关闭时关流并清理事件处理，外设需要时撤销发布。

## 流里连续来的字节自己分成消息

一次读取可能只拿到半条，也可能拿到多条。使用约定的长度前缀或其他帧格式累积、拆包。写入可能只交付部分数据，保留未写完的尾巴并等下一次可写事件。先从几字节的回声开始，再增大传输量。

**动手验证**　同一实现先让一条消息分两次发送，再连续发送两条，确认收到的数据边界仍能正确划分。

**一句话记住**　L2CAP 给 App 一条双向流，消息起止由双方协议约定。

## 自查题

1. **PSM 可以从扫描结果直接猜吗？** 从配件协议拿到 PSM，Core Bluetooth 不会替应用发现通道。
2. **一次 stream.read 等于一条完整消息吗？** 不保证，应用需要按帧规则切分。

[Apple CBL2CAPChannel 文档](https://developer.apple.com/documentation/corebluetooth/cbl2capchannel) · [Apple 发布通道方法](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager/publishl2capchannel%28withencryption%3A%29)

[上一章](#ios/development-guide/classic-bluetooth) · [正文目录](#ios/development-guide/overview)
