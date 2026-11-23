---
title: 原型与工程入口
slug: prototype
order: 10
summary: 在线体验扫描、连接和读数，再运行 Android 工程。
---

# 原型与工程入口　先看这个 App 怎样使用

手机 A 打开 App 后先看到附近设备。找到教学温湿度计，点连接进入详情，再点请求新读数。手机 B 用同一个 App 的模拟外设模式回应它。

## 在线体验原型

点「开始扫描」，选择教学温湿度计，连接后点「请求新读数」。这里使用模拟数据，可以直接在页面里试一遍。

<!-- bthome-prototype -->

[在独立页面打开原型](https://qingzhu-ai-public.github.io/qingzhu-blue/examples/android/bthome-mvp/prototype/index.html) · [查看完整 HTML 源码](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/android/bthome-mvp/prototype/index.html)

## 页面先分成三处

附近设备负责找设备，设备详情负责发请求和显示结果，模拟外设负责让另一台手机有东西可连接。这三个页面围绕同一条流程。

设备列表里的 25.00 °C 来自广播。详情里按按钮后显示的 26.50 °C 和湿度来自一次连接后的请求。两处的字节都显示出来，学到解析时可以直接对照。

## 按钮点下去，结果要等多久

原型里的扫描按钮暂时显示正在扫描，随后出现一台设备。JavaScript 的 setTimeout 用一小段延时模拟等待，真实 App 要等 Android 蓝牙回调。

进入详情后先禁用请求按钮，等模拟连接完成才允许点。请求期间再次禁用，结果出现后恢复。这就对应后面代码的连接、发现服务、等待操作结果几个阶段。

返回列表时清除等待中的定时任务，避免上一页已经关了、旧结果又跑出来。原生 App 同样需要处理旧回调和退出清理。

## 工程里该打开哪些文件

在 Android Studio 打开 bthome-mvp 目录，等 Gradle 同步完成，运行 app。构建需要 JDK 17+ 和 Android SDK Platform 36，手机最低 Android 8.0。

| 文件 | 它在这个功能里做什么 |
| --- | --- |
| SensorActivity.java | 接收点击、申请权限、显示页面 |
| SensorClient.java | 手机 A 扫描、连接和读写 |
| SensorPeripheral.java | 手机 B 广播服务并回应请求 |
| DemoProtocol.java | 两端约定的编号和指令 |
| BthomeDecoder.java | 按字节解释温湿度 |

后面的 Android 实现篇开头列出本篇涉及的完整文件，后面按点击顺序解释关键方法。在完整代码中遇到下一篇的功能，可以等用到时再读它的讲解。

## 先让 App 跑在手机上

按[安装步骤](https://github.com/qingzhu-ai-public/qingzhu-blue/tree/main/examples/android/bthome-mvp)把同一个 APK 装到两台手机。手机 B 开模拟外设并启动广播，手机 A 开始扫描。至少一台手机要支持 BLE 外设广播，扫描不到时可以交换角色。两台先保持前台。

普通明文 BTHome 设备也能用来观察广播。主动连接与请求使用教学服务，手机 B 的模拟外设实现了它。

**一句话记住**　先把每次点击后应该出现的结果想清楚，再用真实蓝牙回调实现这些变化。

## 面试题

1. **原型里的温度能证明手机蓝牙工作正常吗？** 原型展示的是模拟交互，真实扫描与收发要在 Android 手机验收。
2. **为什么请求期间要禁用按钮？** 避免用户重复点击，让两次请求重叠，导致界面难以判断结果属于哪次操作。

继续读[扫描篇](#android/bthome-mvp/scanning)。
