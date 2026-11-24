---
title: 01　点扫描前，先取得手机的许可
slug: permission-and-state
order: 20
---

# 01　点扫描前，先取得手机的许可

蓝牙开关开着，扫描仍然可能失败。点「开始扫描」后，先问系统这款 App 有没有资格扫描，再检查蓝牙是否处于可用状态。

Android 12 及以上声明并在运行时申请 `BLUETOOTH_SCAN`、`BLUETOOTH_CONNECT`。Android 11 及以下，示例用前台位置权限支持扫描，部分系统还要打开定位服务。iOS 在 `Info.plist` 写用途说明，由 Core Bluetooth 初始化时按系统状态触发授权流程。授权成功后再等 `statusStream` 发出 `BleStatus.ready`。

**练习**　第一次点拒绝，确认列表没有启动扫描。去设置恢复权限，再关蓝牙重试一次。

**一句话**　打开蓝牙像给门禁通电，给 App 授权才是发门卡。

**面试题**　系统许可和 `BleStatus.ready` 各回答什么？

前者回答 App 能不能用；后者是插件报告的当前可用状态。蓝牙关闭时，授权仍然可以保持有效。

[flutter_reactive_ble API](https://pub.dev/documentation/flutter_reactive_ble/latest/flutter_reactive_ble/FlutterReactiveBle-class.html) · [温湿度计实战](#flutter/thermometer-mvp/overview)
