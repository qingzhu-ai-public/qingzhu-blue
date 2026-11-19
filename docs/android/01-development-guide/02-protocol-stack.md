---
title: 协议栈与核心概念
order: 30
summary: GATT 把设备功能排成目录，ATT 按设备属性表上的编号去读、写和送数据。
tags: SDK,平台,协议
updated: 2026-11-19
---

# 第 2 章　协议栈与核心概念

现在让手机读出温度计的电量。设备手册可能写「电量服务，UUID 为 `0x180F`」。你要先找到这组功能，再找到里面的电量数据项，最后读出它的值。先顺着这个小动作，把几个经常一起出现的词分开。

**Service（服务）**是设备把相关功能放在一起的一组。**Characteristic（特征）**是组里可读、可写或可上报的数据项。**Descriptor（描述符）**是挂在某项数据下面的补充信息或配置。比如电量是一个特征，若设备支持电量通知，特征下面还会有用来登记订阅的 CCCD。

蓝牙用 **GATT** 约定这些东西怎么组织。真正把请求送给设备时，**ATT** 会按编号读到某一项。Android 代码平时根据 UUID 找到特征，报文里的编号叫 **handle（句柄）**。假设抓包看到 `0A 25 00`，`0A` 表示 ATT 读请求，`25 00` 指向设备属性表里的 `0x0025`。同类特征可以有相同 UUID，固件更新后其句柄也可能变化。

下面这张表适合等你在代码或抓包里碰到某个术语时回来查。

| 层或机制 | 负责什么 | 在 Android 中能看到什么 |
| --- | --- | --- |
| GAP | 广播、发现、连接、角色和安全过程的约定 | 扫描结果、连接/配对状态、能力及参数 |
| GATT | 把属性组织成服务、特征和描述符 | `BluetoothGattService`、`BluetoothGattCharacteristic`、`BluetoothGattDescriptor` |
| ATT | 按句柄读写属性、发通知和指示 | GATT 请求和回调、抓包中的 ATT PDU |
| L2CAP | 通道、多路复用及分段重组等 | LE CoC Socket、抓包中的通道及分片 |
| RFCOMM | 在经典蓝牙上提供串口式字节流 | BR/EDR `BluetoothSocket` |
| SMP | LE 配对和密钥分发 | Bond 状态、系统交互和链路加密相关结果 |
| HCI | Host 与 Controller 的接口 | HCI Snoop 中的命令、事件和数据包 |
| PHY / Link Layer | 无线调制、连接事件、链路重传等 | 选定的 PHY、部分连接参数，或空口抓包 |

## 顺着属性表找到这一次的读写目标

一个特征通常有声明属性和值属性，值下面可跟多个描述符。声明包含值句柄、UUID、Properties 等信息。CCCD（Client Characteristic Configuration Descriptor）是 UUID 为 `0x2902` 的描述符，Server 用它记录各 Client 对此特征的通知或指示订阅。特征的属性位声明支持哪些操作，Server 的权限配置决定操作在什么安全状态下允许执行。

SIG 分配的 16 位 UUID 可以展开到 Bluetooth Base UUID。电量服务 `0x180F` 对应 `0000180f-0000-1000-8000-00805f9b34fb`。UUID 的字符串写法与广播里的字节顺序需要分别按规范处理。私有协议使用双方约定的 128 位 UUID。

## 一次到底能发多少字节

在默认 LE 固定 ATT bearer 上，ATT MTU 初始为 23 字节。普通写入或通知需要 3 字节的 ATT 开销，常见的数据预算是 20 字节。读响应的开销和 Prepare Write 的开销各不相同。扩大 ATT MTU 改变的是 ATT PDU 的容量。控制器可把同一个 ATT PDU 拆到多个链路层包，应用协议也可把一条逻辑消息分成多个 ATT 操作。

链路层有自己的重传。到了 ATT 层，手机用 Write Request 提交属性写入时，设备还会发送写响应。Write Command 则省去了这次 ATT 响应。电子标签保存图片或刷新屏幕的结果，要由产品协议另外告诉 App。

## 一句话总结

**GATT 把设备功能排成目录，ATT 按设备属性表上的编号去读、写和送数据。**

## 面试题

1. 同一个 UUID 在一个设备上出现两次，应该怎么找？
2. 默认 ATT MTU 是 23，普通写为什么常见上限是 20 字节？

### 参考答案

1. 在当前发现结果里结合服务、特征实例和设备协议定位，不能只按第一个同名 UUID 猜。
2. 这类 ATT 报文的操作码占 1 字节，句柄占 2 字节，剩下 20 字节给属性值。

[Bluetooth Core 6.2 ATT](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/attribute-protocol--att-.html) · [Bluetooth SIG Assigned Numbers](https://www.bluetooth.com/specifications/assigned-numbers/)
