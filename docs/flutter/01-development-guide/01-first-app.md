---
title: 00　把第一个蓝牙页面装到手机上
slug: first-app
order: 10
---

# 00　把第一个蓝牙页面装到手机上

用数据线连手机，运行示例。看到「开始扫描」，说明这台手机已经能运行 Flutter 工程。先用真机确认这一点，再接第二台手机当外设。

Flutter 的按钮执行 Dart 代码。点扫描后，`flutter_reactive_ble` 把请求交给系统原生蓝牙 API，再把设备交回 Dart。你写一次列表，两端仍要各自配置权限。用 `flutter devices` 检查手机是否被识别，没有设备时先处理 USB 调试、信任或 iOS 签名。

**练习**　改一次按钮文案并热重载，再改 Android 清单并重新运行 App，观察两种修改的生效方式。

**一句话**　Dart 管屏幕上怎么显示，手机系统管附近有没有设备。

**面试题**　改了 Android 清单，为什么热重载不够？

热重载更新 Dart 代码。Android 清单会打进原生安装包，改后需要重新构建安装。

[flutter_reactive_ble API](https://pub.dev/documentation/flutter_reactive_ble/latest/flutter_reactive_ble/FlutterReactiveBle-class.html) · [温湿度计实战](#flutter/thermometer-mvp/overview)
