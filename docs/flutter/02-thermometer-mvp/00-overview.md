---
title: 综合实战　用 Flutter 做一个蓝牙温湿度计
slug: overview
order: 0
---

# 综合实战　用 Flutter 做一个蓝牙温湿度计

手机 A 运行 Flutter App。手机 B 用原生示例模拟温湿度计。A 扫到 B，连上，写一个字节 `01`，再读到 `40 02 5A 0A 03 BF 13` 时，页面应显示 `26.50 °C · 50.55% RH`。外设可以交替返回两组教学数据。

1. [原型与工程入口](#flutter/thermometer-mvp/prototype)
2. [扫描篇](#flutter/thermometer-mvp/scan)
3. [连接篇](#flutter/thermometer-mvp/connection)
4. [传输篇](#flutter/thermometer-mvp/transfer)
5. [双端验收篇](#flutter/thermometer-mvp/two-device-check)

回包借用 BTHome v2 的温湿度字段布局。示例用自定义 GATT 服务传输，普通 BTHome 广播设备需要按它自己的广播读取方式对接。

[下载示例与运行说明](https://github.com/qingzhu-ai-public/qingzhu-blue/tree/main/examples/flutter/thermometer-mvp) · [开发指南](#flutter/development-guide/overview)
