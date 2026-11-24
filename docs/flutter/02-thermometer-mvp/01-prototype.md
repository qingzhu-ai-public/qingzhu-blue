---
title: 原型与工程入口　先看按钮怎么走
slug: prototype
order: 10
---

# 原型与工程入口　先看按钮怎么走

先点原型里的「开始扫描」，选中外设，再点「请求新读数」。网页只演示交互。真机 App 使用手机蓝牙扫描另一台设备。[打开交互原型](https://qingzhu-ai-public.github.io/qingzhu-blue/examples/flutter/thermometer-mvp/prototype/index.html)

<!-- bthome-prototype -->

## 工程配置参考

<details>
<summary>pubspec.yaml</summary>

[打开工程源码](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/flutter/thermometer-mvp/pubspec.yaml)

```yaml
name: qingzhu_flutter_thermometer
description: 青竹 Flutter 蓝牙温湿度计教学示例
publish_to: none
version: 1.0.0+1
environment:
  sdk: ">=3.8.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
  flutter_reactive_ble: 5.6.0
  permission_handler: 12.0.3
  device_info_plus: 11.5.0
flutter:
  uses-material-design: true
```

</details>

## 装到真机上

1. 用 Flutter 3.47 新建模板，目录名必须和 `pubspec.yaml` 里的项目名一致。

```bash
flutter create --platforms=android,ios --org ai.qingzhu qingzhu_flutter_thermometer
```

2. 把示例的 `pubspec.yaml` 与 `lib/` 放进模板工程，覆盖同名文件。运行 `flutter pub get`。
3. 在 Android 的 `android/app/src/main/AndroidManifest.xml` 中找到根元素 `<manifest>`。将以下内容放在 `<application>` 之前，与它并列。

```xml
    <uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

4. 在 iOS 的 `ios/Runner/Info.plist` 根 `<dict>` 内添加用途说明。iOS 由 BLE 插件触发授权流程。

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>用于扫描和连接教学温湿度计。</string>
```

5. Android 打开 USB 调试。iOS 在 Xcode 中为 Runner 选择签名团队。用 `flutter devices` 确认真机在线，再运行 `flutter run -d <设备ID>`。

看到「蓝牙温湿度计」和「开始扫描」按钮，工程入口就跑通了。再准备一台支持外设角色的手机，打开已有的原生温湿度计示例并启动模拟外设。[Android 示例](https://qingzhu-ai-public.github.io/qingzhu-blue/#android/bthome-mvp/overview) · [iOS 示例](https://qingzhu-ai-public.github.io/qingzhu-blue/#ios/thermometer-mvp/overview) · [HarmonyOS 示例](https://qingzhu-ai-public.github.io/qingzhu-blue/#harmonyos/thermometer-mvp/overview)[插件 Android 与 iOS 配置](https://pub.dev/packages/flutter_reactive_ble)

**一句话**　网页原型先走一遍操作，真机 App 再把这些动作接到系统蓝牙。

**面试题**　能在网页原型里扫到手机旁边的真实温度计吗？

这个原型使用模拟数据。真机示例才调用 Android 或 iOS 的蓝牙 API。

[下一篇　扫描](#flutter/thermometer-mvp/scan)
