---
title: 08　从手机给温度计发一条指令
slug: write
order: 90
---

# 08　从手机给温度计发一条指令

想让温度计重新测一次，或者改为每五秒上报一次。手机先按设备协议把操作编码，再写到对应特征。

## 先确认设备约定

实战里写 `01` 表示请求新读数。真实设备的上报间隔可能用不同特征和字节。例如「五秒编码为 05」必须由协议约定。找到特征后先看属性，再选写入方式。

```swift
peripheral.writeValue(Data([0x01]), for: sample, type: .withResponse)
```

有响应写需要特征带 `.write`，结果通过 `didWriteValueFor` 返回。实战等它成功后再发起读取。写成功表示这次 ATT 写有成功反馈。设备业务是否完成，要按协议读结果、等通知或核对业务应答。

## 什么时候用无响应写

无响应写需要 `.writeWithoutResponse`。调用时传 `.withoutResponse`，系统不会为每次写入给 App 一条 `didWriteValueFor`。批量发送时要看 `canSendWriteWithoutResponse`，变为 false 就暂停，等 `peripheralIsReady(toSendWriteWithoutResponse:)` 后继续。业务可靠性需要协议另行设计。

**动手验证**　对照实战写入和读回的提示。用不支持的命令值应看到外设返回写错误，客户端不会直接读结果。

**一句话记住**　写方法把字节交出去，响应和业务结果分别要在各自的位置确认。

## 自查题

1. **无响应写可用写回调排队吗？** 应使用可发送状态和就绪回调来控制发送。
2. **为什么教程先用有响应写？** 能看到写入结果，比较容易把失败定位到具体阶段。

[Apple CBCharacteristicWriteType](https://developer.apple.com/documentation/corebluetooth/cbcharacteristicwritetype)

[上一章](#ios/development-guide/read-and-decode) · [正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/notification)
