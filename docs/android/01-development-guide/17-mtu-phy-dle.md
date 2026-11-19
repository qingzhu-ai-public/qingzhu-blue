---
title: MTU、PHY、DLE 与连接参数
order: 180
summary: MTU 决定一次能装多少，传得有多快还要看多久能发一次、无线怎么发和设备处理得有多快。
tags: SDK,BLE
updated: 2026-11-19
---

# 第 17 章　MTU、PHY、DLE 与连接参数

给电子标签传一张图。第一版每次发 20 字节，能用，就是慢。你想把一次写入改成长一点，需要先问清楚手机和标签一条 ATT 消息最多能放多少。

这个上限叫 **ATT MTU**。把它看成这条消息的总长度。普通写里有 1 字节操作码和 2 字节属性句柄，所以默认 MTU 23 时，值通常能放 20 字节。把 MTU 调大，一次可能放更多数据。两台协商出相同 MTU 的手机，传完全图的时间仍可能不同，后面再看无线速率、发送机会和设备处理速度。

## 手机请求更大的 MTU，等这条连接给出结果

API 21 起，手机可以在已经连接的 `gatt` 上调用 `gatt.requestMtu(247)`。返回 `true` 后等这次 GATT 的 `onMtuChanged(gatt, mtu, status)`。回调成功时，把它给出的 `mtu` 存在本次连接里，再计算每片能放多少数据。暂时没拿到协商值时，可以按默认 ATT MTU 23 做保守预算。等回调要设截止时间，与服务发现和订阅等初始化步骤排好顺序。

从 Android 14 起，同一 ACL 连接中首个请求 MTU 的 GATT 客户端触发平台请求 517 字节，后续请求会被忽略。对端较小的能力仍会决定最终协商值。新建连接在 API 37 的设置式入口中默认启用自动 MTU 协商，也要处理可能早于业务准备的 `onMtuChanged`。MTU 和缓冲需要以当前会话实测结果为准。

| ATT 操作 | 常见单 PDU 数据预算 |
| --- | --- |
| Write Request / Write Command | `min(ATT_MTU - 3, 512)`，再受属性、固件及 Android 接口限制 |
| 单特征 Notification / Indication | `min(ATT_MTU - 3, 512)` |
| Read Response / Read Blob Response | `min(ATT_MTU - 1, 512)`，长读需要多个 PDU |
| Prepare Write Request | `ATT_MTU - 5`，整个属性还受 512 字节上限和对端限制 |

MTU 23 时，普通写或通知可以承载 20 字节。若你的分片头占 6 字节，应用数据只剩 14 字节。超过单次预算的 Write Command 要在应用层分片，避免依赖栈截断或隐式长写。

## MTU 一样，为什么传得还是不一样快

文件传得有多快，还要看每次连接事件能送多少、两次发送机会隔多久，以及标签写入闪存要花多久。**PHY** 是无线传输用的模式，**DLE** 调整的是较低一层的数据包能装多少，连接参数则影响手机和设备有多频繁地安排通信。App 可以用下面的 API 请求或查看其中一部分。

| 方法或参数 | 调用方式 | 证明生效的证据 |
| --- | --- | --- |
| `setPreferredPhy(txPhy, rxPhy, phyOptions)`，API 26 | 使用 `PHY_LE_1M_MASK`、`PHY_LE_2M_MASK`、`PHY_LE_CODED_MASK` 及适合的 Coded 选项。先查适配器能力。 | `onPhyUpdate(gatt, txPhy, rxPhy, status)` 报告实际 PHY，返回的 PHY 常量与传入掩码不同。 |
| `readPhy()`，API 26 | 读取当前链路的发射与接收 PHY。 | `onPhyRead` 及其状态。 |
| `requestConnectionPriority(CONNECTION_PRIORITY_HIGH)`，API 21 | 在大批传输开始前提出高优先级偏好，完成后可恢复 `BALANCED`。 | 布尔返回表示请求结果，实际连接参数以系统事件或 HCI 为准。 |
| `onConnectionUpdated(gatt, interval, latency, supervisionTimeout, status)`，37.2 | 公开回调。interval 的单位为 1.25ms，supervisionTimeout 为 10ms，latency 以连接事件计。 | 成功回调记录当前所用值。 |
| `requestSubrateMode(mode)`，36.1 | 需要 `BLUETOOTH_CONNECT`，并要求系统特权或符合文档的 Companion 关联条件。 | 查立即状态码和 `onSubrateChange`，实测延迟与功耗。 |
| `readRemoteRssi()`，API 18 | 在已连接的 GATT 会话中申请读取当前 RSSI。布尔返回描述是否受理。 | 等 `onReadRemoteRssi(gatt, rssi, status)`。成功时 `rssi` 以 dBm 给出，和此前广播观测分开记录。 |

DLE 在链路层调整数据长度，影响传输某个 ATT PDU 需要几个链路层数据包。公开 GATT API 没有给普通应用提供对等的 DLE 调参入口。用 HCI 或空口数据区分 MTU 交换、PHY 更新和 Data Length Change。

`isLe2MPhySupported()` 和 `isLeCodedPhySupported()` 返回布尔值。API 37 的 `isLeHighDataThroughputPhySupported()` 返回 `BluetoothStatusCodes`，按 `FEATURE_SUPPORTED` 判断能力。能力查询只描述本机。已连接时，仍按实际 PHY 更新和对端能力判断能否使用。

## 一句话总结

**MTU 决定一次能装多少，传得有多快还要看多久能发一次、无线怎么发和设备处理得有多快。**

## 面试题

1. 请求 MTU 247 后为什么不能直接按 247 切片？
2. MTU 23，普通写的业务帧头占 6 字节，实际数据最多放多少？
3. 换成 2M PHY 以后，怎样知道它真用上了？

### 参考答案

1. 请求只表达期望。Android 14 起平台对首个请求使用 517，对端也可能只支持更小的值。按当前连接协商结果和固件限制计算。
2. 23 减掉 3 字节 ATT 开销，再减 6 字节业务帧头，剩 14 字节。
3. 用 `onPhyUpdate` 或 `onPhyRead` 的结果查看本次连接实际选用的 PHY，再比较对端确认的有效吞吐。

[BluetoothGatt](https://developer.android.com/reference/android/bluetooth/BluetoothGatt) · [BluetoothGattCallback](https://developer.android.com/reference/android/bluetooth/BluetoothGattCallback) · [Android 14 MTU 行为变更](https://developer.android.com/about/versions/14/behavior-changes-all#mtu-set-to-517) · [Bluetooth Core 6.2 ATT](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/attribute-protocol--att-.html)
