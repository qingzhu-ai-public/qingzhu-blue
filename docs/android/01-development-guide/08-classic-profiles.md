---
title: 经典蓝牙 Profile 与系统代理
order: 90
summary: 查耳机有没有连上某项功能，用对应 Profile，查声音此刻从哪儿出，用音频路由。
tags: SDK,经典蓝牙
updated: 2026-11-19
---

# 第 8 章　经典蓝牙 Profile 与系统代理

耳机已经连上，你的 App 要在通话界面显示「当前用的是哪副耳机」。先别从耳机的蓝牙地址直接猜。系统知道它连上了哪些服务，也知道此刻把声音送到了哪里。查连接和查实际声音出口，是两件事。

**Profile** 是蓝牙双方实现某类功能时遵循的约定。经典耳机常见的媒体播放走 A2DP，通话有 Headset/HFP 这一类服务。同一副耳机可以同时支持多种功能。App 想看其中一项的连接状态，就向 Android 申请该项 Profile 的代理，再问代理有哪些设备连着。真正的通话输出则交给系统音频路由查询。

| Profile | 典型用途 | 普通应用常用入口 |
| --- | --- | --- |
| A2DP | 经典蓝牙媒体播放 | `BluetoothA2dp.getConnectedDevices()`、`getConnectionState(device)`、`isA2dpPlaying(device)` |
| Headset | HSP/HFP 耳机和通话相关状态 | `BluetoothHeadset.getConnectionState(device)`、`isAudioConnected(device)` |
| HID Device | 手机向对端注册为输入设备 | `BluetoothHidDevice.registerApp`、`sendReport` 等。角色、前台要求和设备支持需单独验证 |
| LE Audio | LE 上的系统音频 Profile | `BluetoothLeAudio` 状态查询及 `AudioManager` 的实际路由 |
| Hearing Aid | 系统助听设备相关能力和音频路由 | 查机型能力标志和系统设置，按公开 Profile/音频路由接口查询 |

## 到 Android 的服务里查一次已连接耳机

`BluetoothAdapter.getProfileProxy(context, listener, profile)` 从 API 11 起可用。布尔返回值说明是否开始请求代理。`onServiceConnected(profile, proxy)` 到达时才取得代理，`onServiceDisconnected(profile)` 说明代理服务失联。若页面先退出，迟到的代理也要交还系统。

```kotlin
val profile = BluetoothProfile.A2DP
val listener = object : BluetoothProfile.ServiceListener {
    override fun onServiceConnected(type: Int, proxy: BluetoothProfile) {
        try {
            if (type == profile) {
                val connected = proxy.connectedDevices
                displayConnectedDevices(connected)
            }
        } finally {
            adapter.closeProfileProxy(type, proxy)
        }
    }

    override fun onServiceDisconnected(type: Int) {
        clearProfileState(type)
    }
}
val requested = adapter.getProfileProxy(context, listener, profile)
```

上面这段代码适合页面打开时查一次列表。要一直展示变化，页面或会话持有代理，先读现有状态，再接收 Profile 广播提供的新旧状态。离开时由持有者调用 `closeProfileProxy(profile, proxy)`。现代应用查询通常需要 `BLUETOOTH_CONNECT`。

`BluetoothDevice.connect()`、`disconnect()` 等接口即使出现在公开参考中，也要核对普通应用权限及 Companion 关联条件。音频路由和 HID 的调用能力取决于调用角色及权限。应用直接打开 RFCOMM 适合自定义字节流。系统 Profile 管理走其公开代理和系统用户入口。

## 手机充当 HID Device

API 28 起可请求 `BluetoothProfile.HID_DEVICE` 的代理。它让手机在用户操作的应用中作为键盘、遥控器等输入设备。先准备与目标设备匹配的 HID Report Descriptor，并通过 `BluetoothHidDeviceAppSdpSettings` 提供名称、描述、提供者、子类型和描述符字节。使用默认 QoS 时传空。

```kotlin
val sent = hid.registerApp(sdpSettings, null, null, executor, hidCallback)
```

`sent` 只说明命令是否成功发送。收到 `onAppStatusChanged(pluggedDevice, true)` 后，再按连接事件推进。`connect(device)` 和 `disconnect(device)` 的连接结果由 `onConnectionStateChanged` 观察。`sendReport(device, reportId, data)` 的数据按描述符编码。主机请求读取报告时，通过 `onGetReport` 接收请求并用 `replyReport` 返回。完成任务后 `unregisterApp()` 并关闭代理。系统只允许同时有一个 HID Device 应用注册，应用退出前台后可被自动注销。

## 一句话总结

**查耳机有没有连上某项功能，用对应 Profile，查声音此刻从哪儿出，用音频路由。**

## 面试题

1. `onServiceConnected(profile, proxy)` 到了，说明耳机已经连接了吗？
2. 如果页面退出时才收到代理，怎么处理？

### 参考答案

1. 它告诉 App 系统代理已可用。用代理的 `getConnectedDevices()` 或 `getConnectionState(device)` 再查设备状态。
2. 把迟到的代理通过 `closeProfileProxy` 交还系统，并丢弃界面更新。

[BluetoothProfile](https://developer.android.com/reference/android/bluetooth/BluetoothProfile) · [BluetoothHidDevice](https://developer.android.com/reference/android/bluetooth/BluetoothHidDevice) · [低功耗音频与测距](#android/development-guide/le-audio-ranging)
