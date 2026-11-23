---
title: 04　只显示要找的温度计
slug: scan-filters
order: 50
---

# 04　只显示要找的温度计

扫描能收到很多结果。把列表缩小到教学温度计，用户就不必靠名字猜哪个能连。

## 把服务 UUID 交给扫描器

```swift
let teachingService = CBUUID(string: "476CDF45-6063-43A1-B8E2-8C1FBED00601")
central.scanForPeripherals(withServices: [teachingService], options: nil)
```

这里筛的是广播中声明的服务。对于已经连上的设备，还要重新发现服务并检查特征。外设文档写了某 UUID 时，应先确认它是否放在广播里。设备支持某服务，并不必然在每次广播中公布它。

## 用标识更新行

`peripheral.identifier` 是 iOS 提供的 UUID，可以用于本机记录和查找。BLE 设备名可能重复，地址也可能轮换。需要跨手机识别同一个实体时，使用设备协议提供的序列号或其他稳定业务标识。

默认情况下系统会合并重复发现事件。需要观察广播值或信号多次更新时，可在前台通过 `CBCentralManagerScanOptionAllowDuplicatesKey` 请求重复结果，并且仍以 identifier 合并列表，结束后及时停扫。RSSI 的波动适合观察，不能当稳定身份。

**动手验证**　相同位置分别扫描不限服务和指定教学服务的结果。若列表空，先确认模拟外设已广播这个 UUID。

**一句话记住**　用广播里的服务编号缩小范围，用系统标识更新同一行。

## 自查题

1. **系统提供的 identifier 是 MAC 吗？** 它是 Core Bluetooth 提供的标识，无需把它转换成硬件地址。
2. **按服务筛到就代表可写吗？** 连接后仍要发现目标特征并核对属性。

[Apple CBCentralManager 文档](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager)

[上一章](#ios/development-guide/scanning) · [正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/connect)
