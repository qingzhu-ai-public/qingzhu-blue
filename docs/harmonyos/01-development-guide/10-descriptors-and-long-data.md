---
title: 09　读设备说明，再考虑长数据怎么拆
slug: descriptors-and-long-data
order: 100
---

# 09　读设备说明，再考虑长数据怎么拆

配件除了温度，还提供一项说明。另一条配置又比一次写入更长。两个问题分别要看描述符和数据长度。

## 先从特征下面找描述符

`getServices()` 的结果中可以沿服务、特征找到 `descriptors`。描述符附在某个特征下面，例如用户说明和订阅配置。按约定 UUID 选择目标后，`readDescriptorValue(descriptor)` 返回描述符对象，从 `descriptorValue` 取字节。普通可写描述符可按协议使用 `writeDescriptorValue`。

## 把传输上限和业务帧长度分别算

ATT MTU 影响一次操作可装多少数据。不同操作可用的字节数不一样。使用 `setBLEMtuSize` 的场景要根据目标 SDK、连接状态和实际协商结果处理。业务层还要考虑协议自己的序号、长度或校验字段。

先让两端约定分包编号、结束条件和超时处理，再按实际可用长度切数据。无响应写连续发送时要按设备与平台实际能力控制节奏。有响应写可以等本次完成再发下一片。

**自己试一次**　用两端已约定长度的测试帧，先发送一片，再测试一条消息拆两片，确认接收端能重组。

**一句话记住**　知道设备要你读哪一项，也要知道一次操作能装多少字节。

## 自查题

1. **一次写入成功代表整个业务帧已收齐吗？** 长帧要和接收端的重组及业务应答核对。

[华为 BLE API 参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-bluetooth-ble/)

[上一章](#harmonyos/development-guide/disconnect-and-reconnect) · [正文目录](#harmonyos/development-guide/overview) · [下一章](#harmonyos/development-guide/troubleshooting)
