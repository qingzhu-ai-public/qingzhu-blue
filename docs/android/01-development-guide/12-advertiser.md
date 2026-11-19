---
title: 传统、扩展与周期广播
order: 130
summary: 发广播前先确定别人要靠什么找你，再按这一段数据的大小和用途选广播方式。
tags: SDK,BLE
updated: 2026-11-19
---

# 第 12 章　传统、扩展与周期广播

把两台手机的位置换一下。一台负责找设备，另一台要出现在它的列表里。前几章你写的是扫描端，这一章给第二台手机加个「开始广播」按钮。按下去以后，第一台就有机会扫到你放进去的服务 UUID。

**广播**是手机在连接前主动发的一小段数据。可以只发状态供别人看，也可以发出「我这里接受连接」的广播。如果要给别人连进来读写，先把本机的 GATT Server 服务准备好，等 `onServiceAdded` 成功，再发可连接广播。这样扫描端一找到你，连接后就能发现已注册的服务。

## 先发一个带服务 UUID 的传统广播

API 21 起从 `adapter.bluetoothLeAdvertiser` 取得对象。结果可能为空，另可用 `isMultipleAdvertisementSupported()` 查询多广播能力。现代目标版本需 `BLUETOOTH_ADVERTISE`。下例发送一个服务 UUID。这个自定义 128 位 UUID 在传统广播主数据中就要占 18 字节，包括长度和类型。

```kotlin
val advertiser = adapter.bluetoothLeAdvertiser ?: return
val settings = AdvertiseSettings.Builder()
    .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
    .setConnectable(true)
    .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
    .setTimeout(0)
    .build()
val primary = AdvertiseData.Builder()
    .addServiceUuid(ParcelUuid(serviceUuid))
    .setIncludeDeviceName(false)
    .build()
val callback = object : AdvertiseCallback() {
    override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
        showAdvertising(settingsInEffect)
    }
    override fun onStartFailure(errorCode: Int) {
        showAdvertisingError(errorCode)
    }
}
advertiser.startAdvertising(settings, primary, callback)
// 后续结束会话时 advertiser.stopAdvertising(callback)
```

另一台手机主要靠服务 UUID 匹配设备，优先把 UUID 放进主数据。传统广播的主数据和 Scan Response 各有 31 字节预算。要把名称也加进去时，数清名称、公司 ID、字段头和 Tx Power 各占多少，可连接广告还要给系统加的 Flags 留位置。信息放不下时，可用 `startAdvertising(settings, primary, scanResponse, callback)` 把次要字段放到 Scan Response。扫描端需要主动扫描并收到这条响应，才能看到这一部分。

`AdvertiseSettings.Builder.setTimeout(ms)` 规定传统广播时长，0 表示无超时。启动与失败由回调告知，停止要传入原实例。失败时查 `ADVERTISE_FAILED_DATA_TOO_LARGE`、`TOO_MANY_ADVERTISERS`、`FEATURE_UNSUPPORTED` 等常量。失败时记录实际参数和每段 AD 字节预算。

## 传统广播装不下时再看扩展广播

如果业务资料比前面的 31 字节更多，先问两端手机支不支持扩展广播。需要另一端按周期接收同步数据时，再查周期广播能力。API 26 起，用 `isLeExtendedAdvertisingSupported()`、`isLePeriodicAdvertisingSupported()` 和 `getLeMaximumAdvertisingDataLength()` 查询能力。`AdvertisingSetParameters.Builder` 选择传统/扩展、可连接性、可扫描性、PHY 和间隔。扩展模式里可连接和可扫描不能同时开启。周期广播也受参数组合限制。

```kotlin
val parameters = AdvertisingSetParameters.Builder()
    .setLegacyMode(false)
    .setConnectable(false)
    .setScannable(false)
    .setInterval(AdvertisingSetParameters.INTERVAL_MEDIUM)
    .build()
advertiser.startAdvertisingSet(parameters, primary, null, null, null, setCallback)
```

这里两个周期广播参数为 `null`。周期广播需提供 `PeriodicAdvertisingParameters` 和数据，并观察回调。带 `duration` 的重载使用 10 ms 单位，与传统广播的 `setTimeout` 不同。`maxExtendedAdvertisingEvents = 0` 表示无事件数上限。部分重载可指定 `Handler`。

从 `onAdvertisingSetStarted(set, txPower, status)` 收到成功的 `AdvertisingSet` 后，可用 `setAdvertisingData`、`setScanResponseData` 或周期广播方法更新数据，分别等对应回调。支持动态更新时可减少反复停启。结束时 `stopAdvertisingSet(setCallback)`，观察 `onAdvertisingSetStopped`，清理句柄。

## 一句话总结

**发广播前先确定别人要靠什么找你，再按这一段数据的大小和用途选广播方式。**

## 面试题

1. 为什么可连接广播要等 `onServiceAdded()` 成功再启动？
2. 传统广播放了 UUID 后再放名字报太大，从哪里检查？

### 参考答案

1. 扫描端可能一收到广播就连接并发现服务。提前完成属性表注册，能让它连上时看到正确的服务。
2. 分别计算主数据和 Scan Response 的 31 字节预算，计入 AD 头、UUID 长度、名字和系统 Flags。先保留对端实际用于匹配的字段。

[BluetoothLeAdvertiser](https://developer.android.com/reference/android/bluetooth/le/BluetoothLeAdvertiser) · [AdvertisingSetParameters.Builder](https://developer.android.com/reference/android/bluetooth/le/AdvertisingSetParameters.Builder) · [AdvertisingSetCallback](https://developer.android.com/reference/android/bluetooth/le/AdvertisingSetCallback)
