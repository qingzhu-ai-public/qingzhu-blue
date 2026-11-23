---
title: 00　先把第一个 App 装到 iPhone 上
slug: first-app
order: 10
---

# 00　先把第一个 App 装到 iPhone 上

这一章只做一件事。按 Xcode 的运行按钮，让 iPhone 屏幕出现自己写的「查找设备」按钮。你可以暂时只用一台手机。

## 建一个空 App

用 Mac 打开 Xcode，选择 **Create New Project → iOS → App**。Interface 选 SwiftUI，Language 选 Swift。工程配置里的 Bundle Identifier 是系统用来识别 App 的名字。首次练习可以用自己的反向域名作为 Organization Identifier。

打开 Xcode 生成的 `ContentView.swift`，把视图改成下面这样。入口文件里的 `WindowGroup` 指向 `ContentView()`，保持默认即可。

```swift
import SwiftUI

struct ContentView: View {
    @State private var message = "还没开始"

    var body: some View {
        VStack(spacing: 16) {
            Text(message)
            Button("查找设备") {
                message = "按钮有效，下一步接入蓝牙"
            }
        }
        .padding()
    }
}
```

`@State` 让 SwiftUI 在文字变化时刷新视图。`Button` 花括号里的代码会等你真正点一下才执行。以后我们就从这里发起扫描。

## 装上真机

1. 在 **Signing & Capabilities** 选 Team。个人练习可以用 Xcode 里登录的 Apple 账号，按签名提示设置唯一的 Bundle Identifier。
2. 用数据线连接、解锁手机并信任 Mac。系统提示时启用开发者模式。
3. 顶部运行目标选这台 iPhone，点 Run。按钮能改文字就通过了。

模拟器可以用来练界面。验收真实扫描和蓝牙收发时，后面用 iPhone 和外设做。

**一句话记住**　先让按钮在真机上有反应，再把按钮接到蓝牙。

## 自查题

1. **手机已经插上，为什么 Xcode 看不到？** 查数据线、解锁、信任和设备列表。
2. **首页能打开说明蓝牙已经就绪吗？** 只验证了构建、安装和启动。蓝牙状态在创建管理器后检查。

[Apple 真机运行指南](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)

[正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/advertising)
