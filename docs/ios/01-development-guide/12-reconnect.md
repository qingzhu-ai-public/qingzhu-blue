---
title: 11　设备走远了，回来时怎么接上
slug: reconnect
order: 120
---

# 11　设备走远了，回来时怎么接上

打开读数页后把外设拿远。收到断开回调时，App 冻结请求按钮。设备回来后再尝试恢复。

## 先处理这次断开

在 `didDisconnectPeripheral` 记录外设标识、当时阶段和错误。区分用户主动取消和意外断开。清空本次服务、特征与等待结果。页面可以保留上一次读数，但清楚显示断开状态。

## 再从三条路径选设备

| 用途 | 调用 |
| --- | --- |
| 用户重新找附近设备 | `scanForPeripherals(withServices:options:)` |
| App 保存过本机的设备标识 | `retrievePeripherals(withIdentifiers:)` |
| 查系统已连接并匹配服务的设备 | `retrieveConnectedPeripherals(withServices:)` |

取回对象后仍通过 `connect(_:options:)` 建立 App 自己的本地连接。重连成功后按需要重新发现服务和特征，再恢复订阅。重复意外掉线时，给重试设置次数或间隔，用户取消时停止后续重试。

**动手验证**　断开后重开外设，先手动扫描重连一次，再考虑自动恢复。检查旧读写没有进入新的连接。

**一句话记住**　断开先清掉这次会话，重连后重新确认哪些操作可以继续。

## 自查题

1. **缓存标识能保证当前在附近吗？** 取回已知对象不等于此刻可连接。
2. **为何要在重连后确认订阅？** 上一轮连接里的订阅状态不能直接拿来当这一轮的结果。

[Apple CBCentralManager 文档](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager)

[上一章](#ios/development-guide/descriptors) · [正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/peripheral)
