---
title: Flutter 蓝牙开发指南
slug: overview
order: 0
---

# Flutter 蓝牙开发指南

先让手机扫出第一台设备，再顺着连接、读写和解码往下做。正文从每个操作背后的系统行为讲起，实战按文件走完整 App。

1. [把第一个蓝牙页面装到手机上](#flutter/development-guide/first-app)
2. [点扫描前，先取得手机的许可](#flutter/development-guide/permission-and-state)
3. [让附近设备出现在列表](#flutter/development-guide/scan-and-stream)
4. [设备连上了，读数按钮什么时候亮](#flutter/development-guide/connect-and-discover)
5. [读一次温度，再让外设主动推送](#flutter/development-guide/read-write-and-notify)
6. [退回首页后，谁来清理蓝牙](#flutter/development-guide/lifecycle)
7. [扫不到或读不到，从哪一步查](#flutter/development-guide/troubleshooting)
8. [让跨端页面调用已有的原生蓝牙任务](#flutter/development-guide/native-bridge)

[API 速查](#flutter/development-guide/api-reference) · [综合实战 · 蓝牙温湿度计](#flutter/thermometer-mvp/overview)
