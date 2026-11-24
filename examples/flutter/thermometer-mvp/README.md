# Flutter 蓝牙温湿度计示例

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

[原型](prototype/index.html) · [逐篇实战](https://qingzhu-ai-public.github.io/qingzhu-blue/#flutter/thermometer-mvp/overview)
