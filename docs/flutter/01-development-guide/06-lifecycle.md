---
title: 05　退回首页后，谁来清理蓝牙
slug: lifecycle
order: 60
---

# 05　退回首页后，谁来清理蓝牙

在进入页面时创建订阅，在离开时取消。扫描、连接、通知各有自己的订阅句柄，只取消扫描的句柄不会断开连接。

把一次连接看成一个会话。开始或结束时更新会话编号。服务发现和读写返回后先核对编号，再更新 UI。比如 A 断线后连上 B，迟到的 A 读数可以丢弃。请求超时只是 Dart 等待结束，示例还主动断开；重连时重新确认服务。

**练习**　在读数过程中关闭外设，确认按钮恢复可重新扫描，且旧请求不会把读数更新回来。

**一句话**　每份结果都带上这次会话的号码，过期号码别入账。

**面试题**　还要不要检查 `mounted`？

要。会话编号判定结果属于哪次连接，`mounted` 判定页面还在不在。

[flutter_reactive_ble API](https://pub.dev/documentation/flutter_reactive_ble/latest/flutter_reactive_ble/FlutterReactiveBle-class.html) · [温湿度计实战](#flutter/thermometer-mvp/overview)
