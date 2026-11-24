---
title: 06　扫不到或读不到，从哪一步查
slug: troubleshooting
order: 70
---

# 06　扫不到或读不到，从哪一步查

先看问题在哪一段发生，再决定查哪个文件。

| 现象 | 先查什么 |
|---|---|
| 没出现系统弹窗 | Android 清单、版本分支；iOS 用途说明和系统授权记录 |
| 有其他设备，唯独没有教学外设 | 外设是否广播、广播包里是否公布服务 UUID |
| 点设备后按钮灰着 | `connected` 是否到达，目标特征是否支持有响应写入 |
| 能写但解不出来 | 把实际回包转十六进制，检查长度、对象 ID 和小端顺序 |

日志带上操作阶段和设备会话 ID。排查结束后去掉完整 MAC、业务负载这类临时日志。

**练习**　用同一外设分别在 Android 和 iOS 上扫、连、写、读。记下首个失败阶段。

**一句话**　找出握手在哪一棒掉了，再去查那一棒。

**面试题**　有 RSSI 能证明 GATT 连接成功吗？

RSSI 可以随扫描结果出现。连接状态流的 `connected` 才说明连接建立。

[flutter_reactive_ble API](https://pub.dev/documentation/flutter_reactive_ble/latest/flutter_reactive_ble/FlutterReactiveBle-class.html) · [温湿度计实战](#flutter/thermometer-mvp/overview)
