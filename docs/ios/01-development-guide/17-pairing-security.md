---
title: 16　连上了，为什么读一项值却报权限错误
slug: pairing-security
order: 170
---

# 16　连上了，为什么读一项值却报权限错误

温度计已经连接，普通数据能读。有一项配置读不到。先判断错误来自 App 授权、设备的加密要求，还是厂商协议。

## 分清三个环节

| 环节 | 你要观察什么 |
| --- | --- |
| App 蓝牙授权 | `CBManager.authorization`、管理器状态、系统设置 |
| 蓝牙链路与特征权限 | 是否连上、读写回调的 ATT 错误、系统配对提示 |
| 设备业务认证 | 厂商要求的登录、鉴权命令或业务应答 |

iOS 的 Core Bluetooth 由系统管理蓝牙配对过程。对受保护特征读写或订阅时，系统可能按配件与安全配置触发配对。外设端如果需要加密读写，可按实际协议配置 `.readEncryptionRequired` 和 `.writeEncryptionRequired` 等权限。

## 从回调回到协议检查

先确认是目标特征和操作，再看回调 error。`CBATTError.insufficientAuthentication` 与 `insufficientEncryption` 指向不同安全条件。普通属性的 `readNotPermitted` 则提示先核对属性与访问权限。不要因为连上了就反复重发认证请求。先记录系统提示和设备协议，再决定下一步。

**动手验证**　使用一个有加密要求的测试特征，记录第一次和后续访问各出现什么提示、回调给什么错误。

**一句话记住**　连上只是建立通道，通道里哪些数据允许访问还要看设备的安全设置。

## 自查题

1. **蓝牙授权允许就算设备配对了吗？** 授权是用户允许 App 使用蓝牙，配对是蓝牙设备之间的安全过程。
2. **配对等于通过设备业务认证吗？** 业务是否允许操作由设备协议自己的状态或回包决定。

[Apple CBAttributePermissions 文档](https://developer.apple.com/documentation/corebluetooth/cbattributepermissions)

[上一章](#ios/development-guide/packet-flow) · [正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/background)
