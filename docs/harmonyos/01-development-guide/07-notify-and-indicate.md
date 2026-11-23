---
title: 06　让外设主动推送变化
slug: notify-and-indicate
order: 70
---

# 06　让外设主动推送变化

每次点刷新都要向外设读一次。打开自动更新后，外设有数据就主动发，页面在事件里刷新。

## 开订阅，先准备接收事件

特征属性为 notify 时，客户端注册 `BLECharacteristicChange` 监听，再调用 `setCharacteristicChangeNotification(characteristic, true)`。检查返回结果，再显示已订阅。若外设只支持 indicate，用 `setCharacteristicChangeIndication(characteristic, true)`。两种模式按特征和固件协议选一种。

## 看清客户端配置和外设发送

CCCD 是特征上记录客户端订阅状态的描述符（UUID 0x2902）。外设要配置匹配的能力和描述符，并按客户端记录状态。参照目标 SDK 的完整订阅示例处理 CCCD 及回包。典型的通知关闭、开启、指示开启值分别是 00 00、01 00、02 00。应用用订阅 API 表达开关。

外设使用 `notifyCharacteristicChanged(deviceId, value)` 向指定客户端发送。`confirm: false` 表示 Notify，`true` 表示 Indicate。Indicate 的 ATT 确认由手机协议栈处理，成功签收和 App 界面更新要分别验证。

**自己试一次**　找一个可订阅特征，先订阅再触发变化，解除后触发第二次。当前实战使用写后读取，订阅需相应的外设特征。

**一句话记住**　订阅负责约定以后怎么发，事件负责把这次数据交给 App。

## 自查题

1. **开了订阅就意味着马上有读数吗？** 要等外设主动发值，首屏需要时按协议另读一次。

[华为 GATT 通知和指示开发指南](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/gatt-development-guide/)

[上一章](#harmonyos/development-guide/read-write-and-parse) · [正文目录](#harmonyos/development-guide/overview) · [下一章](#harmonyos/development-guide/peripheral-and-response)
