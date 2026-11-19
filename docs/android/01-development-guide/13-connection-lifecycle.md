---
title: BLE 连接生命周期
order: 140
summary: 拿到 `BluetoothGatt` 是开始办这次连接，连接回调和后续准备完成后才开放读写功能。
tags: SDK,BLE
updated: 2026-11-19
---

# 第 13 章　BLE 连接生命周期

用户从列表里点中温度计。你准备点亮「读温度」按钮，先等手机和温度计把连接建好，再找出设备提供的温度功能。你可以把这段分成三个用户看得懂的状态。「正在连接」「已连上，正在准备」「可读取」。

第一步是拿着刚扫到的设备调用 `connectGatt`。返回的 `BluetoothGatt` 可以理解为这一次会话的操作对象，你会用它发现服务、读写和关闭连接。真正的建连结果从 `onConnectionStateChange` 回来。对某些产品，还要等发现服务、必要订阅和认证完成，业务才算就绪。

```text
取得新鲜 ScanResult.device
  → connectGatt 得到客户端句柄
  → onConnectionStateChange(GATT_SUCCESS, STATE_CONNECTED)
  → discoverServices / onServicesDiscovered
  → 订阅、认证或读取能力
  → READY
  → 断开、关闭、结束本次会话
```

## 点下设备时，手机怎样发起连接

调用发生在手机端，接收请求的是刚才扫到的 `BluetoothDevice`。现代目标应用先检查 `BLUETOOTH_CONNECT`。旧重载在 API 37 起弃用，在更早设备上仍是兼容路径。下表可用来对照手上的 SDK 和手机版本。

| 引入版本 | 签名中的参数 | 怎么选 |
| --- | --- | --- |
| 18 | `Context, boolean autoConnect, BluetoothGattCallback` | 最早版本的兼容形式。 |
| 23 | 上述参数加 `int transport` | 连接双模设备的 LE 服务时传 `TRANSPORT_LE`。 |
| 26 | 上述参数加 `int phy` | 位掩码表达建连时偏好的 PHY，`autoConnect=true` 时该选项不生效。 |
| 26 | 上述参数加 `Handler handler` | 把回调送到指定 Handler。传空时由平台选择回调线程。 |
| 37 | `BluetoothGattConnectionSettings, Executor, BluetoothGattCallback` | 建连参数放入 Builder，用 Executor 明确回调执行器。结果可能为 `null`。 |

以下片段要求 `compileSdk >= 37`。同一个串行 Executor 还可承载超时、取消和写队列。设备低于 API 26 时，将回调入口转投到同一串行执行器。

```kotlin
val gatt = when {
    Build.VERSION.SDK_INT >= 37 -> {
        val params = BluetoothGattConnectionSettings.Builder()
            .setTransport(BluetoothDevice.TRANSPORT_LE)
            .setAutoConnectEnabled(false)
            .build()
        device.connectGatt(params, serialExecutor, callback)
    }
    Build.VERSION.SDK_INT >= 26 -> device.connectGatt(
        context, false, callback, BluetoothDevice.TRANSPORT_LE,
        BluetoothDevice.PHY_LE_1M_MASK, gattHandler
    )
    Build.VERSION.SDK_INT >= 23 -> device.connectGatt(
        context, false, callback, BluetoothDevice.TRANSPORT_LE
    )
    else -> device.connectGatt(context, false, callback)
}
```

`autoConnect=false` 适合用户刚选中设备、希望立即尝试的场景。`autoConnect=true` 请求在外设可用时连接，适合有明确持续意图的会话。它仍需要取消策略，进程退出后应用要按后台机制恢复。API 37 的 Builder 可用 `setAutomaticMtuEnabled(false)` 禁用这一路径的自动 MTU 交换，默认开启。`setOpportunisticEnabled(true)` 用于不持有物理连接的机会式客户端。选择机会式连接前要允许「最后一个实际客户端离开后，本会话随之断开」。

37.2 的 `setPathlossThresholdDb` 和 `setRssiThresholdDbm` 是后台自动建连的控制器偏好，已有链路可跳过这类门槛。系统也可能合并多应用的请求。使用小版本 API 时按 `SDK_INT_FULL` 和对应 `VERSION_CODES_FULL` 判断，并验证设备的实际能力。

## 哪一刻算连上，哪一刻该释放

回调回来时，App 先检查是不是正在等的那个 GATT。再看 `status` 和 `newState`。两者分别是 `GATT_SUCCESS` 和 `STATE_CONNECTED` 时，才进入服务发现。失败或断开就结束当前等待，记下阶段、耗时和原始状态。用户取消再重试时，用 `gatt === activeGatt` 或会话代次区分旧回调和新连接。

- `BluetoothGatt.disconnect()` 请求断开或取消待连接。需要等待断开的场景安排截止时间。
- `BluetoothGatt.close()` 释放客户端注册和资源。会话结束、建连失败、超时后都应走单一收口，调用一次并丢弃引用。关闭后不可沿用这个客户端。
- `BluetoothGatt.connect()` 是在尚未关闭的 GATT 客户端上尝试重连，返回是否开始。普通的一次性业务会话可以在断开后关闭、重新获取设备句柄、创建新客户端。
- `BluetoothManager.getConnectionState(device, BluetoothProfile.GATT)` 反映系统视角的连接状态。当前业务会话就绪应按自己的回调、服务和订阅状态判断。

要查多个设备，使用 `BluetoothManager.getConnectedDevices(BluetoothProfile.GATT)` 或 `getDevicesMatchingConnectionStates(BluetoothProfile.GATT, states)`。`BluetoothGatt` 和 `BluetoothGattServer` 上的同名 `BluetoothProfile` 查询会抛 `UnsupportedOperationException`。

将「扫描找到设备」「已调用连接」「连接回调」「服务发现开始」「服务发现结束」分别计时。这个时间线能解释长时间等待究竟发生在哪一段。Android 官方后台指南说明，Android 10 之前的连接请求逐个处理，Android 10 起可以分批处理。手机可支持的连接数和适合产品的并发数仍需实测。

## 一句话总结

**拿到 `BluetoothGatt` 是开始办这次连接，连接回调和后续准备完成后才开放读写功能。**

## 面试题

1. `connectGatt()` 返回对象，能马上读温度吗？
2. `disconnect()` 和 `close()` 各做什么？
3. 旧连接超时后，新连接为什么要核对 `gatt` 实例？

### 参考答案

1. 先等本次 GATT 的连接成功回调，再发现服务并拿到目标特征。需要订阅或认证的设备还要完成对应步骤。
2. 前者请求断开连接或取消连接尝试，后者释放本次 GATT 客户端注册和资源。会话终止时安排一次完整清理。
3. 旧回调可能迟到。核对实例或代次，可以防止旧结果推进当前会话。

[BluetoothDevice](https://developer.android.com/reference/android/bluetooth/BluetoothDevice) · [BluetoothGattConnectionSettings.Builder](https://developer.android.com/reference/android/bluetooth/BluetoothGattConnectionSettings.Builder) · [BluetoothGattCallback](https://developer.android.com/reference/android/bluetooth/BluetoothGattCallback) · [后台 BLE 通信](https://developer.android.com/develop/connectivity/bluetooth/ble/background)
