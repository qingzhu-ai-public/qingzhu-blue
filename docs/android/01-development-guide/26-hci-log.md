---
title: 抓包、HCI Snoop 与日志诊断
order: 270
summary: 从 App 按下按钮开始，沿着手机、控制器和设备日志找同一条消息停在哪一步。
tags: SDK,工程实践
updated: 2026-11-19
---

# 第 26 章　抓包、HCI Snoop 与日志诊断

标签卡在「等回执」。App 同事问设备有没有发，设备同事也在等手机的日志。先找一轮能复现的换图，记下点击时间、这次写的操作编号，以及页面超时的时间。两端都从这几秒找记录。

**HCI Snoop** 是手机主机和蓝牙控制器之间的通信记录。打开它，可以看到这段时间手机向控制器交了什么、控制器又把什么交回来。如果其中有 ATT 数据，还能看到[第 16 章](#android/development-guide/notify-cccd)里的订阅写入、写响应和通知。

## 先对齐时间，再看消息在哪儿断了

| 证据 | 能证明什么 |
| --- | --- |
| 应用事件 | 请求参数、会话代次、操作 ID、同步返回、收到的回调、业务结果 |
| HCI Snoop | Host 和 Controller 边界的命令、事件和 ACL 数据，可解出的 ATT/SMP 报文 |
| 设备端日志或空口抓包 | 设备的属性处理、业务回执，以及 HCI 看不到的无线层交互 |

应用日志记录墙上时间和单调时间。墙上时间方便与其他系统对齐，单调时间算耗时。每条关键事件带上阶段、状态十进制和十六进制、目标实例及数据长度。协议内容和身份字段按工单需要脱敏。

## 在测试手机上抓这一次

在测试手机的开发者选项启用 Bluetooth HCI snoop log。按 AOSP 指南重启蓝牙后复现，然后保存报告。使用专用测试设备和测试数据，分享前检查包里是否有设备地址、应用数据或可识别用户的信息。

```powershell
adb shell dumpsys bluetooth_manager
adb logcat -v threadtime -d > logcat-bluetooth.txt
adb bugreport bluetooth-bugreport.zip
```

从 Bugreport 中查找 BTSnoop 日志，或对文本报告用 AOSP 的 `btsnooz.py` 提取。具体路径、导出能力和全量/过滤选项取决于构建。用 Wireshark 打开，可以先用 `btatt`、`btsmp` 或 `bthci_evt` 缩小查看范围。测试完成后关闭额外抓包选项。

## 从订阅写入一直查到应用回调

从应用日志找到 CCCD 的写入时间。在 Wireshark 展开 ATT，核对写的是哪个句柄和值，随后有没有收到设备的 Write Response。找不到写请求时回到 App 的立即结果和队列。看到 Error Response 就读它的错误码。设备应答成功后，再找它发来的 Handle Value Notification。抓包里已经进了手机，App 却没报告数据，就查本地登记、回调所属的会话和解析过程。

HCI 看的是主机和控制器之间的通信。要解释空中丢包、干扰、重传和具体广播窗口，使用合适的空口抓包设备，或结合控制器与远端日志。

## 一句话总结

**从 App 按下按钮开始，沿着手机、控制器和设备日志找同一条消息停在哪一步。**

## 面试题

1. 抓包里有设备发来的通知，页面却没更新，下一步查哪儿？
2. HCI Snoop 能直接看到空中每次重传吗？

### 参考答案

1. 查当前 GATT 会话的本地注册与 `onCharacteristicChanged()`，然后查解析和向界面的结果交付。
2. HCI 记录主机和控制器边界的数据。观察空中重传和干扰，需要适合的空口抓包或控制器证据。

[AOSP 蓝牙验证与调试](https://source.android.com/docs/core/connect/bluetooth/verifying_debugging)
