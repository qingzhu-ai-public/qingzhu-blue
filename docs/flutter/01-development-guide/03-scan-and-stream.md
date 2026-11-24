---
title: 02　让附近设备出现在列表
slug: scan-and-stream
order: 30
---

# 02　让附近设备出现在列表

先让教学外设开始广播，再点「开始扫描」。`scanForDevices` 返回 `Stream<DiscoveredDevice>`。它像一条持续送结果的队列，你用 `.listen()` 接住每条结果。

`withServices` 传的是设备在广播里公布的服务 UUID。只在 GATT 内提供该服务的设备，不保证能通过这个条件扫到。调试时可短暂去掉筛选，查广播里的服务字段。

同一设备可以上报多次。按 `device.id` 更新 Map，页面只留一行，名称和 RSSI 可以刷新。点设备、扫描到时或页面销毁时，取消这次 `StreamSubscription`。Android 扫到的 ID 和 iOS 的系统标识来源不同，勿当成贯通两端的业务编号。

**练习**　把扫描时长从八秒改成三秒。等按钮恢复后再扫，观察列表有没有重复项。

**一句话**　一次扫描会收到多张设备名片，按编号收进同一格。

**面试题**　`.listen()` 的返回值有什么用？

它是这次订阅的句柄。把它保存下来，结束时调用 `cancel()`。

[flutter_reactive_ble API](https://pub.dev/documentation/flutter_reactive_ble/latest/flutter_reactive_ble/FlutterReactiveBle-class.html) · [温湿度计实战](#flutter/thermometer-mvp/overview)
