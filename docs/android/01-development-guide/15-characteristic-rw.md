---
title: Characteristic 与 Descriptor 读写
order: 160
summary: 写入有三站，手机先受理，蓝牙再报告写入结果，设备最后告诉你事情办完没有。
tags: SDK,BLE
updated: 2026-11-19
---

# 第 15 章　Characteristic 与 Descriptor 读写

上一章找到了温度特征和命令特征。现在接两个按钮。「刷新」让手机问当前温度，「开始测量」让手机往命令特征发一段设备能识别的字节。

特征值像设备接口里的数据，读温度或写命令都通过它。描述符挂在特征下面，通常放配置和补充说明。比如要告诉设备这台手机想接收上报，要写订阅描述符，下一章会实际做一次。

以开始测量为例，代码调用写方法后，Android 先给一个立即结果，告诉 App 有没有接下请求。蓝牙写操作结束后再回一个结果。设备真正测完时，应用还要等设备协议约定的「测量完成」。页面可以按这几个状态显示进度。

## 找到对应方法，把请求交给 Android

现代目标版本对下列 I/O 方法要求 `BLUETOOTH_CONNECT`。在 API 33 及以上传入显式数据，旧系统才通过属性对象存放值。读取的发起方法沿用原签名，变化出现在回调端。

| 方法 | 引入 / 弃用 | 立即结果 | 完成事件 |
| --- | --- | --- | --- |
| `readCharacteristic(characteristic)` | 18 | `boolean`，是否开始 | `onCharacteristicRead(gatt, characteristic, value, status)`（33+），旧回调无 `value`。 |
| `readDescriptor(descriptor)` | 18 | `boolean`，是否开始 | `onDescriptorRead(gatt, descriptor, status, value)`（33+），旧回调无 `value`。 |
| `writeCharacteristic(characteristic, byte[], writeType)` | 33 | `BluetoothStatusCodes` | `onCharacteristicWrite(gatt, characteristic, status)`。 |
| `writeCharacteristic(characteristic)` | 18 / 33 | `boolean` | 同上，发起前设置旧对象的值和写类型。 |
| `writeDescriptor(descriptor, byte[])` | 33 | `BluetoothStatusCodes` | `onDescriptorWrite(gatt, descriptor, status)`。 |
| `writeDescriptor(descriptor)` | 18 / 33 | `boolean` | 同上，发起前设置旧对象的值。 |

注意新版 **Characteristic read 的 `value` 在 `status` 之前，Descriptor read 的 `value` 在 `status` 之后**。回调成功才消费数据。API 32 及以下在旧回调里立即复制 `characteristic.value` 或 `descriptor.value`。实现新旧签名时转交给同一个处理入口，避免调用父类兼容桥后重复处理。

```kotlin
@Suppress("DEPRECATION")
fun startWrite(
    gatt: BluetoothGatt,
    characteristic: BluetoothGattCharacteristic,
    payload: ByteArray,
    writeType: Int
): Boolean {
    val bytes = payload.copyOf()
    return if (Build.VERSION.SDK_INT >= 33) {
        gatt.writeCharacteristic(characteristic, bytes, writeType) ==
            BluetoothStatusCodes.SUCCESS
    } else {
        characteristic.writeType = writeType
        characteristic.setValue(bytes) && gatt.writeCharacteristic(characteristic)
    }
}
```

上面把立即结果整理成一个布尔值。App 显示「正在发送」之前先看它有没有受理。产品日志里保留 Android 返回的原始错误，例如 `ERROR_GATT_WRITE_REQUEST_BUSY`、`ERROR_GATT_WRITE_NOT_ALLOWED` 或权限错误。写之前检查目标、Properties、写类型和值的长度。立即失败就结束本轮等待，受理后再等匹配这次操作的 `onCharacteristicWrite`。

## 用户按刷新，再读出一份当前数据

下面是一个读取特征的回调片段。读操作仍由会话持有。发起读时先记录正在等待的特征，再调用 `gatt.readCharacteristic(characteristic)`。返回 `false` 时立即清理等待状态。`handleRead` 核对回调归属并在 `GATT_SUCCESS` 时交付字节。

```kotlin
override fun onCharacteristicRead(
    gatt: BluetoothGatt, ch: BluetoothGattCharacteristic, value: ByteArray, status: Int
) {
    handleRead(gatt, ch, status, value.copyOf())
}

@Suppress("DEPRECATION")
override fun onCharacteristicRead(
    gatt: BluetoothGatt, ch: BluetoothGattCharacteristic, status: Int
) {
    if (Build.VERSION.SDK_INT < 33) {
        handleRead(gatt, ch, status, ch.value?.copyOf())
    }
}
```

读描述符时以 `characteristic.getDescriptor(descriptorUuid)` 获取对象，再调用 `readDescriptor(descriptor)`。等待 `onDescriptorRead`，用回调提供的 descriptor 与在途对象匹配。描述符是否有可读值由设备属性表决定。

## 写命令时，设备要不要回一次

设备需要响应这次属性写入时，选 `WRITE_TYPE_DEFAULT`，对应特征的 `PROPERTY_WRITE`。抓包里，手机发 ATT Write Request，设备成功处理属性写后回 Write Response。短写成功回调说明属性写这一步已经完成。测量完成则由设备应用另发业务结果。

`WRITE_TYPE_NO_RESPONSE` 与 `PROPERTY_WRITE_NO_RESPONSE` 搭配，走 ATT Write Command。Android 仍提供写回调供本地流程推进。对端不会为该 ATT 命令送回写响应，以业务 ACK 确认实际消费。先从每次一个待完成操作开始测吞吐，再考虑协议层窗口。

`WRITE_TYPE_SIGNED` 对应 `PROPERTY_SIGNED_WRITE`，涉及 ATT Signed Write 和对端支持。产品协议明确要求并验证签名条件时才选用。

## Reliable Write

`beginReliableWrite()`、逐笔 `writeCharacteristic(...)`、`executeReliableWrite()` 与 `onReliableWriteCompleted` 组成事务。写入在对端准备队列暂存，按官方约定用可靠写过程的特征写回调验证远端回显。能取得并验证回显后才提交，值或状态异常调用 `abortReliableWrite()`。测试时抓 Prepare/Execute Write，应答和偏移由 Server 配合。这个事务有明确的属性写用途，设备上的业务操作与原子性还要看设备协议。

## 等这次读写结束，再取队列里的下一条

普通应用中，每个 GATT 客户端只保留一个等待中的属性请求，是最容易验证的起点。写期间收到通知，通知走独立入口。应用可以给队列命令分配 `operationId` 来串日志，平台回调只提供 GATT、属性对象、数据和状态等约定字段。若同一个 GATT 上的写超时，立刻用同一特征发送下一条写，有机会把迟到的旧回调错给新请求。无法确认旧请求是否结束时，关闭这次会话，下一次用新句柄隔离。

## 一句话总结

**写入有三站，手机先受理，蓝牙再报告写入结果，设备最后告诉你事情办完没有。**

## 面试题

1. API 33 的新版 `writeCharacteristic` 返回 `SUCCESS`，可以显示「测量完成」吗？
2. `WRITE_TYPE_NO_RESPONSE` 时，`onCharacteristicWrite` 成功能证明对端收到了吗？
3. 为什么写超时后不宜立刻对同一 GATT 和同一特征发下一条写？

### 参考答案

1. 这个值说明系统接受了写入。还要等 GATT 写回调，以及设备的测量结果。
2. 它可以用于推进本地发送流程。对端消费数据用设备业务确认或读回结果来证明。
3. 回调里没有应用生成的 `operationId`，迟到的旧回调可能与新写无法区分。无法确认旧操作已结束时，用新的 GATT 会话隔离。

[BluetoothGatt](https://developer.android.com/reference/android/bluetooth/BluetoothGatt) · [BluetoothGattCallback](https://developer.android.com/reference/android/bluetooth/BluetoothGattCallback) · [BluetoothStatusCodes](https://developer.android.com/reference/android/bluetooth/BluetoothStatusCodes)
