---
title: 02　点一下扫描，结果从哪里回来
slug: scan-and-events
order: 30
---

# 02　点一下扫描，结果从哪里回来

先用 `onDiscoverPeripheral` 注册监听，再调用 `scan({ serviceUUIDs, seconds })`。这个 Promise 结束时，表示启动调用已返回。真正的设备数据一条条从监听函数回来。

发现一个设备就按 `id` 更新列表，重复广播依旧只显示一行。`onStopScan` 让界面恢复按钮。页面卸载时对每个监听句柄调用 `remove()`，否则下一次进页面可能有两份监听在改数据。

**练习**　连续进入和退出页面。用单个监听计数确认一台设备的发现事件没有被多份监听处理。

**一句话**　扫一下像打开收音机，发现事件是之后收到的节目。

**面试题**　为什么要先注册监听再扫描？

设备可能很快出现，先监听才能接到启动后早到的结果。

[react-native-ble-manager API](https://innoveit.github.io/react-native-ble-manager/methods/) · [温湿度计实战](#react-native/thermometer-mvp/overview)
