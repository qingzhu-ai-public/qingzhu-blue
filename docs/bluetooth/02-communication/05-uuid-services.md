---
title: UUID 与标准服务
order: 20
summary: 16 位与 128 位 UUID 的关系，电量温湿度等标准服务，小端与符号位两大解析坑。
tags: GATT, UUID
updated: 2026-11-24
---

# UUID 与标准服务

你给温度计定义了一个 128 位的服务 UUID，随机生成的，很长。连上另一台大厂手环，发现它的电池服务 UUID 只有四位：`180F`。这不是它偷工减料，而是蓝牙世界有两套 UUID 用法：SIG 分配的标准编号，和你自己生成的自定义编号。分清这两套，你就知道哪些轮子不用造。

## 16 位和 128 位是同一个体系

蓝牙 UUID 本质上都是 128 位。SIG 把其中一段保留出来，分配给标准服务和特征，登记在 [Assigned Numbers](https://www.bluetooth.com/specifications/assigned-numbers/) 里。16 位编号是这段的简写，展开规则是嵌进固定的 **Base UUID**。

```text
Base UUID    00000000-0000-1000-8000-00805F9B34FB
16 位 0x180F → 0000180F-0000-1000-8000-00805F9B34FB
```

所以 `180F` 和 `0000180F-0000-1000-8000-00805F9B34FB` 是同一个 UUID，平台 API 里两种写法都常见。看到四位编号，先查 Assigned Numbers；查不到的自定义 UUID，含义由厂商文档定义。

自定义 UUID 自己生成，用任何 UUID v4 生成器（命令行 `uuidgen`、在线工具都行），**不要**落在 Base UUID 那一段里，避免和未来的标准编号撞车。一个产品线约定一组，写进协议文档，固件和 App 共用。

## 每台设备几乎都有的两个服务

连上任何 BLE 设备，服务列表开头常常是这两个。

| 服务 | UUID | 里面有什么 |
|---|---|---|
| Generic Access | `0x1800` | 设备名、外观等 GAP 信息 |
| Generic Attribute | `0x1801` | GATT 服务自身的信息，如 Service Changed |

它们是协议栈自带的，不用你实现，也解释了「为什么设备明明只有一个自定义服务，列表里却有三四个」。

## 值得先查一遍的标准服务

做传感器类产品，下面这些标准服务大概率用得上。用了标准服务，任何通用工具（nRF Connect、系统设置）都能直接读懂你的设备，联调省一大截力气。

| 服务 | UUID | 关键特征 | 数据格式 |
|---|---|---|---|
| Device Information | `0x180A` | 厂商名 `0x2A29`、型号 `0x2A24`、固件版本 `0x2A26` | UTF-8 字符串 |
| Battery Service | `0x180F` | Battery Level `0x2A19` | uint8，0–100 的百分比 |
| Environmental Sensing | `0x181A` | 温度 `0x2A6E`、湿度 `0x2A6F` | 温度 sint16，单位 0.01 °C；湿度 uint16，单位 0.01 % |
| Heart Rate | `0x180D` | Heart Rate Measurement `0x2A37` | 首字节标志位 + 心率值 |
| Current Time | `0x1805` | Current Time `0x2A2B` | 年月日时分秒等打包 |

拿温度特征算一遍。24.10 °C 按 0.01 °C 单位是 2410，十六进制 `0x096A`，小端传输就是 `6A 09`。湿度 45.20 % 是 4520，`0x11A8`，空口上 `A8 11`。零下温度用有符号数：-5.50 °C 是 -550，补码 `0xFDDA`，空口 `DA FD`。这些格式定义在 [GATT Specification Supplement](https://www.bluetooth.com/specifications/specs/gatt-specification-supplement/)，字段几个字节、什么符号、什么单位，都以它为准。

```text
读到 6A 09 → 小端还原 0x096A → 2410 → ×0.01 → 24.10 °C
读到 DA FD → 小端还原 0xFDDA → 按 sint16 解释 -550 → -5.50 °C
```

新手最常见的解析错误就在这两处：字节序搞反（2410 变 27145），或者把有符号数当无符号数（零下变六万多度）。

## 标准服务和自定义服务怎么选

- **有标准就用标准**。电量、温度、湿度、设备信息，SIG 都定义好了，固件和 App 都少写文档，通用工具直接可读。
- **业务特有的用自定义**。采样策略、历史记录下载、OTA 通道，标准没覆盖，自己定义 UUID 和协议，写清字节格式。
- **混合很常见**。一台温湿度计同时挂 Environmental Sensing、Battery、Device Information 三个标准服务，再加一个自定义服务管历史记录，互不冲突。

还有一条路是**行业开放标准**，比如温湿度计常用的 [BTHome](https://bthome.io/)：它不建连接，直接把标准化格式的读数放进广播的服务数据里，Home Assistant 等生态开箱即用。本指南的 Android 综合实战做的就是 [BTHome 温湿度计](#android/bthome-mvp/prototype)，可以对照「广播路线 + 开放标准」和「连接路线 + 标准 GATT 服务」两种做法的取舍。

## 一句话总结

**16 位 UUID 是 SIG 标准编号的简写，展开靠 Base UUID；电量温度这类数据先查标准服务，业务特有的才自定义，格式以 GSS 和厂商文档为准，小端和符号位是解析两大坑。**

## 面试题

1. `0x2A6E` 展开成 128 位 UUID 是什么？
2. 温度特征读到 `DA FD`，温度是多少？说出换算步骤。
3. 为什么自定义 UUID 不要落在 `0000xxxx-0000-1000-8000-00805F9B34FB` 这一段？
4. 你的温湿度计想同时被 nRF Connect 直接读懂、被 Home Assistant 免连接接收，分别可以怎么做？

### 参考答案

1. `00002A6E-0000-1000-8000-00805F9B34FB`，把 16 位值嵌入 Base UUID 的第 3、4 字节位置。
2. 小端还原为 `0xFDDA`，温度特征是 sint16，按补码解释是 -550，单位 0.01 °C，即 -5.50 °C。
3. 这一段保留给 SIG 分配标准编号，自定义值落进去可能和现在或将来的标准定义冲突。
4. 前者实现标准 Environmental Sensing 服务（0x181A），温度和湿度用标准特征；后者按 BTHome 格式把读数放进广播服务数据。两者可以同时做。

## 参考

[Assigned Numbers](https://www.bluetooth.com/specifications/assigned-numbers/) · [GATT Specification Supplement](https://www.bluetooth.com/specifications/specs/gatt-specification-supplement/) · [Battery Service 规范](https://www.bluetooth.com/specifications/specs/battery-service-1-1/) · [BTHome](https://bthome.io/)