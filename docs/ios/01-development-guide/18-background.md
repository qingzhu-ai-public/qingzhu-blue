---
title: 17　切到后台，温度还能更新吗
slug: background
order: 180
---

# 17　切到后台，温度还能更新吗

温度页在前台会更新。锁屏或切到别的 App 后，要把「还能收到事件」和「App 一直在运行」分开看。

## 先用前台版本确定基线

现成教学工程退到后台就清理会话。改变产品需求时，在 Xcode 的 Background Modes 里选择对应角色。中心端对应 `bluetooth-central`，外设端对应 `bluetooth-peripheral`。系统对后台扫描和广播的限制与前台不同。需要收指定设备时使用协议服务 UUID，并在实际目标系统上验证发现和更新的耗时。

## 需要状态恢复时，要能接住恢复回调

为需要恢复的 manager 配置稳定的恢复标识，如中心端的 `CBCentralManagerOptionRestoreIdentifierKey`。系统可能在 `centralManager(_:willRestoreState:)` 交还先前的外设、扫描配置等。恢复时重新接上代理，再按恢复对象和业务状态判断是否继续发现、读写或订阅。业务数据和用户意图仍应自行持久化。

恢复与后台唤醒都有系统条件。按前台、锁屏、切后台、系统终止、用户强退分别验证。Apple 的 TN3115 还注明了 iOS 26 和 iPadOS 26 对部分重新启动场景的 AccessorySetupKit 条件。发布前按目标系统和具体场景对表复测。

**动手验证**　为每种场景记录是否收到扫描、连接或值更新事件，以及进程是否重新启动。将看不到界面更新与收不到事件分开记录。

**一句话记住**　后台模式让系统在特定事件下交付蓝牙工作，恢复时 App 还要接回自己的状态。

## 自查题

1. **打开后台模式可一直运行定时器吗？** 系统调度由后台规则决定，蓝牙事件能力不能当常驻运行保证。
2. **为什么不能只测切后台？** 锁屏、系统清除与用户强退的行为可能不同。

[Apple 后台处理说明](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html) · [Apple TN3115](https://developer.apple.com/documentation/technotes/tn3115-bluetooth-state-restoration-app-relaunch-rules)

[上一章](#ios/development-guide/pairing-security) · [正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/multi-device)
