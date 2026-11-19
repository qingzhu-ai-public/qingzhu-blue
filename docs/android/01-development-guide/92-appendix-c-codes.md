---
title: 附录 C 状态码速查
order: 340
summary: 记录错误时把 API/回调名、十进制、十六进制、阶段和目标属性 一起写下。同一个值可在不同子系统重复出现，例如 5 在 AT…
tags: SDK,附录
updated: 2026-11-19
---

# 附录 C　状态码速查

记录错误时把 **API/回调名、十进制、十六进制、阶段和目标属性** 一起写下。同一个值可在不同子系统重复出现，例如 5 在 ATT 是认证不足，在扫描回调是硬件资源不足。

## 立即返回值

API 33+ 的 `BluetoothGatt.writeCharacteristic(ch, value, type)`、`writeDescriptor(descriptor, value)`、`BluetoothGattServer.notifyCharacteristicChanged(device, ch, confirm, value)` 返回 `BluetoothStatusCodes`。实际支持的错误以所用方法的参考为准。

| 值 | 常量 | 排查 |
| --- | --- | --- |
| 0 | `SUCCESS` | 已接受调用，随后等待相应 GATT 回调。 |
| 1 | `ERROR_BLUETOOTH_NOT_ENABLED` | 重新读取适配器状态，处理关闭或关闭中的情况。 |
| 6 | `ERROR_MISSING_BLUETOOTH_CONNECT_PERMISSION` | 检查目标版本、清单和当前授权，也处理权限异常。 |
| 200 | `ERROR_GATT_WRITE_NOT_ALLOWED` | 检查目标属性、操作或写类型。 |
| 201 | `ERROR_GATT_WRITE_REQUEST_BUSY` | 查同一客户端上是否已有在途请求。 |

[BluetoothStatusCodes](https://developer.android.com/reference/android/bluetooth/BluetoothStatusCodes)

## 扫描与广播

| 值 | `ScanCallback.onScanFailed` | `AdvertiseCallback.onStartFailure` |
| ---: | --- | --- |
| 1 | 同一 callback 已启动 | 广播数据太长 |
| 2 | 应用注册失败 | 广播实例过多 |
| 3 | 内部错误 | 同一 callback 已开始广播 |
| 4 | 功能不支持 | 内部错误 |
| 5 | 硬件资源不足（公开常量 API 33） | 功能不支持 |
| 6 | 扫描提交太频繁（公开常量 API 33） | 按具体回调的文档解析 |

扫描的 PendingIntent 重载还可能通过返回值或 extras 报错。广播集回调使用自己的状态码常量。不要以某个数值推断是客户端还是外设问题。

[ScanCallback](https://developer.android.com/reference/android/bluetooth/le/ScanCallback) · [AdvertiseCallback](https://developer.android.com/reference/android/bluetooth/le/AdvertiseCallback) · [AdvertisingSetCallback](https://developer.android.com/reference/android/bluetooth/le/AdvertisingSetCallback)

## GATT 回调与 ATT

| 值 | 含义 | 排查 |
| --- | --- | --- |
| 0 / `0x00` | `GATT_SUCCESS` | 确认是哪项操作成功。 |
| 2 / `0x02` | Read Not Permitted | 检查特征能力、属性句柄和设备表。 |
| 3 / `0x03` | Write Not Permitted | 检查属性可写性、目标描述符和写类型。 |
| 4 / `0x04` | Invalid PDU（ATT） | 检查协议报文结构及抓包。 |
| 5 / `0x05` | Insufficient Authentication | 对照配对与属性认证要求。 |
| 7 / `0x07` | Invalid Offset | 检查长读、准备写的偏移和有效长度。 |
| 8 / `0x08` | Insufficient Authorization（ATT） | 检查设备授权条件。 |
| 12 / `0x0C` | Encryption Key Size Too Short | 核对安全级别与密钥长度。 |
| 13 / `0x0D` | Invalid Attribute Value Length | 核对属性长度、MTU 与对端协议。 |
| 15 / `0x0F` | Insufficient Encryption | 检查加密是否成功。 |
| 147 / `0x93` | `BluetoothGatt.GATT_CONNECTION_TIMEOUT`（公开常量 API 35） | 找连接阶段和系统事件。 |
| 257 / `0x101` | `BluetoothGatt.GATT_FAILURE` | 通用失败，需结合阶段。 |

[BluetoothGatt](https://developer.android.com/reference/android/bluetooth/BluetoothGatt) · [Bluetooth Core 6.2 ATT](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/attribute-protocol--att-.html)

## AOSP 内部值与 HCI 断开原因

同一 AOSP 源码版本中，129（`0x81`）为 `GATT_INTERNAL_ERROR`，132（`0x84`）为 `GATT_BUSY`，133（`0x85`）为 `GATT_ERROR`，137（`0x89`）为 `GATT_AUTH_FAIL`。这些源码符号帮助读实现和日志，具体回调映射受系统版本、路径和厂商实现影响。

在 **HCI 断开原因** 里，8（`0x08`）是连接超时，19（`0x13`）是对端用户终止连接，22（`0x16`）是本地主机终止连接。把这组原因与同值的 ATT 错误分开记录。遇到未知状态保留原值，从 [故障章](#android/development-guide/gatt-errors) 选下一项证据。

[AOSP gatt_api.h](https://android.googlesource.com/platform/packages/modules/Bluetooth/+/9afa02435692ca52952fe7158fcc162e05cff0fc/system/stack/include/gatt_api.h) · [AOSP HCI 状态定义](https://android.googlesource.com/platform/packages/modules/Bluetooth/+/cdb1c6dca4/system/stack/include/hci_error_code.h)
