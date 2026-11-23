---
title: 15　发不完的一条消息，怎样拆开来发
slug: packet-flow
order: 160
---

# 15　发不完的一条消息，怎样拆开来发

改配置只写一个字节。换成文件片段就可能超出一次写入长度，先问系统能发多大，再决定怎样拆。

## 先得到这一连接的写入上限

```swift
let limit = peripheral.maximumWriteValueLength(for: .withoutResponse)
```

`for:` 要和实际写入方式一致，这个值是 App 能交给该写操作的最大数据长度。业务帧有包号、长度和校验字段时，要先把它们的字节数算进去。对端也应明确最大可接收的业务帧长度。

## 一包一包发，接收端知道怎样拼回去

假设双方约定每片用 3 字节表明片序号和帧信息，当前写上限为 20，则每片最多放 17 字节业务数据。接收端需要知道何时开始、何时收齐，以及缺片怎么处理。重复、超时和重连后的处理规则也由协议约定。

有响应写可以等 `didWriteValueFor` 再推进队列。无响应写应在每次发之前看 `canSendWriteWithoutResponse`，false 时保留剩余队列，等 `peripheralIsReady(toSendWriteWithoutResponse:)` 后继续。外设主动更新使用 `maximumUpdateValueLength` 和自己的就绪回调。

**动手验证**　先记录两种写类型的上限，再用一条长消息验证按长度拆分及接收端重组。

**一句话记住**　系统告诉你一口能发多少，协议告诉两端多口怎么拼回去。

## 自查题

1. **得到上限后能直接减去 ATT 头吗？** 这是 Core Bluetooth 给写入值的上限，应用应扣自己的额外业务字段。
2. **无响应写排满后还能一直调用吗？** 暂停并等待系统就绪回调。

[Apple CBPeripheral 写入文档](https://developer.apple.com/documentation/corebluetooth/cbperipheral)

[上一章](#ios/development-guide/two-device-lab) · [正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/pairing-security)
