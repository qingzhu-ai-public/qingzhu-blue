---
title: 后台、前台服务与进程生命周期
order: 250
summary: 退到后台时，先说清谁来触发、谁来维持连接、进程重启后凭什么继续。
tags: SDK,工程实践
updated: 2026-11-19
---

# 第 24 章　后台、前台服务与进程生命周期

用户点了「给标签换图」，文件还没发完，就切去回消息。他回来时，希望看到传输还在走，或者看到这次任务停在了哪里。另一个需求是标签回到附近时，App 再处理一条待发任务。两种场景都会提到「后台」，启动时机却不同。

先问用户什么时候开始这件事，打算持续多久，期间应不应该有通知。用户已经从页面主动发起的持续传输，可以用合适的前台服务维护。想等设备靠近再做事，需要系统能在发现时把事件交下来。进程如果退出，还要靠保存过的任务进度决定怎么恢复。

| 需求 | 可以用的机制 | 需要实测 |
| --- | --- | --- |
| 进程未运行时收到扫描匹配 | `BluetoothLeScanner.startScan(..., PendingIntent)` | 过滤是否命中、匹配时能否投递、后续工作能否启动 |
| 找已关联的配件、在附近时唤起应用服务 | Companion Device Manager + `CompanionDeviceService` | 关联类型、存在事件、设备地址轮换 |
| 用户发起并可感知的持续连接或传输 | 前台服务 `connectedDevice` | 启动限制、通知、取消和断开路径 |
| 可延后且有明确终点的工作 | WorkManager 或适当的短任务 | 系统调度、重试、时长和连接释放 |

## 用户已经按下「开始换图」

前台服务可以让用户通过通知知道传输还在继续。适合这个例子的启动时机，是用户还在页面上并主动发起换图时。Android 12 起从后台启动前台服务受限制，按文档核对业务是否属于豁免。对目标 API 34+，声明 `FOREGROUND_SERVICE` 和 `FOREGROUND_SERVICE_CONNECTED_DEVICE`，在服务上标记 `android:foregroundServiceType="connectedDevice"`。启动时满足类型前提，BLE 场景可通过适用的蓝牙运行时权限满足。调用 `startForegroundService` 后在系统期限内发布前台通知并进入前台。用户停止业务时，结束连接和通知，服务也停止。

## 到附近再开始，先让系统记得这台配件

API 26 起 `CompanionDeviceManager.associate` 可让系统代为查找配件并让用户选择。清单声明 `android.software.companion_device_setup` 所需功能。构造请求时用 `BluetoothLeDeviceFilter` 关联扫描过滤器，或用 `BluetoothDeviceFilter` 查经典设备。

```kotlin
val companionFilter = BluetoothLeDeviceFilter.Builder()
    .setScanFilter(productScanFilter)
    .build()
val request = AssociationRequest.Builder()
    .addDeviceFilter(companionFilter)
    .setSingleDevice(true)
    .build()
// API 33+
companionManager.associate(request, context.mainExecutor, associationCallback)
```

旧重载参数是 `(request, callback, handler)`。API 33+ 在 `onAssociationPending(intentSender)` 中启动系统选择界面，从 `onAssociationCreated(associationInfo)` 保存关联 ID。API 26–32 用 `onDeviceFound(intentSender)` 与对应 Activity 结果。处理用户取消和 `onFailure`。关联是系统授予应用与设备的关系，完成后按需创建实际 GATT 或 Socket 连接。API 33+ 用 `getMyAssociations()` 获取有效关联，`disassociate(id)` 清除。

API 31–35 可以调用 `startObservingDevicePresence(address)`，经 `CompanionDeviceService` 感知出现与离开。API 36+ 使用 `ObservingDevicePresenceRequest.Builder().setAssociationId(id).build()` 及对应开始和停止重载，处理 `onDevicePresenceEvent(event)`。声明 `REQUEST_OBSERVE_COMPANION_DEVICE_PRESENCE`，服务使用 `BIND_COMPANION_DEVICE_SERVICE` 并按官方方式注册。确需后台运行或启动前台服务时，分别核对 `REQUEST_COMPANION_RUN_IN_BACKGROUND`、`REQUEST_COMPANION_START_FOREGROUND_SERVICES_FROM_BACKGROUND` 的适用条件。

## 再打开 App，接着传哪一份文件

比如 App 再打开时，先读持久化的文件任务、最后确认的事务和配件关联 ID，检查用户仍希望继续、权限仍有效。按设备协议查询已提交进度，再为当前设备重建连接。原来的 GATT 对象、回调队列和定时器随着进程结束。界面旋转、系统回收、用户强行停止和手机重启各测一次，记录恢复是由哪一个事件触发的。

## 一句话总结

**退到后台时，先说清谁来触发、谁来维持连接、进程重启后凭什么继续。**

## 面试题

1. 用户从前台主动开启持续 BLE 传输，目标 API 34+ 时怎样配置前台服务？
2. Companion 关联成功后，可以马上对设备写 GATT 特征吗？
3. 进程被回收后，应保存什么来续传？

### 参考答案

1. 按 `connectedDevice` 类型声明服务和前台服务权限，满足类型的运行时前提，启动后及时进入前台并提供通知与取消入口。
2. 关联记录让系统知道这个 App 与配件的关系。需要读写时还要建实际 GATT 连接并发现服务。
3. 保存用户意图、业务事务标识和已确认进度。恢复时重新核对设备和权限，再按设备协议重建会话。

[后台 BLE 通信](https://developer.android.com/develop/connectivity/bluetooth/ble/background) · [伴生设备配对](https://developer.android.com/develop/connectivity/bluetooth/companion-device-pairing) · [前台服务类型](https://developer.android.com/develop/background-work/services/fgs/service-types)
