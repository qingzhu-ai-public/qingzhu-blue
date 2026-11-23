---
title: 19　搜不到、连不上、收不到，从哪里查
slug: troubleshooting
order: 200
---

# 19　搜不到、连不上、收不到，从哪里查

用户说「蓝牙坏了」。先把这句话换成一条能验证的现象，例如「能扫到，点连接后一直没出现已连接」。

## 按最后成功的一步找

| 最后看到什么 | 下一条要看的记录 |
| --- | --- |
| App 启动 | manager 状态、授权和是否发起扫描 |
| 正在扫描 | 外设是否已广播，过滤的服务 UUID 是否匹配 |
| 已发现设备 | connect 调用、连接结果和超时 |
| 已连接 | 服务/特征发现结果以及属性 |
| 请求已发出 | 对应的写、读或订阅状态回调 |
| 收到字节 | 十六进制、长度和解析结果 |

日志尽量包含时间、角色、试验编号、外设标识、操作阶段、错误域和码。Swift 的 error 转成 `NSError` 后可读取 `domain` 和 `code`。`CBError` 通常描述蓝牙操作或连接错误，`CBATTError` 反映属性协议层的错误，不能混用同一张码表。

## 两端日志对不上，再看抓包

先从客户端和外设各取一份日志。例如外设有收到写请求，而手机读不到值，就先检查读请求有没有发出。需要协议层证据时，按 Apple 的工具说明用 PacketLogger 或外部 BLE 抓包设备。日志里避免留下用户信息和真实设备密钥。

**动手验证**　把客户端请求的特征 UUID 改错一次，找出最后一个成功回调，恢复后重做对照。

**一句话记住**　先把「蓝牙坏了」缩小到一个有证据的失败阶段。

## 自查题

1. **错误码数字一样就一定同义吗？** 先看错误域和出现阶段。
2. **没有任何 didDiscover 时先抓读写吗？** 先查扫描与广播，读写还没开始。

[Apple Core Bluetooth 错误类型](https://developer.apple.com/documentation/corebluetooth) · [Apple 关于 PacketLogger 的讲解](https://developer.apple.com/videos/play/wwdc2019/901/)

[上一章](#ios/development-guide/multi-device) · [正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/testing)
