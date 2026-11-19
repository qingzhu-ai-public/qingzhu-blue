---
title: 附录 A 术语表
order: 320
summary: [协议栈与核心概念](02-协议栈与核心概念.md) · [API 总索引](附录B-API速查.md)
tags: SDK,附录
updated: 2026-11-19
---

# 附录 A　术语表

| 术语 | 本书中的含义 |
| --- | --- |
| BR/EDR / Classic | 经典蓝牙。Android 的 RFCOMM、A2DP、HFP 等走对应的经典接口。 |
| LE / BLE | 低功耗蓝牙。可用于广播、GATT、LE CoC、LE Audio 等。 |
| GAP | 规定发现、连接、角色和安全流程等通用行为的 Profile。 |
| Broadcaster / Observer | 发送广播、接收广播的 GAP 角色。可以用于无连接数据。 |
| Central / Peripheral | LE 连接角色，常见流程由 Central 发起、Peripheral 接受。 |
| GATT | 通用属性 Profile，规定服务、特征、描述符的组织和操作。 |
| ATT | 属性协议。请求通过 handle 定位具体属性，承载读、写、通知和指示等。 |
| Service | 一组相关的特征，可以包含其他服务。 |
| Characteristic | 服务中的一项能力及其值，含属性声明和可选描述符。 |
| Descriptor | 与特征关联的附加属性。 |
| CCCD | 客户端特征配置描述符，16 位 UUID 为 `0x2902`。配置 Notify / Indicate。 |
| UUID / Handle / Instance ID | UUID 标识属性类型。Handle 是 ATT 属性表中的定位值。Instance ID 用于区分当前 Android 属性实例。 |
| AD Structure / Scan Response | 广播数据由长度、类型和数据组成。可扫描广播允许扫描端发请求获得附加响应。 |
| RSSI / Tx Power | 接收信号强度与发射功率。RSSI 受遮挡、方向与环境影响。 |
| MTU / PHY / DLE | ATT 单元容量、物理层模式、链路层数据长度扩展，分别改变不同层的限制。 |
| L2CAP CoC / PSM | 面向连接的 L2CAP 通道及其服务复用标识。 |
| RFCOMM / SDP | 经典蓝牙上的串口式传输，以及用于定位服务的发现协议。 |
| SMP / Bond | LE 安全管理协议及配对后保存的密钥关系。 |
| IRK / RPA | 身份解析密钥与可解析私有地址。知道相应 IRK 的系统可识别轮换地址。 |
| HCI / Snoop | Host 和 Controller 的接口及该接口的记录。 |
| ATT ACK / 业务 ACK | 协议操作的响应或确认，以及业务设备对指令或事务的确认。两类消息在日志中分开写。 |
| Profile Proxy | 应用用于查询或调用系统蓝牙 Profile 服务的代理对象。 |
| Companion 关联 | 系统保存的应用与伴生设备的关系，关联后再按业务建立实际连接。 |
| Channel Sounding | 依赖双方能力的蓝牙测距技术。Android 在 API 36 提供统一测距接口。 |

[协议栈与核心概念](#android/development-guide/protocol-stack) · [API 总索引](#android/development-guide/appendix-b-api)
