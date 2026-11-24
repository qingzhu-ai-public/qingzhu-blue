---
title: 04　读一次温度，再让外设主动推送
slug: read-write-and-notify
order: 50
---

# 04　读一次温度，再让外设主动推送

先做手动读数。手机调用 `writeCharacteristicWithResponse` 写 `[0x01]`，收到写确认后，再用 `readCharacteristic` 读业务数据。写确认只说明这次写操作成功完成，温湿度来自第二次调用。

打开自动更新需要设备提供带 Notify 或 Indicate 的特征。用 `subscribeToCharacteristic(...).listen(...)` 接值，用订阅句柄的 `cancel()` 结束。开启时，由手机蓝牙层配置外设这条特征的 CCCD。Indicate 时，客户端蓝牙栈按 ATT 协议给外设回确认，Dart 业务处理只负责读收到的数据。教学外设的基础读数特征支持读写，练习订阅时要换支持通知的特征。

**练习**　给解码器输入 `40 02 5A 0A 03 BF 13`，再把温度两字节换成 `0C FE`，应显示 `-5.00 °C`。

**一句话**　读是你去问，订阅是请设备有新值时告诉你。

**面试题**　同一段温度代码能直接解所有温度传感器吗？

需要按该设备的协议读字段。这个示例用有符号小端整数，单位是百分之一摄氏度。

[flutter_reactive_ble API](https://pub.dev/documentation/flutter_reactive_ble/latest/flutter_reactive_ble/FlutterReactiveBle-class.html) · [温湿度计实战](#flutter/thermometer-mvp/overview)
