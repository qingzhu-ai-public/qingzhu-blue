---
title: 附录 F 从现象查故障
order: 370
summary: 收到故障反馈时先找最后一个成功的阶段。故障发生前的最后一次方法调用和最后一条回调，通常比页面上的统一错误提示更有用。
tags: SDK,附录
updated: 2026-11-19
---

# 附录 F　从现象查故障

收到故障反馈时先找最后一个成功的阶段。故障发生前的最后一次方法调用和最后一条回调，通常比页面上的统一错误提示更有用。

| 现象 | 查什么、怎么验证 | 去哪一章 |
| --- | --- | --- |
| 系统蓝牙列表有设备，App 扫不到 | 确定设备在用经典发现还是 BLE 广播，检查扫描权限和真实广播字段 | [全景](#android/development-guide/overview) · [扫描](#android/development-guide/scanning) |
| 亮屏能扫，熄屏收不到 | 用时间戳判断是扫描还是 UI 停止，复测有效过滤器与 PendingIntent | [过滤与后台扫描](#android/development-guide/scan-filter) |
| 新系统权限已给，还是 `SecurityException` | 确认抛出异常的方法，扫描、查询设备、发广播分别要不同授权 | [权限](#android/development-guide/permissions) |
| `connectGatt` 返回对象后没成功 | 记录句柄新鲜度、连接回调、超时与关闭，按需要取 HCI 时间线 | [连接](#android/development-guide/connection-lifecycle) |
| `getService` 返回空 | 先等发现完成，枚举本次服务列表，查重 UUID、固件版本和服务变化 | [服务发现](#android/development-guide/service-discovery) |
| 写立即返回 busy，或者后面的写没回调 | 检查同一 GATT 实例是否已有在途操作，区分拒绝与等待超时 | [读写](#android/development-guide/characteristic-rw) · [队列](#android/development-guide/thread-state-machine) |
| 本地订阅成功，但没有通知 | 检查 CCCD 写是否受理、完成且用对值，抓设备和 HCI 报文 | [CCCD](#android/development-guide/notify-cccd) |
| Android 14 请求 MTU 247，收到 517 或更小 | 分开记录请求值和协商值，按回调及对端上限计算 | [MTU](#android/development-guide/mtu-phy-dle) |
| 建连/写请求失败报 8、133 或 137 | 先取回调名、阶段和状态码来源，再找 HCI 或 ATT 证据 | [状态码速查](#android/development-guide/appendix-c-codes) |
| 收到写成功，设备没有完成事务 | 查业务 ACK、片序和端侧处理，核对幂等后再重发 | [分包与流控](#android/development-guide/fragmentation-flow) |
| 绑定后读取受保护特征仍失败 | 查看两端绑定记录、当前链路加密和设备的访问要求 | [LE 安全](#android/development-guide/pairing-security) |
| 重新扫描出现两个相同标签 | 对照广播地址轮换、观测时间和经认证的逻辑设备 ID | [设备身份](#android/development-guide/address-privacy) |
| 广播失败提示包太大 | 分开计算主包与 Scan Response，计入名称、UUID、AD 头和 Flags | [广播](#android/development-guide/advertiser) |
| 外设收到写，却无法让另一台手机看到变化 | 核对请求应答、该客户端的 CCCD 和通知发送结果 | [GATT Server](#android/development-guide/gatt-server) |
| 经典蓝牙已配对，Socket 还是连不上 | 核对 SDP UUID、监听、发现是否取消、认证模式是否匹配 | [RFCOMM](#android/development-guide/rfcomm-socket) |
| 蓝牙耳机已连接，通话走了扬声器 | 查可用通信设备、`setCommunicationDevice` 和实际路由变更 | [音频](#android/development-guide/le-audio-ranging) |
| 退到后台或进程退出后不恢复 | 拆开设备发现、任务调度、持续连接和用户的恢复意图 | [后台](#android/development-guide/background-service) |

给自己的排查记录补上手机系统构建、外设固件、应用目标版本、最小复现、操作时间线和失败比例。长期保留的记录进入 行业经验库。
