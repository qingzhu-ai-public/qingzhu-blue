---
title: 11　接真实配件前，先问厂商哪几个问题
slug: pairing-and-security
order: 120
---

# 11　接真实配件前，先问厂商哪几个问题

换成一台真实电子秤。包装上的蓝牙版本帮不了你决定怎么发指令，先要设备的协议。

## 先确认接口类型

问厂商设备使用 BLE GATT、经典蓝牙 Profile、串口通道还是专用 SDK，是否公布服务及特征 UUID，是否有公开协议与可验证的样例。BLE 中心端的这一套服务发现和特征读写适用于 GATT 数据入口。经典蓝牙或系统音频功能按对应框架和权限接入。

## 分清蓝牙授权、配对和业务认证

用户授权给 App 使用本机蓝牙，配对涉及设备之间建立安全关系。厂商业务认证可能还要求应用按协议发登录指令。某项值读失败时先记录系统错误、是否配对及协议限制，再决定下一步。程序不应硬编码真实设备密钥或把鉴权帧留在公共日志。

**自己试一次**　根据厂商文档列出发现方式、连接方式、第一条请求和成功回包。先跑通这一条再扩大范围。

**一句话记住**　选 API 前先弄清楚配件用哪种协议。

## 自查题

1. **已经建立连接，是不是所有特征都能读？** 还要看特征属性、访问要求和配件的业务状态。

[华为 Connectivity Kit 蓝牙指南](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-guides/gatt-development-guide/)

[上一章](#harmonyos/development-guide/troubleshooting) · [正文目录](#harmonyos/development-guide/overview)
