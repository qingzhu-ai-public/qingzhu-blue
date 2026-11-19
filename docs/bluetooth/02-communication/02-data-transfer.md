---
title: MTU、L2CAP 与业务分包
order: 20
summary: 按实际 ATT 操作计算载荷，区分链路分段与应用分包，并为配置命令设计回执。
tags: MTU, L2CAP, 分包
updated: 2026-11-19
---

# MTU、L2CAP 与业务分包

两字节的温度读数可以直接放进一次通知。要下载一段历史记录，往往就得拆成多次通知。先算每次操作能带多少字节，再决定接收端怎么把记录拼回去。

## 先算一条 ATT 操作的预算

LE 的固定 ATT 承载默认 ATT_MTU 为 23 字节。通过 MTU 交换，两端可以按各自的接收能力使用较大的值，有效值取双方通告值中较小的一个。应用按平台给出的有效限制发送，还要考虑外设特征和固件自身的长度限制。

| 单条 ATT 操作 | 该 PDU 中留给值的空间 | 默认 MTU 23 时 |
|---|---:|---:|
| Read Response | `ATT_MTU - 1` | 22 字节 |
| Write Request 或 Write Command | `ATT_MTU - 3` | 20 字节 |
| 单条 Handle Value Notification 或 Indication | `ATT_MTU - 3` | 20 字节 |
| Prepare Write Request | `ATT_MTU - 5` | 18 字节 |

这些数字只描述单条 PDU 的空间。属性值还受规范 512 字节上限和该特征自身的定义约束。ATT 也提供长读、长写流程，使用前要查平台 API 和外设是否支持所需操作。

## 三种长度各管一层

- **ATT_MTU** 限制一条 ATT PDU 的长度。
- **链路层数据长度** 影响一条链路层数据 PDU 能承载多少数据。Data Length Extension 调的是这一层，一条 ATT PDU 可以经下层拆到多个链路层包里。
- **应用消息长度** 由业务协议定义。历史记录跨多条通知时，接收端要依据应用协议重组。

L2CAP 把 ATT 等上层协议的数据分送到各自的通道。双方如果都开放了 LE L2CAP 面向连接通道（CoC），也可以把它用于自定义传输。CoC 流控用接收方授予的 credit 限制可发送的帧数。采用前先确认两端的 API 和协议约定，业务完成回执仍由应用定义。

## 用一条 37 字节记录算一次

假设通知能带 20 字节值，双方约定其中 4 字节用于消息编号和分片信息，每片可放 16 字节记录。37 字节的记录要发 3 片，分别装 `16 + 16 + 5` 字节。接收端用消息编号和分片序号归组，凑齐并检查长度后再交给业务，超时则清理这条未完成的记录。

传输连续的历史记录时，可以约定接收窗口或批次确认，给手机处理数据和外设释放缓冲区留出时间。写入采样间隔这类命令则单独约定结果，回执中带命令编号。超时重试沿用同一编号，外设据此识别重复命令，避免重复执行；如果外设无法去重，先读回状态再决定是否补发。

继续看 Android 的 [MTU、PHY、DLE 与连接参数](#android/development-guide/mtu-phy-dle)和[分包、重组、确认与流控](#android/development-guide/fragmentation-flow)。

## 参考

[Bluetooth Core 6.2 ATT](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/attribute-protocol--att-.html) · [Bluetooth Core 6.2 L2CAP](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/logical-link-control-and-adaptation-protocol-specification.html)
