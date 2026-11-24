---
title: 实验 用 nRF Connect 走通一条链路
order: 10
summary: 不写代码，用手机把扫描、连接、读写、订阅走一遍，双机模拟外设。
tags: 动手, 实验
updated: 2026-11-24
---

# 实验　用 nRF Connect 走通一条链路

不写一行代码，把导读里那条链路亲手走一遍。你需要的只是一部手机，装 Nordic 官方的 nRF Connect for Mobile（Android 在 Google Play 或 Nordic 官网下载，iOS 在 App Store 搜 nRF Connect）。附近任何 BLE 设备都能当观察对象——手环、耳机、别人的手机都行；想完整做读写和订阅，最好有第二部 Android 手机，用它模拟一台外设。

做完这个实验，正文里的广播、连接、服务、特征、CCCD 全都见过实物，后面读代码章节会顺很多。

## 准备

- 一部主力手机，装好 nRF Connect。Android 首次扫描需要授予附近设备/位置权限，按提示给。
- 观察对象：任何在广播的 BLE 设备。找不到就用第二部 Android 手机，nRF Connect 里自带 Advertiser 功能，几步就能造出一台。
- 本篇截图式的按钮名称以 Android 版为准，iOS 版布局不同但功能对应，找不到时按功能名找。

## 第一步　扫描，读一条真实广播

打开 App 停在 SCANNER 页，点 SCAN。列表会涌出附近的设备，每行有名字（或 N/A）、地址、RSSI。

1. 找一台名字眼熟的设备，点行展开，看它的广播字段：Flags、Local Name、Service UUIDs、Manufacturer Data，和你手上任何一份协议文档能对起来。
2. 点 RAW，看原始字节。对照[广播与扫描](#bluetooth/fundamentals/advertising)的「长度+类型+数据」规则，亲手拆一条 `02 01 06`。
3. 观察 RSSI 数字跳动。把设备挪远、用手握住，看数值怎么变。这就是「RSSI 不能当硬过滤条件」的体感。
4. 试试顶部过滤：按名字、按 RSSI、只看有名字的。再想想：如果设备名在扫描响应里，哪种过滤会漏掉它。

**检查点**：你能从原始字节里指出 Flags 和名字各在哪个位置。

## 第二步　连接，看服务表

对一台可连接设备点 CONNECT（不可连接的设备没有这个按钮，这本身就是广播类型的体现）。

1. 连上后切到 CLIENT 页，看服务列表。开头通常是 Generic Access（0x1800）和 Generic Attribute（0x1801），往下才是设备自己的服务。
2. 展开一个服务，看特征和它的属性标记：READ、WRITE、NOTIFY。每个特征下面若有 Client Characteristic Configuration（0x2902），那就是 CCCD。
3. 对照[UUID 与标准服务](#bluetooth/communication/uuid-services)：有 Battery Service 吗？点开读一下 Battery Level，读到的一个字节就是电量百分比。

**检查点**：你能说出这台设备有哪些服务，哪个特征可读、哪个可订阅。

## 第三步　读、写、订阅

找一台有可交互特征的设备（下一步自己造的最方便）。

1. **读**：点特征旁的向下箭头（Read）。值栏出现字节，按设备协议解释它。
2. **写**：点向上箭头（Write），输入一个值发送。观察写入是否成功、设备行为有没有变化。
3. **订阅**：点三个向下箭头的图标（Enable Notifications），这就是 App 帮你写 CCCD `01 00`。让设备产生新数据，值栏应持续刷新。再点一次关闭订阅，对应写 `00 00`。
4. 切到 LOG 页，回看刚才每一步的日志：连接、发现服务、写描述符、收到通知，全有时间戳。这就是[排障](#bluetooth/communication/troubleshooting)里说的「时间线」的现成样板。

**检查点**：你亲眼看到「写 CCCD 之后数据才开始流」，并能指出日志里对应的那一行。

## 第四步　用第二部手机造一台外设

第二部 Android 手机装 nRF Connect，做两件事。

1. **ADVERTISER 页**：新建一条广播，加 Local Name（比如 `TempLab`）和一条 Manufacturer Data，开始广播。回到主力手机扫描，找到它，拆它的广播字节——这次每个字段都是你自己放的。
2. **SERVER 页**：添加一个服务（可以从预置里选，比如 Battery Service 或自定义），配置一个支持 Read/Notify 的特征。主力手机连接它，读值、订阅，然后在第二部手机上改值并发送通知，看主力手机实时收到。

没有第二部手机时，用任何现成 BLE 外设完成读和订阅，跳过造外设的部分，实验价值不减。

**检查点**：你同时见过链路的两端——一端发通知的日志，一端收通知的日志。以后排障要两边对时间线，你已经知道那是什么样子。

## 第五步　配对与解绑（可选）

如果设备要求配对，读写时会弹系统配对框。完成后在 BONDED 页能看到绑定记录，试试 Remove bond，再读写一次，观察安全错误怎么出现。这就是[配对与绑定](#bluetooth/communication/security)里「手机侧取消绑定」场景的实物版。

## 把实验映射回正文

| 你做的事 | 对应概念 | 正文 |
|---|---|---|
| 展开广播、看 RAW | AD Structure、扫描响应 | [04 广播与扫描](#bluetooth/fundamentals/advertising) |
| CONNECT 后看服务表 | 服务发现、GATT 对象 | [06 GATT 与 ATT](#bluetooth/communication/gatt-att) |
| 读 Battery Level | 标准服务、数据格式 | [07 UUID 与标准服务](#bluetooth/communication/uuid-services) |
| 三箭头订阅 | CCCD、Notify | [06 GATT 与 ATT](#bluetooth/communication/gatt-att) |
| LOG 页时间戳 | 会话时间线 | [10 排障](#bluetooth/communication/troubleshooting) |
| Remove bond | 绑定与密钥清理 | [09 配对与隐私](#bluetooth/communication/security) |

下一步选平台写代码：[Android 导读](#android/development-guide/guide) · [iOS 第一篇](#ios/development-guide/first-app) · [HarmonyOS 第一篇](#harmonyos/development-guide/first-app)。

## 一句话总结

**nRF Connect 是一台不用写代码的通用客户端，扫描、连接、读写、订阅、日志全都有；先用它把链路走通，正文的每个概念就都有了实物。**

## 面试题

1. 不可连接的设备在 nRF Connect 里没有 CONNECT 按钮，这对应广播的什么性质？
2. 三箭头图标按下后，App 实际向设备写了什么？
3. 想验证「RSSI 不可靠」，在实验里怎么做？

### 参考答案

1. 它发的是不可连接广播（如 ADV_NONCONN_IND），只发数据不接受连接。
2. 向该特征的 CCCD（0x2902）写入开启值，Notify 是 `01 00`，Indicate 是 `02 00`。
3. 固定设备和手机位置记录 RSSI，再遮挡、换姿态、挪动，观察同一设备数值的波动幅度。

## 参考

[Nordic BLE 入门课第一课](https://academy.nordicsemi.com/topic/blefund-lesson-1-exercise-1/) · [Android-nRF-Connect 功能说明](https://github.com/NordicSemiconductor/Android-nRF-Connect/blob/main/documentation/README.md)