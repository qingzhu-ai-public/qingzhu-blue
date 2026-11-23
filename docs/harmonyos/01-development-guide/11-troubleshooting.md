---
title: 10　搜不到、连不上、收不到，从哪一步查
slug: troubleshooting
order: 110
---

# 10　搜不到、连不上、收不到，从哪一步查

用户说温度不更新时，先记录屏幕最后一条状态。最后一次成功到哪里，就从那里继续排查。

## 把现象写成一条能验证的记录

| 现象 | 先查哪一步 |
| --- | --- |
| 找不到设备 | App 权限和系统开关、B 是否广播、服务 UUID 是否一致 |
| 扫到了却连不上 | connect 调用、连接状态、等待超时 |
| 连上了不能请求 | getServices 是否成功、特征 UUID 是否匹配 |
| 发了指令没有读数 | B 是否收到写、A 是否开始读、原始字节是否完整 |
| 收到数据但算错 | 字段偏移、字节顺序、符号与倍率 |

同步系统调用可能直接抛异常，返回 Promise 的操作还可能在等待时失败。日志保留调用名、阶段、`BusinessError.code` 和 message，记录机型、系统与外设固件版本。两台设备各记一次操作时间，方便核对事件顺序。

**自己试一次**　跑通一次，然后只关 B 的广播、只改一个 UUID、只发错一个指令，各做一轮。每轮先恢复上次改动。

**一句话记住**　排错先找最后一次成功，不靠猜。

## 自查题

1. **发现设备后一直没有发送，要不要先查解析器？** 先查连接和服务发现，解析发生在收到字节以后。

[华为 BLE API 与错误码入口](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-bluetooth-ble/)

[上一章](#harmonyos/development-guide/descriptors-and-long-data) · [正文目录](#harmonyos/development-guide/overview) · [下一章](#harmonyos/development-guide/pairing-and-security)
