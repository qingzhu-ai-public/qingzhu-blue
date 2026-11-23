---
title: 05　点一台设备，等它真的连上
slug: connect
order: 60
---

# 05　点一台设备，等它真的连上

用户点选温度计，界面显示正在连接，同时允许返回列表取消。等连接回调到达，再继续查找读写入口。

## 将扫描结果里的对象交给连接 API

保留 `didDiscover` 交给你的 `CBPeripheral`，点击时调用 `central.connect(peripheral, options: nil)`。第一个参数是这台设备，第二个参数使用系统默认连接选项。先停扫，然后把该设备保存为本次选中项。

## 三种回调对应三种页面状态

| 回调 | 页面应该怎样变 |
| --- | --- |
| `centralManager(_:didConnect:)` | 显示连上了，进入服务发现 |
| `centralManager(_:didFailToConnect:error:)` | 显示错误，允许重新扫描 |
| `centralManager(_:didDisconnectPeripheral:error:)` | 禁用后续读写，清掉本次的特征和等待操作 |

Core Bluetooth 的连接请求没有自动超时。App 可以设定自己的等待时间，例如 12 秒。用户取消或计时到期时，调用 `cancelPeripheralConnection(_:)`，并让本次任务失效。取消的是本 App 的本地连接，系统可能仍为其他客户端管理连接。

**动手验证**　点连接后立刻返回列表。确认晚到的连接事件不会把旧页面打开。

**一句话记住**　connect 只是请系统尝试，看到 didConnect 才能往下走。

## 自查题

1. **为什么需要自己的连接超时？** 系统请求可能长时间待定，页面需要自己的等待和取消策略。
2. **连接取消后要处理回调吗？** 要让失效的旧事件无法更新当前会话。

[Apple connect 方法](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/connect%28_%3Aoptions%3A%29)

[上一章](#ios/development-guide/scan-filters) · [正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/services-characteristics)
