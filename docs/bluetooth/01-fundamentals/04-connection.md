---
title: BLE 建连、连接参数与断线恢复
order: 40
summary: 理解连接事件、外设延迟和监督超时，给业务划出清楚的就绪条件。
tags: 连接, GAP
updated: 2026-11-19
---

# BLE 建连、连接参数与断线恢复

手机收到传感器的可连接广播后，可以发起连接。链路建立后，两端按约定的时序交换数据。这时手机还得找到温度特征，并按业务需要完成订阅或认证，界面才有理由显示「可以读温度」。

## 三个常见参数

| 参数 | 影响 |
|---|---|
| Connection Interval | 相邻连接事件锚点之间的间隔。间隔较短通常有更多交换机会，也可能让设备更频繁地唤醒 |
| Peripheral Latency | 在满足链路规则时，外设可以跳过的连续连接事件数。空闲时可以少唤醒，外设有数据仍可参与连接事件 |
| Supervision Timeout | 链路在规定时间内收不到有效数据包时判定连接丢失。它有自己的时钟，应用命令另设超时 |

估算吞吐时还要看每次连接事件能交换多少数据。缩短连接间隔可能有帮助，也可能因双方调度、干扰或设备处理能力而达不到预期。用目标设备记录实际参数和收发速率，再决定怎么取舍。

## 业务什么时候放行

可以把就绪拆成几个能观察的条件。温度传感器至少要完成以下步骤。

1. 确认本次连接已建立，记录连接或请求编号。
2. 找到需要的服务、特征和订阅描述符。遇到安全要求则按设备协议建立所需安全状态。
3. 手机启用本地接收，并确认服务端接受订阅配置。若固件有应用层握手，等到握手完成再开放对应操作。

这些步骤的顺序会随设备要求变化。例如某个设备会在读特征时才要求加密。日志把每个阶段和错误分别记下来，才能区分连接超时、发现失败和订阅失败。

## 断开后重新建立什么

收到断开事件就让旧连接退出业务队列，丢弃属于旧会话的迟到回调。重新连接后按平台与设备能力确认服务和安全状态，恢复本地监听，再检查服务端订阅配置。按 GATT 规范，服务端为已绑定客户端保留 CCCD，未绑定客户端在每次连接时使用默认值。两种情况下，应用都要确认新会话已经能接收数据。

重连期间先标记待确认的操作。有副作用的命令可能已经在外设执行，只是回执还没回来。要再次下发，先查询设备状态，或按[命令编号与去重规则](#bluetooth/communication/data-transfer)重试。

Android 侧可对照[连接生命周期](#android/development-guide/connection-lifecycle)和[线程、状态机、命令队列与取消](#android/development-guide/thread-state-machine)。

## 参考

[Bluetooth Core 6.2 LE Link Layer](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/low-energy-controller/link-layer-specification.html) · [Bluetooth Core 6.2 GATT](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/generic-attribute-profile--gatt-.html)
