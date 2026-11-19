---
title: Android 蓝牙全景
order: 20
summary: 同一个蓝牙图标下面有几条不同的路，先认出设备走哪一条，再选 Android 入口。
tags: SDK,平台,协议
updated: 2026-11-19
---

# 第 1 章　Android 蓝牙全景

做一个「添加温度计」的页面。你按下「搜索」，列表里应该出现传感器。偏偏系统设置里能看到旁边的耳机，你的页面一项都没有。先想清楚这两块界面在找什么，后面就知道该查扫描代码，还是该看传感器有没有发广播。

耳机可能通过系统的经典蓝牙发现或音频服务出现。我们的页面可以只扫 BLE，并且只显示广播里带指定 UUID 的温度计。设备什么时候发、手机用哪条路径找、结果符合哪些条件，三件事一起决定了屏幕上有什么。

这章先顺着一次搜索和连接走过去。你在 App 点按钮，Android 把请求交给手机里的蓝牙系统，控制器负责收发无线信号。另一端的温度计也有自己的蓝牙系统和固件。等你按下「读温度」，才轮到设备提供的数据接口。

## 蓝牙请求经过哪些层

```text
App / SDK
  → Android 公开 API（BluetoothManager、BluetoothGatt、BluetoothSocket 等）
  → 系统 Bluetooth 服务、协议栈和 Profile
  → HAL / HCI
  → 控制器、基带与无线链路
  → 对端协议栈与设备应用
```

在代码里先用 `BluetoothManager` 拿到本机适配器。可以把这个对象理解成应用进入本机蓝牙功能的入口。要找温度计时，从它拿 BLE 扫描器。要跟串口模块传数据时，用 Socket。要切换通话耳机，则从系统音频入口查当前路由。

| 任务 | 入口 | 拿到的是什么 |
| --- | --- | --- |
| 发现经典设备 | `BluetoothAdapter.startDiscovery()` | `ACTION_FOUND` 异步广播 |
| BLE 扫描 | `BluetoothAdapter.getBluetoothLeScanner()` | `ScanResult`，内含设备句柄及广播观测 |
| BLE 发广播 | `BluetoothAdapter.getBluetoothLeAdvertiser()` | 广播启动结果及可选的广播集控制 |
| GATT Client | `BluetoothDevice.connectGatt(...)` | 每个客户端的 `BluetoothGatt` 与异步事件 |
| GATT Server | `BluetoothManager.openGattServer(...)` | 本地属性表和来自远端的请求 |
| 应用自定义字节流 | `BluetoothSocket`、`BluetoothServerSocket` | 流、远端设备、阻塞连接与关闭接口 |
| 系统 Profile 状态 | `BluetoothAdapter.getProfileProxy(...)` | 异步交付的代理句柄 |
| 通话路由 | `AudioManager` | 可用通信设备和当前路由 |
| 测距 | `RangingManager` | 能力回调、测距会话和测量值 |

## 蓝牙的三组角色

**Central/Peripheral** 描述 LE 连接中的角色。典型流程是 Peripheral 广播，Central 扫描后发起连接。**Observer/Broadcaster** 对应只观察和只广播的场景。**GATT Client/Server** 描述连接上谁发起属性操作、谁托管属性表。同一台 Android 设备可以同时扮演多个角色，能力与并发上限取决于控制器和系统实现。

电子标签往往是 Peripheral 和 GATT Server，Android 往往是 Central 和 GATT Client。第 18 章把 Android 改成 Server，另一台手机来读写。两个例子使用同一套属性模型。

## 从结果往回找

实操时先记三件事。是否看到新鲜广播？这次 GATT 连接是否收到成功状态？这条业务指令是否收到设备确认？三个答案分别缩小扫描、连接、业务协议的范围。想进一步看每层的包和错误，跟着 [抓包章节](#android/development-guide/hci-log) 做一次端到端对照。

## 一句话总结

**同一个蓝牙图标下面有几条不同的路，先认出设备走哪一条，再选 Android 入口。**

## 面试题

1. 系统设置能看到设备，BLE 扫描列表却没有，先查什么？
2. 常见 BLE 温度计连到手机后，哪一端是 GATT Server？

### 参考答案

1. 先确认设备是否在发 BLE 广播，再检查权限以及过滤字段能否在实际广播里找到。
2. 温度计提供温度和电量等数据项，通常是 GATT Server。手机向它发起读写，通常是 GATT Client。

[Android 蓝牙概览](https://developer.android.com/develop/connectivity/bluetooth) · [AOSP 蓝牙架构](https://source.android.com/docs/core/connect/bluetooth)
