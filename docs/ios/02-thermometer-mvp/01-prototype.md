---
title: 原型与工程入口　先把 App 装到 iPhone
slug: prototype
order: 10
---

# 原型与工程入口　先把 App 装到 iPhone

在本页点一遍交互原型。手机 A 查找教学温湿度计，点设备后等连接，最后请求一组读数。手机 B 用同一款 App 模拟温湿度计。[在独立页面打开原型](https://qingzhu-ai-public.github.io/qingzhu-blue/examples/ios/thermometer-mvp/prototype/index.html)

<!-- bthome-prototype -->

## 要准备什么

第一次运行只需要一台 iPhone。示例最低支持 iOS 16，使用 SwiftUI 和 Core Bluetooth。需要一台装有 Xcode 的 Mac，Xcode 要支持你手机上的系统版本。验证蓝牙收发时再准备第二台支持 BLE 外设的 iPhone，或一台实现本示例教学协议的设备。

## 第一次运行到手机上

1. 在 Xcode 欢迎页选择 **Open Existing Project**，打开 `examples/ios/thermometer-mvp/Thermometer.xcodeproj`。工程打开后，左栏能看到 Thermometer 和四个 Swift 文件。
2. 点击左栏蓝色工程图标，在 **TARGETS** 下选 **Thermometer**，打开 **Signing & Capabilities**。保持自动签名，选择自己的 **Team**。找不到团队时，在 **Xcode → Settings → Accounts** 添加 Apple 账号。如果默认 Bundle Identifier 已被使用，把它改成一个你能签名的唯一标识。
3. 用数据线连接并解锁 iPhone，按提示信任电脑。如果系统要求启用开发者模式，在手机的 **设置 → 隐私与安全性 → 开发者模式** 操作，按系统提示完成重启和确认。
4. 在 Xcode 顶部选 **Thermometer** 方案和你的 iPhone，点击三角形 **Run**，也可以按 **⌘R**。手机出现「蓝牙温湿度计」页和「开始扫描」按钮就通过了首个检查点。[Apple 真机运行指南](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)

手机没出现在设备列表时，先看手机是否解锁、是否信任电脑。能选手机但 Run 失败时，打开 Xcode 的错误列表，先处理签名团队、Bundle Identifier 或开发者模式提示。蓝牙授权会在开始扫描或模拟广播时请求。

## 从哪个文件开始读

| 文件 | 对应哪一步 |
| --- | --- |
| ThermometerApp.swift | 入口页面、按钮和读数显示 |
| SensorCentral.swift | 手机 A 搜索、连接、写入和读取 |
| SensorPeripheral.swift | 手机 B 注册服务、广播与应答 |
| DemoProtocol.swift | 双方约定的编号、命令与解析 |
| Info.plist | App 的蓝牙用途说明 |

有第二台手机时，同样装好 App。手机 B 点「模拟温湿度计 → 启动广播」，等页面显示正在广播。手机 A 留在首页，跟着扫描篇操作。原型可以在浏览器里反复练习，里面的设备和读数都是模拟数据。

**一句话记住**　先看到 App 页面，再验证从按钮到蓝牙数据的那条路径。

**自查题**　看到首页就算蓝牙通了么？首页出现证明安装和启动成功，蓝牙链路要再用真机验收。

继续读[扫描篇](#ios/thermometer-mvp/scanning)。
