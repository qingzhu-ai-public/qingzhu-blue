---
title: 配对、绑定、加密与地址隐私
order: 30
summary: 判断链路何时需要配对或加密，分清蓝牙地址、设备身份与业务授权。
tags: 安全, 隐私
updated: 2026-11-19
---

# 配对、绑定、加密与地址隐私

手机连上后能读温度，写采样间隔却返回安全相关错误。先查看这个特征的访问权限。固件可以允许读数公开，同时要求配置写入使用加密链路，或要求客户端通过特定级别的认证。

## 把安全状态分开记

| 状态 | 表示什么 |
|---|---|
| 已连接 | 两端的蓝牙链路已建立 |
| 已配对（Pairing） | 两端建立了用于保护通信的共享密钥 |
| 已绑定（Bonding） | 两端保存了配对所得的密钥等信息，供以后重连使用 |
| 当前链路已加密 | 本次连接已启用链路层加密 |
| 应用已授权 | 设备或服务已允许当前使用者执行某项业务操作 |

已绑定的设备重连后，可以用之前保存的密钥启用加密。抓日志时记录本次连接的安全状态，才能区分密钥丢失、加密还没启动，以及属性权限不够。

配对方式取决于双方的输入输出能力、安全要求和支持的流程。LE Secure Connections 使用 Just Works 时可以建立加密，但配对过程缺少中间人防护。如果产品要求抵抗这种风险，就按硬件能力选择支持该防护的配对方式，例如满足交互条件时使用 Numeric Comparison，并独立验证具备哪些业务操作权限。

## 设备地址变了还能认出来吗

BLE 外设可以用可解析私有地址（RPA），地址会变化。持有对方身份解析密钥（IRK）的一侧，可以解析出该地址关联的设备身份。应用能拿到什么标识取决于平台 API 和系统策略。

设备列表、历史数据和任务记录需要长期关联时，使用产品定义的稳定标识。可以在完成可信连接或业务认证后读取设备标识并建立映射。若打算把固定序列号直接放进明文广播，先评估是否允许附近的接收器长期追踪这台设备。设备名、RSSI 和广播里的明文字段均可用于筛选，授权要有独立依据。

## 联调时测一次恢复出厂

用同一对设备测首次配对、重连、外设恢复出厂以及手机侧主动取消绑定。恢复出厂可能让外设丢失已保存的密钥，而手机还留着旧记录。记录两侧各自清除了什么，设备标识和用户归属也按产品流程重新确认。

Android 的操作与边界见[配对与 LE 安全](#android/development-guide/pairing-security)和[地址轮换与隐私](#android/development-guide/address-privacy)。

## 参考

[Bluetooth Core 6.2 Security Manager](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/security-manager-specification.html) · [Bluetooth Core 6.2 GAP](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/generic-access-profile.html)
