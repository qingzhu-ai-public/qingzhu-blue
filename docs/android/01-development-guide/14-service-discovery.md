---
title: 服务发现与 GATT 对象模型
order: 150
summary: 连上像拨通了电话，做一次服务发现才知道对方能提供哪些功能。
tags: SDK,BLE
updated: 2026-11-19
---

# 第 14 章　服务发现与 GATT 对象模型

温度计已经连上，接下来想读温度。你拿设备文档给的 UUID 去找，却发现 `getService(uuid)` 返回空。连接只是让手机和设备能够通信。手机还需要问一次设备「你有哪些功能」，把服务和特征找回来。这个过程叫**服务发现**。

在连接成功回调里，用这次会话的 `gatt.discoverServices()` 发起查询。`false` 表示调用没有启动发现。返回 `true` 后等同一个 GATT 的 `onServicesDiscovered`。回调报告 `GATT_SUCCESS` 时，先按服务 UUID 找到一组功能，再按特征 UUID 找到其中要读写的一项。需要订阅时，最后在特征下面找描述符。

如果回调已经成功，却找不到目标，先打印这次发现的所有服务和特征 UUID，对照固件文档。

| 方法 | 起始版本 | 用法与完成信号 |
| --- | --- | --- |
| `BluetoothGatt.discoverServices()` | 18 | 布尔值表示是否开始发现。等待 `onServicesDiscovered(gatt, status)`。 |
| `getServices()` | 18 | 读取目前已知的服务列表，发现完成后遍历。 |
| `getService(uuid)` | 18 | 命中第一个匹配实例，未找到返回 `null`。 |
| `BluetoothGattService.getCharacteristics()` / `getCharacteristic(uuid)` | 18 | 查列表或取第一个匹配特征。 |
| `BluetoothGattService.getIncludedServices()` | 18 | 读取包含服务。 |
| `BluetoothGattCharacteristic.getDescriptors()` / `getDescriptor(uuid)` | 18 | 查描述符列表或按 UUID 查询。 |
| `onServiceChanged(gatt)` | 31 | Server 的数据库已变化，旧服务对象需要重新发现和定位。 |

```kotlin
override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
    if (gatt !== activeGatt) return
    if (status != BluetoothGatt.GATT_SUCCESS) {
        failSession("discovery status=$status")
        return
    }
    val service = gatt.getService(serviceUuid)
    val write = service?.getCharacteristic(writeUuid)
    if (write == null || write.properties and
        BluetoothGattCharacteristic.PROPERTY_WRITE == 0
    ) {
        failSession("required WRITE characteristic unavailable")
        return
    }
    prepareProtocol(gatt, write)
}
```

上例找的是应用要写的特征，比如用来发「开始测量」命令。代码根据服务和特征 UUID 找到对象，再检查它有没有写入能力。如果设备用同一个 UUID 提供了多份特征，就枚举列表，按服务、实例 ID 和协议给出的区分字段选对一份。实例 ID 这个编号适合在本次发现里区分对象。跨会话保存配置时用设备协议给定的标识。

## 找到了特征，再看设备允许你怎么用

先看设备声明这个特征会做什么。`getProperties()` 返回的能力位可以用来检查可读、可写或可通知。再看设备在什么条件下准许操作。`getPermissions()` 在本地 Server 建表时用来声明这些要求。作为客户端，远端是否要求链路加密、认证或授权，要结合实际 ATT 结果。

固件升级后发现到旧表时，先查设备的 GATT Service Changed 行为、是否保留绑定、服务 UUID 是否还存在，以及另一台手机能否发现新表。收到 `onServiceChanged` 时暂停业务，清掉旧特征和订阅引用，再重新发现。旧操作若仍在飞，先等明确的终态，或关闭旧会话后重连。AOSP 有用于系统内部的缓存接口，应用的兼容路径应围绕公开的服务变化、发现和生命周期。

## 一句话总结

**连上像拨通了电话，做一次服务发现才知道对方能提供哪些功能。**

## 面试题

1. 什么时候可以开始用 `getService(uuid)` 找本次连接的服务？
2. 固件更新后收到 `onServiceChanged`，之前保存的特征怎样处理？

### 参考答案

1. 当前 GATT 调用 `discoverServices()` 后，等 `onServicesDiscovered` 成功，再从本次发现结果取服务。
2. 暂停操作，等当前请求收口或关闭旧会话，丢弃旧属性和订阅引用。重新发现并定位目标，按需要恢复订阅。

[BluetoothGatt](https://developer.android.com/reference/android/bluetooth/BluetoothGatt) · [BluetoothGattService](https://developer.android.com/reference/android/bluetooth/BluetoothGattService) · [BluetoothGattCallback](https://developer.android.com/reference/android/bluetooth/BluetoothGattCallback)
