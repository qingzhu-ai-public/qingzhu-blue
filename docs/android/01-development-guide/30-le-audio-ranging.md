---
title: 低功耗音频与蓝牙测距
order: 310
summary: 耳机声音走哪儿查实际路由，配件离多远查实际测距，两件事都先经过系统能力检查。
tags: SDK,架构
updated: 2026-11-19
---

# 第 30 章　低功耗音频与蓝牙测距

同一副蓝牙耳机，可以有两个完全不同的产品需求。通话时，用户想让声音从耳机出来。耳机落在房间里时，另一个功能可能想显示配件离手机有多远。一个要选音频设备，另一个要做测距。

**LE Audio** 是系统支持的低功耗蓝牙音频能力。应用需要看系统允许选哪些通信设备、当前实际去了哪里。**测距**则由 Android 的测距模块安排会话，拿到距离样本后才有数据可显示。沿用前面章节的习惯，先确认设备能力，再选 Android 的入口。

## 通话页面选了耳机，怎么知道声音过去了

API 33 起，`BluetoothAdapter.isLeAudioSupported()`、`isLeAudioBroadcastSourceSupported()` 和 `isLeAudioBroadcastAssistantSupported()` 返回 `BluetoothStatusCodes`。例如结果等于 `FEATURE_SUPPORTED` 表示本机支持这一能力。需要查询 Profile 时用 `getProfileProxy(..., BluetoothProfile.LE_AUDIO)`，取得并使用 `BluetoothLeAudio`，结束后释放代理。广播能力仅表示平台支持相应角色，具体控制接口还需核对权限。

用户点「切到耳机」时，App 从 Android 12（API 31）起可用 `AudioManager.getAvailableCommunicationDevices()` 找系统可选的设备。按用户选中的条目调用 `setCommunicationDevice(device)`。返回值表示系统是否接受这个路由请求。页面显示当前出口时再读 `getCommunicationDevice()` 或等路由监听，通话结束清除选择并移除监听器。

```kotlin
val chosen = audioManager.availableCommunicationDevices
    .firstOrNull { it.id == selectedId }
if (chosen != null && audioManager.setCommunicationDevice(chosen)) {
    // 读取 communicationDevice，或等待通信设备变更监听器。
}
```

这个入口用于通信。常规媒体播放由系统媒体路由管理。通话同时涉及模式、音频焦点、录音权限和音频设备切换，按应用场景查 [LE Audio 指南](https://developer.android.com/develop/connectivity/bluetooth/ble-audio/overview) 和 [AudioManager](https://developer.android.com/reference/android/media/AudioManager)。

## 找配件时，让系统实际测一次距离

想显示「还差多远」，可以先看两端提供什么能力。BLE RSSI 通过接收信号强弱估计距离，手挡住、设备换个方向，结果都可能变化。Channel Sounding 是另一种测距方式，也需要两端硬件、角色和协商方式匹配。Android 从 API 36 提供 `RangingManager`，先查可用能力，再开一轮测距。

1. 声明并申请 `android.permission.RANGING`。获取 `context.getSystemService(RangingManager::class.java)`。
2. 调 `registerCapabilitiesCallback(executor, callback)`，在回调里检查 `RangingCapabilities` 的可用技术和 `getCsCapabilities()`。离开时 `unregisterCapabilitiesCallback(callback)`。
3. 调 `createRangingSession(executor, sessionCallback)`，为两端按约定配置角色及参数。Raw initiator 路径中可用 `BleCsRangingParams.Builder(peerAddress)`、`RawRangingDevice.Builder().setCsRangingParams(...)`、`RawInitiatorRangingConfig.Builder().addRawRangingDevice(...)` 构造 `RangingPreference`。Responder 与 OOB 路径用对应配置对象。
4. `session.start(preference)` 返回 `CancellationSignal`。观察 session 回调中的成功、失败、结果或停止事件，按 `RangingData` 读取有效的距离和质量信息。停止时调用 `session.stop()`，最终关闭会话。

官方说明普通应用的非 UWB 测距受后台限制。测试选用前台，记录能力、距离、遮挡、角色和样本分布。后续再核对小版本差异和对端设备协议。

## 一句话总结

**耳机声音走哪儿查实际路由，配件离多远查实际测距，两件事都先经过系统能力检查。**

## 面试题

1. `setCommunicationDevice()` 返回 `true`，界面怎样确认当前音频出口？
2. 手机支持 BLE，开启 Channel Sounding 之前还要确认什么？
3. RSSI 变弱一定表示设备更远了吗？

### 参考答案

1. 回读 `getCommunicationDevice()` 或监听通信设备变化，再显示当前路由。会话结束清除选择。
2. 查询测距模块的当前能力、对端支持、双方角色与会话参数，并申请测距所需权限。
3. 距离、遮挡、方向和天线都能影响信号强度，估计距离时应结合场景和连续样本。

[Android 测距指南](https://developer.android.com/develop/connectivity/ranging) · [RangingManager](https://developer.android.com/reference/android/ranging/RangingManager) · 测距 API 签名
