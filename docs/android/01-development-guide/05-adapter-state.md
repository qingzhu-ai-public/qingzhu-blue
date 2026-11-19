---
title: 适配器、蓝牙开关与状态广播
order: 60
summary: 按钮发出开启请求，系统进到 `STATE_ON`，这两步分别记录。
tags: SDK,平台,协议
updated: 2026-11-19
---

# 第 5 章　适配器、蓝牙开关与状态广播

用户点了「搜索温度计」，但刚从快捷设置关掉蓝牙。页面该做的是说明当前蓝牙关着，给用户一个开启的入口，等他同意并且蓝牙真的打开后再搜索。

App 通过本机的 **BluetoothAdapter（蓝牙适配器）** 查询开关和能力。这是手机这一端的对象。它告诉你本机是否准备好，还可以提供扫描器或广播器。先用 `BluetoothManager.getAdapter()` 获取它。这条入口从 API 18 提供。用类型取系统服务需要 API 23，兼容更低版本时传 `Context.BLUETOOTH_SERVICE`。

下面接到按钮处理里。调用前完成[权限检查](#android/development-guide/permissions)。如果没有适配器，界面应说明手机无法使用这项功能。适配器存在且已经开启，就进扫描流程。蓝牙关闭时，App 通过系统界面让用户决定是否开启。

```kotlin
val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
val adapter = manager?.adapter ?: return
if (adapter.isEnabled) {
    startBluetoothFeature(adapter)
} else {
    enableLauncher.launch(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE))
}
```

`enableLauncher` 用 `ActivityResultContracts.StartActivityForResult()` 提前注册。收到结果后重新读取适配器状态，等它进入 `STATE_ON` 再使用扫描器。用户也可能在页面打开时从快捷设置关闭蓝牙，所以还要监听系统发来的 `ACTION_STATE_CHANGED`。

| 方法或事件 | 调用结果与约束 |
| --- | --- |
| `BluetoothAdapter.getDefaultAdapter()` | API 5，API 31 起弃用。使用上下文关联的 `BluetoothManager`。 |
| `isEnabled()` / `getState()` | 快照。后者可区分 `OFF`、`TURNING_ON`、`ON`、`TURNING_OFF`。 |
| `ACTION_REQUEST_ENABLE` | 拉起系统授权界面。现代应用需要 `BLUETOOTH_CONNECT`。 |
| `enable()` / `disable()` | API 33 弃用。Android 13+ 上目标 API 33+ 的普通应用会收到 `false`，设备所有者、配置文件所有者及系统应用有豁免。 |
| `ACTION_STATE_CHANGED` | 从 `EXTRA_STATE` 和 `EXTRA_PREVIOUS_STATE` 读取新旧状态。 |
| `getBluetoothLeScanner()` / `getBluetoothLeAdvertiser()` | API 21，蓝牙关闭可返回 `null`。Advertiser 还需要设备支持。 |
| `getRemoteDevice(address)` | 把格式合法的地址构造成句柄，调用本身不扫描、不连接。 |
| `getRemoteLeDevice(address, addressType)` | API 33，调用方提供 public/random 地址类型。来自扫描的 `result.device` 能保留平台给出的设备句柄。 |

动态接收器在发起操作前注册，结束时注销。Android 文档要求使用 AndroidX `ContextCompat.registerReceiver` 时，对来自蓝牙等高权限组件的系统广播使用 `RECEIVER_EXPORTED` 接收。把过滤器限制为所需动作，收到后核对 action，并在推进状态机前重新读取适配器状态。应用自有事件放到单独的非导出接收器。

用快捷设置试一次，把蓝牙关掉再打开。进入 `TURNING_OFF` 时，App 停止发新请求，结束当前扫描和连接，取消相关计时器，再把等待中的操作报告为结束。重新收到 `ON` 后，如果用户还希望搜索，重新获取 Scanner 或 Advertiser 并开一轮。回调处理前检查它属于哪一轮，避免把刚关掉的那轮结果显示到新的列表。

## 一句话总结

**按钮发出开启请求，系统进到 `STATE_ON`，这两步分别记录。**

## 面试题

1. 现代普通 App 如何让用户打开蓝牙？
2. 扫描过程中蓝牙被关闭，重新打开后如何恢复？

### 参考答案

1. 发起 `ACTION_REQUEST_ENABLE`，收到结果及状态变化后，用适配器确认 `STATE_ON`。
2. 结束上一轮扫描和连接。重新获取 Scanner，按用户意图创建新会话，并忽略旧会话已经排队的回调。

[BluetoothAdapter](https://developer.android.com/reference/android/bluetooth/BluetoothAdapter) · [动态广播接收器](https://developer.android.com/develop/background-work/background-tasks/broadcasts)
