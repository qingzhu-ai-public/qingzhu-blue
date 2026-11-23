---
title: 综合实战　做一个 HarmonyOS 蓝牙温湿度计
slug: overview
order: 0
---

# 综合实战　做一个 HarmonyOS 蓝牙温湿度计

手机 A 扫到设备，等连接和服务发现成功，再写入一条指令。手机 B 用同一套代码模拟外设。第一次请求成功后，页面应得到 26.50 °C 和 50.55% RH。

| 篇目 | 做完能看到什么 |
| --- | --- |
| [原型与工程入口](#harmonyos/thermometer-mvp/prototype) | 点通原型，把 App 装上第一台手机 |
| [扫描篇](#harmonyos/thermometer-mvp/scan) | 看到教学外设和信号强度 |
| [连接篇](#harmonyos/thermometer-mvp/connection) | 「请求新读数」按钮可以点击 |
| [传输篇](#harmonyos/thermometer-mvp/transfer) | 写入 01，读回并解析温湿度 |
| [双机验收篇](#harmonyos/thermometer-mvp/two-phone-check) | 让第二台手机模拟设备并做异常验证 |

[ArkTS 示例源码与导入步骤](https://github.com/qingzhu-ai-public/qingzhu-blue/tree/main/examples/harmonyos/thermometer-mvp) · [返回开发指南](#harmonyos/development-guide/overview)

读取响应借用 BTHome v2 的字段布局。扫描识别的是教学服务 UUID，连上后使用双方约定的 GATT 服务和命令。当前真机步骤列的是预期结果。
