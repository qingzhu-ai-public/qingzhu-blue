---
title: 22　接到一台经典蓝牙设备，先问厂商什么
slug: classic-bluetooth
order: 230
---

# 22　接到一台经典蓝牙设备，先问厂商什么

串口秤已经在 Android 上跑通，换到 iPhone 时只知道它标注「蓝牙 5」。先向厂商要无线接口协议。

## 先分清 App 到底要什么

| 目标 | 先确认的接入方式 |
| --- | --- |
| 读写传感器数据 | 是否提供 BLE GATT 或受支持的 GATT over BR/EDR 服务 |
| 接经典蓝牙串口设备 | 厂商是否为 iOS 提供适用的配件协议、SDK 或 MFi 接入路径 |
| 使用耳机和音箱 | 系统配对与音频路由；从音频框架检查 App 可控制的功能 |
| 接 MFi 专用协议 | External Accessory、厂商的协议字符串及配件要求 |

Core Bluetooth 在支持条件下可用 GATT over BR/EDR。但 Android 上的 RFCOMM/SPP 方案不能简单改写成 Core Bluetooth 调用。要核对产品型号、固件、服务与特征 UUID、配件协议，以及厂商是否验证了 iOS 版本。[Apple Core Bluetooth 与 BR/EDR](https://developer.apple.com/videos/play/wwdc2019/901/)

## 先做一轮最小验证

拿真实配件只做一个动作，例如读一条秤重数据。确认设备能发现、能建立应用所需连接并能拿到字节，再排开发计划。使用 External Accessory 时，先确认厂商文档中的支持协议和会话方式。

**动手验证**　用厂商的协议表逐项标记「发现」「连接」「收发」对应哪个 iOS 框架。

**一句话记住**　先问清楚设备说什么协议，再决定 iOS 的入口。

## 自查题

1. **包装写蓝牙 5 可以推断支持 BLE 数据读写吗？** 版本号不能说明它公开了哪种配件协议。
2. **耳机能连接代表 App 可以读写任意数据吗？** 要看系统音频功能和设备实际向 App 提供的接口。

[Apple External Accessory 文档](https://developer.apple.com/documentation/externalaccessory)

[上一章](#ios/development-guide/accessory-setup) · [正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/l2cap)
