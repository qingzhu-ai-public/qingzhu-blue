---
title: 经典蓝牙与 BLE 怎么选
order: 20
summary: 先对照设备支持的 Profile，再按连接方式、数据方向和功耗决定用哪条链路。
tags: 入门, 选型
updated: 2026-11-19
---

# 经典蓝牙与 BLE 怎么选

接一台存量串口设备时，说明书可能写着 SPP。换成一台电池供电的温度传感器，说明书上更可能是一组 GATT 服务和特征 UUID。两台设备都叫蓝牙设备，App 要使用的通信接口却完全不同。

## 先问两端支持什么

| 要做的事 | 先确认的能力 |
|---|---|
| 接已支持 SPP 的串口设备 | 设备支持经典蓝牙 BR/EDR 上的 SPP，目标平台也允许应用访问这个 Profile |
| 给存量耳机播放音乐或接听电话 | 耳机和手机是否共享 A2DP 或 HFP 等对应的经典蓝牙 Profile |
| 做电池传感器，需要读数和参数设置 | BLE 是否满足更新频率和功耗要求，双方是否约定了 GATT 接口 |
| 给附近多台接收设备发少量状态 | BLE 广播的载荷和接收延迟是否够用，业务能否容忍漏收 |
| 接 LE Audio 设备 | 两端是否支持相应的 LE Audio Profile 和角色 |

设备标注「双模」，表示支持 BR/EDR 和 LE 两种传输。具体能用哪些 Profile，还要查设备和目标平台。版本号可以帮你查规范，但应用能不能调用某项能力，需要查系统接口并拿目标设备验证。

## 把实际数据量算出来

传感器每分钟更新一次温度，和应用一次下载一天的历史记录，对链路的要求很不一样。把单次数据量、更新频率、能容忍的延迟写下来，再决定读数直接随广播发出，还是建立连接后再传。

广播适合多台接收设备独立收听。某一台接收器漏掉一条读数，可以根据下一条更新恢复。配置写入则需要设备明确反馈结果，通常用连接上的双向通信更合适。

对持续传输的业务，用目标手机和外设实测有效吞吐、断连和功耗。规格里的 PHY 速率只描述物理层，应用实际每秒能传多少数据，还受协议开销、连接参数和两端处理速度影响。

## 接着读

走 BLE 的设备先看[广播与扫描](#bluetooth/fundamentals/advertising)。接经典蓝牙串口设备时，可以对照 [Android RFCOMM 与 L2CAP Socket](#android/development-guide/rfcomm-socket)。

## 参考

[Bluetooth SIG 技术概览](https://www.bluetooth.com/learn-about-bluetooth/tech-overview/) · [Serial Port Profile](https://www.bluetooth.com/specifications/specs/serial-port-profile-1-2/)
