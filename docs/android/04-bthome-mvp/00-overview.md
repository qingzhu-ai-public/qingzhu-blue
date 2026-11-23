---
title: 做一个能读温湿度的 Android App
slug: overview
order: 0
summary: 用两台 Android 手机完成从扫描广播到读回温湿度的练习。
---

# 综合实战　做一个能读温湿度的 Android App

你打开 App，点「开始扫描」，列表里出现一台温湿度计，显示 `25.00 °C`。点「连接」进入详情，接着点「请求新读数」。这次屏幕会显示一组温湿度和设备返回的原始字节。

这是一套可以单独用 Android Studio 打开的示例工程。两台手机安装同一个 APK，一台模拟设备，另一台练习扫描、连接和读写。[示例工程与安装步骤](https://github.com/qingzhu-ai-public/qingzhu-blue/tree/main/examples/android/bthome-mvp)

每篇开头列出本篇涉及的完整代码，随后按用户操作逐步讲解重点。

1. [原型与工程入口篇](#android/bthome-mvp/prototype)　先用浏览器点一遍，看看哪些读数该放在列表，哪些要等连上后再显示。
2. [扫描篇](#android/bthome-mvp/scanning)　找到设备，把广播里的几个字节变成温度。
3. [连接篇](#android/bthome-mvp/connection)　点选一台外设，等连接与服务发现完成。
4. [传输篇](#android/bthome-mvp/transfer)　发送一条测量指令，读回并解释结果。
5. [双机验收篇](#android/bthome-mvp/two-device-check)　从扫描走到读数，再用断开实验验证界面和日志。

示例用 [BTHome v2](https://bthome.io/format/) 解析公开的广播数据。连接后使用本项目约定的 GATT 服务完成收发。手边只有一台手机时，如果附近有明文 BTHome v2 设备，可以先练习扫描和解析。
