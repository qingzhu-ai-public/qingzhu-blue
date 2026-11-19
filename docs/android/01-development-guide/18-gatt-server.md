---
title: GATT Server 与外设角色
order: 190
summary: 当 GATT Server 就是把设备接口摆出来，按请求答复，再把数据发给订阅了的客户端。
tags: SDK,BLE
updated: 2026-11-19
---

# 第 18 章　GATT Server 与外设角色

现在让另一台 Android 手机当实验外设。第一台写入 `android-ble-echo`，第二台收到后把同样的字节通知回去。屏幕上看到一模一样的值，就能验证两边确实走通了。

前面一直是手机向设备读写。现在第二台手机要提供别人能读写的接口，这一端叫 **GATT Server**。它先建好服务、特征和订阅用的 CCCD，再让另一台手机扫到自己。连接以后，客户端发来读写请求，由这台手机按请求回答。客户端已经订阅时，Server 才按协议把回声发给它。

## 先把读写入口准备好，再让别人连

`BluetoothManager.openGattServer(context, callback)`、`addService(service)` 和基本回调从 API 18 提供。BLE 广播另需 API 21 及控制器支持。现代目标应用打开与操作 GATT Server 需要 `BLUETOOTH_CONNECT`，广播需要 `BLUETOOTH_ADVERTISE`。

```kotlin
val server = manager.openGattServer(context, serverCallback) ?: return
val service = BluetoothGattService(serviceUuid, BluetoothGattService.SERVICE_TYPE_PRIMARY)
val echo = BluetoothGattCharacteristic(
    echoUuid,
    BluetoothGattCharacteristic.PROPERTY_READ or
        BluetoothGattCharacteristic.PROPERTY_WRITE or
        BluetoothGattCharacteristic.PROPERTY_NOTIFY,
    BluetoothGattCharacteristic.PERMISSION_READ or
        BluetoothGattCharacteristic.PERMISSION_WRITE
)
echo.addDescriptor(BluetoothGattDescriptor(
    cccdUuid,
    BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
))
service.addCharacteristic(echo)
if (!server.addService(service)) server.close()
// onServiceAdded 成功后再开始广播。
```

`addService` 返回 `true` 后，等这项服务的 `onServiceAdded(status, service)` 成功，再开始广播或注册下一项服务。接下来由外设会话保存 Server、当前值和订阅状态。用 `getServices()` 查看本机服务，通过 `removeService(service)` 或 `clearServices()` 管理属性表。改表时考虑已连接手机的发现结果和订阅。实验结束时停止广播，需要时先 `cancelConnection(device)`，再清理会话并 `close()`。

## 客户端一写入，外设这边收到什么

第一台手机写入 `android-ble-echo`，第二台会收到特征写请求回调。回调带了发来请求的设备、请求编号和字节。外设 App 检查读写权限约定、长度和偏移。需要应答时，用该回调给出的设备和编号调用 `sendResponse(device, requestId, status, offset, value)`。检查应答是否提交成功，拒绝时用对应的 GATT/ATT 错误码。

| 回调 | Server 需要做什么 |
| --- | --- |
| `onCharacteristicReadRequest(device, id, offset, ch)` | 检查特征与 offset，返回从该偏移开始的有效值。非法偏移响应 `GATT_INVALID_OFFSET`。 |
| `onDescriptorReadRequest(device, id, offset, descriptor)` | CCCD 要返回该客户端的当前配置，按 offset 应答。 |
| `onCharacteristicWriteRequest(..., preparedWrite, responseNeeded, offset, value)` | 普通写先校验再更新。需要响应时发送结果，无响应写只处理数据。 |
| `onDescriptorWriteRequest(..., preparedWrite, responseNeeded, offset, value)` | 检查 CCCD 值是否为支持的两字节配置。验证成功后更新该客户端的订阅。 |
| `onExecuteWrite(device, id, execute)` | 对已准备操作统一提交或撤销，然后应答。支持 prepared write 时暂存分片并在提交时验证完整事务。简单实验可以明确拒绝 prepared write。 |
| `onConnectionStateChange(device, status, newState)` | 维护每个连接的状态，清除暂存写、待发通知等会话数据。需跨连接保留的绑定配置按协议单独建模。 |
| `onMtuChanged(device, mtu)` | 按客户端保存已知 MTU，用它限制回应与通知大小。 |

## 把回声发给订阅的那台手机

发通知前确认这个设备已订阅该特征。`notifyCharacteristicChanged(device, characteristic, confirm, value)` 自 API 33 起可用，返回 `BluetoothStatusCodes`。旧重载先设置特征值，再调用 `notifyCharacteristicChanged(device, characteristic, confirm)`，其返回布尔值。旧对象共享时在同一个串行发送流程内设置值和提交。

`confirm = true` 走 Indication，`false` 走 Notification。发送下一条前等待 `onNotificationSent(device, status)`，并处理断连与超时。要支持多个客户端，需要把待发项和订阅状态以连接及属性分开保存。实验只用一个客户端时，可以把边界写清楚，先确认字节从客户端写入并从通知读回。

## 一句话总结

**当 GATT Server 就是把设备接口摆出来，按请求答复，再把数据发给订阅了的客户端。**

## 面试题

1. 服务注册后何时可以开始可连接广播？
2. 收到一个需要应答的写请求，怎么把成功结果送回正确的客户端？
3. Server 发送 Notify 和 Indicate 时，`notifyCharacteristicChanged` 的参数区别在哪儿？

### 参考答案

1. 等当前服务的 `onServiceAdded` 报告成功，确保客户端接入时能发现属性表。
2. 校验请求后，用回调里的 `device` 和 `requestId` 调 `sendResponse`，用对应的状态和偏移应答。
3. `confirm=false` 发 Notify，`confirm=true` 发 Indicate。发之前还要确认该客户端订阅了相应方式。

[BluetoothManager](https://developer.android.com/reference/android/bluetooth/BluetoothManager) · [BluetoothGattServer](https://developer.android.com/reference/android/bluetooth/BluetoothGattServer) · [BluetoothGattServerCallback](https://developer.android.com/reference/android/bluetooth/BluetoothGattServerCallback)
