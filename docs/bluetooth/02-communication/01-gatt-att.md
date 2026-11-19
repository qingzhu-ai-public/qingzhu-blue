---
title: GATT 与 ATT 读写、通知和确认
order: 10
summary: 沿着温度服务找到特征和描述符，分清读写响应、通知以及业务回执分别确认了什么。
tags: GATT, ATT
updated: 2026-11-19
---

# GATT 与 ATT 读写、通知和确认

传感器连接后，手机需要读一次当前温度，并在温度变化时收到更新。固件可以提供一个自定义服务，把温度读数和采样间隔分别放在不同的特征里，手机按双方约定的 UUID 和数据格式访问它们。

## 从服务找到可以操作的值

| 对象 | 在例子里负责什么 |
|---|---|
| Service | 把温度读数和采样间隔组织在一起 |
| Characteristic | 提供一项具体数据及其属性。温度读数可以支持 Read 和 Notify，采样间隔可以支持 Write |
| Descriptor | 给某个特征补充信息或配置。支持 Notify 或 Indicate 的特征使用 CCCD 配置这些操作 |

GATT 定义这些对象的组织方式以及发现、读写和订阅流程。ATT 提供访问属性表的协议操作。UUID 表示属性的类型，句柄（Handle）是在某个服务端属性表里定位条目的编号。一个数据库里可能有多个相同 UUID 的实例。固件升级也可能改变句柄，客户端应按平台提供的服务发现和缓存更新机制处理。

GATT Server 提供属性表，GATT Client 发起对这些属性的操作。温度传感器常同时是 GAP Peripheral 和 GATT Server，手机常同时是 GAP Central 和 GATT Client。两套角色分别描述连接关系和属性访问关系，同一条连接的两端都可以提供属性表。

## 看清操作完成到哪一层

| 操作 | 发起方向 | 协议层结果 |
|---|---|---|
| Read | Client → Server | Server 返回属性值或错误 |
| Write with Response | Client → Server | Server 返回写入响应或错误 |
| Write without Response | Client → Server | ATT 没有对应的写入响应 |
| Notify | Server → Client | ATT 不要求客户端逐条确认 |
| Indicate | Server → Client | Client 在 ATT 层返回确认 |

写入采样间隔的命令可能先由通信模块接收，再交给设备任务保存和生效。如果业务要确认配置已经生效，约定一条带命令编号的结果消息，或读回当前配置。Indication 的确认同样只到 ATT 层，应用是否处理并保存了温度还要看应用逻辑。

## 订阅成功后还要验证一次

CCCD 的 UUID 是 `0x2902`，通常由客户端配置。值 `0x0001` 启用 Notify，`0x0002` 启用 Indicate，`0x0000` 关闭。设置前先看特征声明支持哪种模式，按平台 API 打开本地接收并完成远端设置。订阅完成后，让传感器产生一个新的读数，再观察客户端是否收到、字节序是否解对。

Android 的具体步骤见[服务发现](#android/development-guide/service-discovery)、[特征读写](#android/development-guide/characteristic-rw)和 [Notify、Indicate 与 CCCD](#android/development-guide/notify-cccd)。下一篇讲[一条温度记录装不下时怎么传](#bluetooth/communication/data-transfer)。

## 参考

[Bluetooth Core 6.2 GATT](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/generic-attribute-profile--gatt-.html) · [Bluetooth Core 6.2 ATT](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/attribute-protocol--att-.html)
