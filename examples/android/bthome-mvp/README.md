# 蓝牙温湿度计 · Android MVP

打开 App，先扫到一台温湿度计，再连接它并主动请求新读数。广播温度显示在设备列表，连接读数和原始字节放在详情页。手边没有温湿度计时，可以用第二台 Android 手机运行同一个 App，切换到模拟外设。

## 先看原型

用浏览器打开 [交互原型](prototype/index.html)。点「开始扫描」，选中教学温湿度计，再点「请求新读数」。也可以返回列表，打开外设模式。原型中的数据是模拟的，浏览器里就能走完。

## 在真机上运行

在 Android Studio 打开本目录，等待 Gradle 同步，选择 `app` 配置运行。工程需要 JDK 17 或更新版本和 Android SDK Platform 36。手机需要 Android 8.0 或更新版本，两台手机至少有一台支持 BLE 外设广播。Windows 上也可以用同目录的 [构建脚本](构建.ps1) 得到调试 APK。

```powershell
$apk = & ".\构建.ps1"
adb devices
$client = "填手机 A 的序列号"
adb -s $client install -r $apk
$peripheral = "填手机 B 的序列号"
adb -s $peripheral install -r $apk
```

把命令里的序列号占位符替换为 `adb devices` 列出的实际值。如果之前装过采用另一把实验签名的 APK，需要先卸载旧实验 App，再安装新版本。

1. 手机 B 点「模拟温湿度计」和「启动广播」，等页面显示正在广播。
2. 手机 A 点「开始扫描」。看到「教学温湿度计」和 `25.00 °C` 后，点这一条的「连接」。
3. 手机 A 等状态提示可以请求，再点「请求新读数」。预期显示 `26.50 °C · 50.55% RH` 和原始字节。
4. 手机 B 点「停止广播」，验证手机 A 的连接和按钮状态。

## 按开发顺序学习

每篇先列出本篇涉及的完整代码，再按操作顺序讲解关键调用。

| 篇目 | 这一篇做出来的功能 |
| --- | --- |
| [原型与工程入口篇](https://qingzhu-ai-public.github.io/qingzhu-blue/#android/bthome-mvp/prototype) | 看完整原型代码，点通流程，再运行 Android 工程 |
| [扫描篇](https://qingzhu-ai-public.github.io/qingzhu-blue/#android/bthome-mvp/scanning) | 在列表显示温度、信号强度和广播字节 |
| [连接篇](https://qingzhu-ai-public.github.io/qingzhu-blue/#android/bthome-mvp/connection) | 点选设备，发现读写所需的服务和特征 |
| [传输篇](https://qingzhu-ai-public.github.io/qingzhu-blue/#android/bthome-mvp/transfer) | 发送一字节指令，读回结果并显示温湿度 |
| [双机验收篇](https://qingzhu-ai-public.github.io/qingzhu-blue/#android/bthome-mvp/two-device-check) | 用另一台手机模拟外设，检查成功与断开流程 |

扫描使用 [BTHome v2](https://bthome.io/format/) 的明文数据。主动请求新读数使用自定义的教学 GATT 服务。普通 BTHome 设备可用于扫描练习，连接实战需要模拟外设或实现了同一教学服务的设备。
