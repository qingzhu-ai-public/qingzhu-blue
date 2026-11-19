---
title: 导读 从扫描结果到一条温度数据
order: 10
summary: 用一台温度传感器走完 BLE 通信，弄清每一步是谁在做、成功后能继续做什么。
tags: 入门
updated: 2026-11-19
---

# 导读 从扫描结果到一条温度数据

设想你在做一台温度传感器。手机能扫到它，设备列表里也有名字，点进去却一直没有温度。要定位问题，可以顺着数据实际经过的几步查。

```text
传感器广播 → 手机扫描并发起连接
                     ↓
手机发现服务并订阅温度特征
                     ↓
传感器发送新读数
```

广播里可以直接放读数。这种做法适合设备只需定期发数据的场景。如果手机还要设置采样间隔、读取历史记录或接收某个设备的实时更新，就可以让传感器接受连接，再通过 GATT 交换数据。

## 每一步能确认什么

| 已经看到的现象 | 可以确认的事 | 接下来查什么 |
|---|---|---|
| 扫描列表出现设备 | 手机收到了可识别的广播 | 广播是否可连接，筛选条件是否匹配 |
| BLE 链路已建立 | 两端已有一条连接 | 需要的服务和特征是否已找到 |
| 服务和特征已找到 | 手机知道要访问哪个接口 | 特征是否可读、可写或可订阅，访问是否要求加密 |
| 设备端接受了订阅 | 服务端已接受这个客户端的订阅配置 | 固件是否产生新读数，客户端是否收到并解析 |

## 这些协议在什么位置

先分清主机（Host）和控制器（Controller）。广播、扫描和无线收发由控制器的链路层调度，主机和控制器通过 HCI 交换命令、事件与数据。查建连问题时，HCI 日志可以帮你确认请求有没有从主机发到控制器。

GAP 规定设备发现与连接的角色和流程。连接建立以后，GATT 定义服务、特征和描述符，ATT 负责访问服务端属性，L2CAP 提供承载这些协议数据的通道。看应用日志时，把发现设备、建立链路和应用准备就绪分别记下来，同一个「已连接」状态就不会掩盖后面的失败。

## 从手上的问题开始读

- 还在选设备或通信方式，先看[经典蓝牙与 BLE 怎么选](#bluetooth/fundamentals/classic-vs-le)。
- 搜不到设备，或能搜到却连不上，接着看[广播与扫描](#bluetooth/fundamentals/advertising)和[建连与连接参数](#bluetooth/fundamentals/connection)。
- 已经连上，开始写收发逻辑，读 [GATT 与 ATT](#bluetooth/communication/gatt-att)和 [MTU、L2CAP 与分包](#bluetooth/communication/data-transfer)。
- 设备要求配对，或者重扫后地址变了，从[配对、绑定与地址隐私](#bluetooth/communication/security)查起。

如果你在 Android 上实现这条链路，可以接着做[第一台设备的联调](#android/development-guide/guide)。已经遇到故障时，直接翻[按通信阶段排障](#bluetooth/communication/troubleshooting)。

## 参考

[Bluetooth SIG BLE Primer](https://www.bluetooth.com/bluetooth-le-primer/)
