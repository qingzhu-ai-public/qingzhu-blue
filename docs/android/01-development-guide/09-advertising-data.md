---
title: BLE 广播数据与解析
order: 100
summary: 广播像设备在连接前递来的名片，先核对它写了什么，再决定列表上显示什么。
tags: SDK,BLE
updated: 2026-11-19
---

# 第 9 章　BLE 广播数据与解析

扫描列表里出现两台同名的温度计。你希望只显示自己的型号，就需要看看每台设备在广播里放了什么。蓝牙设备可以在连接前广播名称、服务 UUID 或厂商数据。手机扫描到的是设备当时发出来的信息。

用 `result.scanRecord` 取这次收到的广播记录。如果要看这条广播声明的名字，查 `ScanRecord.getDeviceName()`。如果读 `BluetoothDevice.getName()`，得到的是系统缓存的名字。有些设备会把名字放到收到扫描请求后才发出的 Scan Response，也有设备根本没放名字。可以先把两种名字都打印出来，再挑实际稳定存在的字段做匹配。

## 从字节看 AD Structure

设备把几种信息放进同一条广告数据里，每一段叫 AD Structure。先读这一段有多长，再看类型是哪一种，最后解释它的数据。长度计入类型和数据。从下面第一行看，`02` 让你再读两个字节，`01` 说明这一段是 Flags，`06` 才是 Flags 的值。

```text
02 01 06      Flags（结构长度 2，类型 0x01，值 0x06）
03 03 0F 18   完整 16 位 Service UUID 列表（这里有 0x180F）
04 FF 34 12 01  厂商数据（演示公司 ID 0x1234，后续内容 01）
```

示例公司 ID 仅用于演示解析。产品发送厂商数据应使用协议约定且有权使用的 SIG 公司标识。`getManufacturerSpecificData(0x1234)` 返回 `01`，公司 ID 已被解析为键。对端协议表若从第一个厂商数据字节开始编号，解析时无需再跳过两字节。

| API | 结果与边界 |
| --- | --- |
| `ScanResult.getScanRecord()` | 可能为 `null`。有记录时也可能缺少某种 AD 类型。 |
| `ScanRecord.getBytes()` | Android 提供的原始扫描记录。适合分析自定义 AD 类型或排查解析问题。 |
| `getServiceUuids()` | 广播宣告的 UUID 列表，不保证等于建连后发现的服务表。 |
| `getServiceSolicitationUuids()` | API 29，读取广播请求对端提供的服务 UUID。与广播自身提供的服务列表分开解析。 |
| `getServiceData(ParcelUuid)` | 用 UUID 查 service data，返回的数据不含 UUID 前缀。 |
| `getManufacturerSpecificData(int)` | 用 16 位公司 ID 取业务数据，可无匹配。无参重载返回按 ID 组织的集合。 |
| `getAdvertisingDataMap()` | API 33，按 AD 类型查看解析数据。需要保留原始顺序或重复类型时解析 `getBytes()`。 |
| `ScanResult.getRssi()` / `getTimestampNanos()` | RSSI 为 dBm，时间戳是自启动以来的单调时间。用于计算记录新鲜度。 |
| `isConnectable()` / `isLegacy()` / `getDataStatus()` | API 26 起可查询连接性、传统/扩展类型和数据状态。截断数据不能当作完整协议帧。 |

## 把广播字节变成列表里的内容

假设厂商文档说业务数据的第一个字节是版本，第二个字节开始才是型号。App 要先看有没有足够的字节，再取出版本和型号。Kotlin 的 `Byte` 有符号，读无符号字段时用 `toInt() and 0xff`。小端 16 位字段先把高低两个字节都转成无符号值，再移位合并。包截断或者版本未知时，记下原始观测，这一条先不当作识别成功。

如需手动遍历 AD 结构，令 `i` 指向长度字节。每次读取无符号长度 `n`，遇到零停下。若 `n > bytes.size - i - 1`，说明剩余字节不足。否则类型在 `i + 1`，处理后推进到 `i + n + 1`。读取 RSSI 和解析设备身份是两条独立路径。RSSI 适合粗筛，地址用于下一次会话连接，稳定身份按 [第 20 章](#android/development-guide/address-privacy) 设计。

## 一句话总结

**广播像设备在连接前递来的名片，先核对它写了什么，再决定列表上显示什么。**

## 面试题

1. 广播原始字节里有 `04 FF 34 12 01`，调用 `getManufacturerSpecificData(0x1234)` 会拿到什么？
2. 设备文档列了一个服务 UUID，为什么不能保证用该 UUID 的广播过滤能命中？

### 参考答案

1. 拿到业务字节 `01`，Android 已经把小端公司 ID `34 12` 解析成键 `0x1234`。
2. 过滤匹配设备实际宣布的广播字段，服务也可能只在连接后的属性表里出现。先打印 `ScanRecord` 对照。

[ScanRecord](https://developer.android.com/reference/android/bluetooth/le/ScanRecord) · [ScanResult](https://developer.android.com/reference/android/bluetooth/le/ScanResult) · [Bluetooth SIG Assigned Numbers](https://www.bluetooth.com/specifications/assigned-numbers/)
