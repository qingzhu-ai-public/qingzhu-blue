---
title: GAP 广播、扫描与设备发现
order: 30
summary: 区分可扫描和可连接，读懂广播字段，并验证筛选条件为什么漏掉设备。
tags: GAP, 广播
updated: 2026-11-19
---

# GAP 广播、扫描与设备发现

设备名称显示在列表里，说明手机收到了某些广播数据。要判断能不能连，还要看广播是否允许连接。只发温度的信标可以一直被扫到，也可以从头到尾都不接受连接。

## 先认清角色

在常见的 BLE 场景里，传感器想被手机连接时，以 Peripheral 的身份发可连接广播。手机负责发起连接，是 Central。只发广播和只接收广播时，分别对应 Broadcaster 和 Observer。

可扫描的广播允许扫描端发请求，再从响应里拿额外数据。被动扫描只接收已发出的广播。传统广播有只允许扫描响应、却不接受连接的类型。把设备名放在扫描响应里时，接收端是否拿得到它，还取决于扫描方式和平台是否交付这部分数据。

## 读一段广播数据

例如，设备把以下两项放进传统广播。每项 AD Structure 的第一个字节是长度，计入后面的类型和数据，长度字节本身另算。

```text
02 01 06  05 09 54 65 6D 70
```

| 字节 | 含义 |
|---|---|
| `02 01 06` | 后面有 2 字节，`0x01` 是 Flags，值为 `0x06` |
| `05 09 54 65 6D 70` | 后面有 5 字节，`0x09` 表示完整本地名称，随后 4 字节是 `Temp` |

解析时先用长度验证边界，再按类型读取数据。厂商自定义广播常用 Manufacturer Specific Data，里面的 Company Identifier 和随后由厂商定义的字节要分别解释。按厂商协议文档确定字段长度和字节序。

## 广播预算与筛选

传统广播的广告数据和扫描响应数据各最多 31 字节，每项 AD Structure 的长度和类型也要占空间。扩展广播可以承载更多数据，周期广播可以让接收端同步到既定广播时序。选用这些能力前，先确认接收设备和系统接口能否使用。

联调时先短时间去掉过滤，记录设备实际发出的字段，再逐项加回服务 UUID、厂商数据或名称条件。服务 UUID 可能没有被写进广播，却能在连接后发现。RSSI 会随遮挡、天线姿态和环境变化，适合辅助排序。需要稳定识别设备时，按[地址隐私与业务身份](#bluetooth/communication/security)设计。

Android 实现看[广播数据与解析](#android/development-guide/advertising-data)和[扫描全流程](#android/development-guide/scanning)。准备建连时，接着看[连接参数与就绪条件](#bluetooth/fundamentals/connection)。

## 参考

[Bluetooth Core 6.2 GAP](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/generic-access-profile.html) · [Core Specification Supplement 数据类型](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/CSS_v14/out/en/core-supplementary-features/data-types-specification.html)
