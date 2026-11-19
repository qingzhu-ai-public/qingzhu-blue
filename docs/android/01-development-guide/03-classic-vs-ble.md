---
title: 经典蓝牙与 BLE 选型
order: 40
summary: 选蓝牙方案，先看设备把数据放在哪条通道，再决定手机怎样连过去。
tags: SDK,平台,协议
updated: 2026-11-19
---

# 第 3 章　经典蓝牙与 BLE 选型

假设你接到同一个温度显示需求，手里却有两种设备。一种文档写「连接模块的 SPP 串口，按行收温度」，另一种写「发现温度特征，打开通知」。页面都显示一个数字，Android 端用的连接方式却不同。

第一种走经典蓝牙的 RFCOMM。Android 连上模块的服务后从字节流里取数据，读到一行再解析。第二种走 BLE 的 GATT。Android 找到温度所在的特征，再读一个值或订阅上报。设备还有可能同时提供两种接口。判断时先看它把业务数据放在哪条通道，然后问清怎么找到目标设备、服务标识、认证要求和数据格式。

跟设备团队对接口时，可以照下面的场景逐项确认。

| 已知设备接口或需求 | Android 路径 | 立项时验证 |
| --- | --- | --- |
| 设备公开 SPP 或自定义 RFCOMM 服务 | `BluetoothSocket` + SDP 服务 UUID | 服务已注册、两端认证要求一致、字节流消息边界 |
| 设备公开一组低功耗属性 | 扫描、GATT、读写、订阅 | UUID、Properties、CCCD、固件版本兼容 |
| 自己设计双方，要求 LE 上的通道式传输 | LE L2CAP CoC，API 29 起 | 两端支持 CoC，PSM 发现、包大小和回压 |
| 音乐播放、通话、耳机切换 | 系统 Profile、`AudioManager` | 媒体与通话路由、设备能力、实际输出 |
| 无连接数据采集 | BLE 广播 | 数据预算、扫描时机、丢样和地址更新 |
| 面对近距离定位需求 | 评估 RSSI 或 Channel Sounding | 双端测距硬件、权限、隐私、实际误差分布 |

## 设备能扫到，数据到底从哪儿走

某个双模设备用 BLE 广播暴露序列号，数据传输走 RFCOMM。BLE 扫描可以帮你识别候选目标。接下来要按产品协议确认 BR/EDR 侧地址或设备映射，再使用对应的 RFCOMM UUID。直接尝试在广播地址上找 GATT 数据特征，很可能是在连另一条接口。

另一个常见的叫法是「BLE 串口透传」。拿到这类模块的文档，先找它有没有给出写特征和通知特征的 UUID。有这两项时，手机用 GATT 写和订阅，让两端再约定如何分包、如何重组。

## 一句话总结

**选蓝牙方案，先看设备把数据放在哪条通道，再决定手机怎样连过去。**

## 面试题

1. 设备写着「蓝牙 5.x」，能据此决定用 GATT 还是 RFCOMM 吗？
2. 同一设备用 BLE 广播身份，但数据走 RFCOMM，App 应怎样接？

### 参考答案

1. 要看设备实际开放的业务接口、服务标识和配对要求。版本号单独不足以确定传输路径。
2. BLE 扫描用于发现和识别，随后按产品协议确认经典侧的设备映射及服务 UUID，再创建 RFCOMM Socket。

[Android 经典蓝牙](https://developer.android.com/develop/connectivity/bluetooth) · [Android BLE 概览](https://developer.android.com/develop/connectivity/bluetooth/ble/ble-overview)
