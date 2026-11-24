---
title: 03　设备连上了，读数按钮什么时候亮
slug: connect-and-discover
order: 40
---

# 03　设备连上了，读数按钮什么时候亮

点设备后先取消扫描，再调用 `connectToDevice(id: ...)`。监听连接流，收到 `connected` 后才能查读写入口。连接流还会继续报告断开，页面要保留这次订阅。

一个特征用设备 ID、服务 UUID、特征 UUID 定位，三者组成 `QualifiedCharacteristic`。示例用 `resolveSingle` 检查只找到一个目标，再确认它既能读，又支持有响应写入。按钮亮起代表已经找到可用入口。

**练习**　改错一位特征 UUID。保留正确的扫描服务 UUID，上机观察连接之后报错的位置。

**一句话**　连上像进了楼，查到特征才找到办事窗口。

**面试题**　重新连同一设备时，为什么还要查一次特征？

旧特征对象来自上一次连接。重建连接后应重新验证服务和特征，设备固件也可能改过配置。

[flutter_reactive_ble API](https://pub.dev/documentation/flutter_reactive_ble/latest/flutter_reactive_ble/FlutterReactiveBle-class.html) · [温湿度计实战](#flutter/thermometer-mvp/overview)
