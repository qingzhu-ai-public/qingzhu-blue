---
title: 04　写一条指令，读回真正的温湿度
slug: read-write-and-notify
order: 50
---

# 04　写一条指令，读回真正的温湿度

`write` 写 `[0x01]` 并等待写确认，再调用 `read` 取得 `number[]`。把字节转成 `Uint8Array`，以 `DataView.getInt16(2, true)` 读出有符号小端温度。解析失败时保留十六进制，便于对设备协议。

外设有 Notify 或 Indicate 特征时，先监听 `onDidUpdateValueForCharacteristic`，再用 `startNotification` 请求开启上报。底层手机蓝牙层会为这条特征配置 CCCD。退出自动更新时调用 `stopNotification`，再移除应用监听。Indicate 的 ATT 确认由手机系统处理。

**练习**　分别输入正温、负温和截断包。确认截断包明确提示格式错误。

**一句话**　写确认是签收条，温湿度要打开下一封信。

**面试题**　为什么监听事件时还要按设备、服务和特征过滤？

同一个监听入口可以收到不同设备和不同特征的上报。过滤能让一块界面只更新自己的读数。

[react-native-ble-manager API](https://innoveit.github.io/react-native-ble-manager/methods/) · [温湿度计实战](#react-native/thermometer-mvp/overview)
