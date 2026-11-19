---
title: 导读 先接通一台设备
order: 10
summary: 学蓝牙先让一条数据走个来回，之后每遇到一个成功或失败，都能说出它发生在哪一步。
tags: SDK,必读
updated: 2026-11-19
---

# 导读　先接通一台设备

你手边有两台 Android 手机。把课程里的 BLE Echo 装上，一台点「启动外设」，另一台点「扫描并验证回声」。客户端会发一段固定字节，外设收到以后原样发回来。两边的日志能让你看见同一次通信到底走到了哪儿。

这就是本书的第一件事。连上外设，再让数据走一个来回。以后换成温度计、电子标签或你自己的硬件，依然可以沿着同一条顺序查。比如换图时，扫到广播只能告诉你附近有人在发信号。连上以后还要找到设备开放的功能，写入数据，最后等标签告诉你图换好了。

刚开始先区分三种结果。你调用方法后，Android 可能告诉你「我接到这个请求了」。等系统处理完，它会用回调告诉你连接或写入的结果。标签真的换好图，则要等设备的业务回执，或者按协议读回校验。能分清这三句话，出错时就知道去找哪一段日志。

## 按手头的任务读

| 手头的任务 | 阅读顺序 | 做完后可以验证 |
| --- | --- | --- |
| 从零接一台 BLE 设备 | [权限](#android/development-guide/permissions) → [扫描](#android/development-guide/scanning) → [建连](#android/development-guide/connection-lifecycle) → [发现](#android/development-guide/service-discovery) → [读写](#android/development-guide/characteristic-rw) → [订阅](#android/development-guide/notify-cccd) | 写入一段数据并收到同样的字节 |
| 接经典串口设备 | [发现与绑定](#android/development-guide/discovery-pairing) → [RFCOMM](#android/development-guide/rfcomm-socket) | 收发带长度的消息，断开后释放阻塞的读写 |
| 让手机当 BLE 外设 | [广播](#android/development-guide/advertiser) → [GATT Server](#android/development-guide/gatt-server) | 另一台手机能扫描、发现服务并订阅 |
| 项目要处理后台和断线 | [连接队列](#android/development-guide/thread-state-machine) → [后台](#android/development-guide/background-service) → [真机测试](#android/development-guide/test-lab) | 能解释每个阶段失败后由谁清理、由谁恢复 |
| 手上已有日志或某个方法名 | [排错索引](#android/development-guide/appendix-f-faq) / [API 总索引](#android/development-guide/appendix-b-api) | 找到调用前提、返回值、完成事件和下一项证据 |

例子默认面向普通 Android 应用。章节里的 Kotlin 片段集中展示调用顺序，未写出的应用变量由调用方提供。实验手册另有可放入 Android 工程的 Java 示例。需要两台支持对应能力的真机，或一台手机配一个可控制的外设。先在前台验证链路，再测试熄屏、切后台和重连。

## 读懂一个 API 条目

看到一个方法写着「API 33」，先问是哪一种版本。`compileSdk` 决定编译时能不能引用这个方法。手机的系统版本决定运行时能不能走这条分支。`targetSdk` 表达应用面向的 Android 版本，会影响系统给这款应用执行的规则。例如 API 33 增加了可以直接传字节的 GATT 写入重载，旧手机要切回旧重载。静默开关蓝牙还受目标版本影响。

看成功时问清楚成功的是哪一步。扫描的 `startScan` 回调重载返回 `Unit`，失败走 `onScanFailed`。新版 GATT 写入立即返回 `BluetoothStatusCodes`，完成时的回调使用另一套 GATT 状态码。设备是否执行指令，要按设备协议验证。

协议定义、平台合约和可复现的工程记录各有来源。版本变化到 [官方参考索引](#android/development-guide/appendix-d-refs) 查，机型或固件经验到 行业经验库 查。

## 一句话总结

**学蓝牙先让一条数据走个来回，之后每遇到一个成功或失败，都能说出它发生在哪一步。**

## 面试题

1. 手机看到设备的 BLE 广播，可以直接把界面显示为「已连接」吗？
2. App 收到 GATT 写成功后，怎样确认标签已经换图？

### 参考答案

1. 广播只说明收到了一次发现数据。连接是否建立，要等这次连接的结果。
2. 按设备协议等待换图完成回执，或读取设备状态来确认。
