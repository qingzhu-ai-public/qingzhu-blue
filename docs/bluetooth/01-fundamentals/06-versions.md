---
title: 版本与能力演进
order: 30
summary: 从 4.0 到 6.2 的能力地图，版本号不承诺特性，接设备先问能力清单。
tags: 入门, 版本
updated: 2026-11-24
---

# 版本与能力演进

设备说明书上写着「蓝牙 5.0」，你的第一反应可能是：它比 4.2 的设备快多少？这个问法本身就掉进了坑里。蓝牙的版本号标记的是设备按哪一版规范做了认证，不承诺任何一项具体能力。一台标 5.0 的设备完全可以不实现 2M PHY。这一篇给你一张「版本号 → 能力 → 对开发者意味着什么」的地图，以后看到版本号，知道该追问什么。

## 一张演进表

从 4.0 开始，每一版只列对应用开发者有实际影响的变化。

| 版本 | 发布时间 | 关键能力 | 对开发者意味着什么 |
|---|---|---|---|
| 4.0 | 2010 | 引入 BLE，GATT/ATT 体系 | 传感器类设备的起点，纽扣电池成为可能 |
| 4.1 | 2013 | 与 LTE 共存改进，LE 双角色拓扑 | 一台设备可以同时当 Central 和 Peripheral |
| 4.2 | 2014 | 数据长度扩展（DLE）、LE Secure Connections、链路层隐私 | 吞吐明显提升；配对用上椭圆曲线；隐私地址下沉到链路层 |
| 5.0 | 2016 | 2M PHY、Coded PHY、扩展广播 | 速率翻倍或距离换速率的选项；广播不再限于 31 字节 |
| 5.1 | 2019 | 测向（AoA/AoD）、GATT 缓存改进 | 室内定位有了标准手段；重连后服务发现可以更快 |
| 5.2 | 2020 | LE Audio（LC3、等时信道）、EATT、增强功率控制 | 音频从经典蓝牙走向 BLE；多条 ATT 承载并发 |
| 5.3 | 2021 | 连接子速率（Subrating）、周期广播增强、加密密钥长度控制 | 空闲连接更省电；主机可强制最小密钥长度 |
| 5.4 | 2023 | PAwR（带响应的周期广播）、广播数据加密 | 无连接的双向一对多通信，电子价签是典型场景 |
| 6.0 | 2024 | Channel Sounding（信道探测测距）、基于决策的广播过滤 | 厘米级安全测距，数字钥匙和查找类应用的基础 |
| 6.1 | 2025 | 随机化 RPA 更新时机 | 隐私地址在随机时间更换，更难被追踪，控制器自主处理更省电 |
| 6.2 | 2025 | 更短连接间隔（最小 7.5 ms 降到 375 µs）、测距抗振幅攻击、HCI USB 等时支持 | 高性能 HID 和实时交互的延迟上限被打开 |

6.0 之后规范改为每年两版，5 月和 11 月各一次，所以 6.1、6.2 挨得很近。[Bluetooth Core 6.2 发布说明](https://www.bluetooth.com/blog/just-released-bluetooth-core-6-2/) · [6.1 随机化 RPA 说明](https://www.bluetooth.com/zh-cn/blog/enhancing-device-privacy-and-energy-efficiency-with-bluetooth-randomized-rpa-updates/)

## 版本号不承诺能力

SIG 自己反复强调这一点：描述产品时应该说它支持哪些**特性**，而不是它按哪版规范认证。原因有三层。

1. 规范里大量能力是**可选的**。2M PHY、Coded PHY、扩展广播、LE Audio，设备都可以不实现，照样通过 5.x 认证。
2. 能力要**两端都支持**才生效。手机支持 2M PHY，传感器只支持 1M，连接就用 1M。MTU、DLE 也是同样道理，有效值取两端较小者。
3. 能力还要**系统开放接口**。芯片支持不等于手机系统给了 API。Android 到 8.0 才有 PHY 相关接口，扩展广播的扫描接口更晚。

所以接一台新设备，正确的问法是把版本号换成一张能力清单：支持哪些 PHY？ATT MTU 能到多少？支持 DLE 吗？广播用传统还是扩展？配对用 Legacy 还是 Secure Connections？这些问题设备厂商都答得上来，答不上来的就实测。

## 对应用开发者最重要的三次变化

四十多个特性里，真正改变日常开发的是这三处。

**4.2 的 DLE 和 Secure Connections。**DLE 把一条链路层数据包的载荷从 27 字节提到最高 251 字节，配合 MTU 交换，应用吞吐从「每包 20 字节」时代进入「每包两百多字节」时代。Secure Connections 把配对密钥交换升级为 ECDH，Just Works 之外的配对方式获得中间人防护。今天做分包和安全设计，默认基线就是 4.2。细节见 [MTU 与分包](#bluetooth/communication/data-transfer)和[配对与加密](#bluetooth/communication/security)。

**5.0 的 PHY 与扩展广播。**2M PHY 用更短的发射时间换功耗和吞吐；Coded PHY 用冗余编码换距离，速率降到 500 或 125 kbit/s。扩展广播把广播数据从 31 字节的限制里解放出来，周期广播让接收端能同步到固定的广播时序。但接收端支持度参差，用之前先查目标手机。

**5.2 起的 LE Audio。**音频不再只能走经典蓝牙的 A2DP。LC3 编码加等时信道，让 BLE 也能传音频，还带来 Auracast 广播音频这种一对多场景。做耳机类产品的要关注，做传感器的可以先跳过。Android 侧的接口现状见[低功耗音频与蓝牙测距](#android/development-guide/le-audio-ranging)。

## 一句话总结

**版本号是认证标签，能力清单才是合同；接设备先问 PHY、MTU、DLE、广播类型和配对方式，两端和系统三方都点头，能力才算数。**

## 面试题

1. 一台标称蓝牙 5.0 的传感器，一定能用 2M PHY 通信吗？
2. DLE 和 ATT MTU 交换分别调整哪一层的长度？只做其中一个，吞吐会怎样？
3. 手机和传感器都支持 Coded PHY，什么场景下值得用它？代价是什么？
4. 6.0 引入的 Channel Sounding 解决什么问题？和用 RSSI 估距离有什么区别？

### 参考答案

1. 不一定。2M PHY 是可选特性，版本号不承诺实现。要查设备的能力声明，且手机侧也要支持并开放接口。
2. DLE 调链路层数据 PDU 的载荷长度，MTU 调一条 ATT PDU 的长度。只提高 MTU 不开 DLE，一条 ATT PDU 会被拆成多个 27 字节的小包，空口效率低；只开 DLE 不换 MTU，应用每次仍只能发 20 字节值。两者配合才有明显吞吐提升。
3. 距离远、遮挡多、对速率要求低的场景，比如户外抄表。代价是速率降到 500 或 125 kbit/s，同样的数据要占用更长的发射时间。
4. 解决精确且安全的距离测量。RSSI 受环境和天线姿态影响大，只能粗估；Channel Sounding 用相位测距加往返时间两种方法，达到厘米级精度，并能抵抗中继攻击。

## 参考

[Core 规范变更历史](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-54/out/en/architecture,-mixing,-and-conventions/core-specification-change-history.html) · [Core 6.0 特性概览](https://www.bluetooth.com/core-specification-6-feature-overview/) · [Core 6.2 特性概览](https://www.bluetooth.com/bluetooth-core-6-2-feature-overview/)