---
title: 10　读一项设备说明，认识描述符
slug: descriptors
order: 110
---

# 10　读一项设备说明，认识描述符

特征下面有时还挂着说明，例如这组数据供用户看的名字。这个附属信息叫描述符。

## 从已发现的特征下面继续找

调用 `peripheral.discoverDescriptors(for: characteristic)`。等 `didDiscoverDescriptorsFor` 返回后，从 `characteristic.descriptors` 按协议所需的 UUID 找到对象。设备没提供描述符时，页面可以沿用自己的默认名称。

读取描述符调用 `peripheral.readValue(for: descriptor)`。回调 `didUpdateValueFor descriptor` 和读取特征的回调名字类似，但参数类型是 `CBDescriptor`。结果从 `descriptor.value` 获取，类型按描述符定义判断。比如用户说明可先尝试 `descriptor.value as? String`。

## 写之前查设备协议

对协议明确支持写入的描述符，使用 `peripheral.writeValue(data, for: descriptor)`，结果看描述符版本的 `didWriteValueFor`。CCCD 的订阅配置有专门的 `setNotifyValue`，这一点要和自定义可写描述符区分开。

**动手验证**　找一台提供用户说明描述符的外设，先列出 UUID，再读描述符内容。实战教学特征没提供这项说明时，记录为空即可。

**一句话记住**　特征放业务数据，描述符补充说明或配置。

## 自查题

1. **发现描述符时传服务还是特征？** 传它所属的特征。
2. **描述符读取一定得到 Data 吗？** 检查该描述符的定义和 value 的实际类型。

[Apple CBDescriptor 文档](https://developer.apple.com/documentation/corebluetooth/cbdescriptor)

[上一章](#ios/development-guide/notification) · [正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/reconnect)
