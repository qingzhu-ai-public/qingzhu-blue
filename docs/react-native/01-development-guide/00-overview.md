---
title: React Native 蓝牙开发指南
slug: overview
order: 0
---

# React Native 蓝牙开发指南

先让手机扫出第一台设备，再顺着连接、读写和解码往下做。正文从每个操作背后的系统行为讲起，实战按文件走完整 App。

1. [把带蓝牙原生模块的 App 装到手机](#react-native/development-guide/first-app)
2. [点扫描前，把权限和开关分开检查](#react-native/development-guide/permission-and-state)
3. [点一下扫描，结果从哪里回来](#react-native/development-guide/scan-and-events)
4. [连接成功后，再找可读写的特征](#react-native/development-guide/connect-and-discover)
5. [写一条指令，读回真正的温湿度](#react-native/development-guide/read-write-and-notify)
6. [离开页面后，停止谁的扫描和监听](#react-native/development-guide/lifecycle)
7. [明明装了库，怎么还是连不上](#react-native/development-guide/troubleshooting)
8. [让跨端页面调用已有的原生蓝牙任务](#react-native/development-guide/native-bridge)

[API 速查](#react-native/development-guide/api-reference) · [综合实战 · 蓝牙温湿度计](#react-native/thermometer-mvp/overview)
