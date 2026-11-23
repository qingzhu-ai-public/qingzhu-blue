---
title: 01　为什么还没连接就能看到设备
slug: roles-and-advertising
order: 20
---

# 01　为什么还没连接就能看到设备

两台手机做实验。B 先发出教学服务的广播，A 还没打开连接，就能在列表看到它。

## 广播和连接是两个阶段

广播像外设放在门口的告示。手机 A 扫描，看到名称、服务 UUID 或其他广播字段。服务 UUID 是双方约定的编号。真正的读写要在建立连接后，通过设备提供的服务和特征完成。

| 角色 | 在实战里做什么 |
| --- | --- |
| BLE 中心端 / GATT 客户端 | A 扫描和连接，发出读写请求 |
| BLE 外设 / GATT 服务端 | B 发可连接广播，提供服务并回应 |

中心与外设指发现和连接角色，客户端和服务端指 GATT 里的请求发起方与应答方。本例让 A 同时担任中心与客户端，B 担任外设与服务器。

**自己试一次**　点通实战原型。比较看到设备那一刻和出现温度那一刻。

**一句话记住**　广播负责让别人找到设备，连接后的 GATT 负责交换数据。

## 自查题

1. **看到服务 UUID 就能直接写吗？** 还要连接、发现服务并找到可写的目标特征。

[华为 BLE 扫描与广播](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ble-development-guide/)

[上一章](#harmonyos/development-guide/first-app) · [正文目录](#harmonyos/development-guide/overview) · [下一章](#harmonyos/development-guide/permission-and-state)
