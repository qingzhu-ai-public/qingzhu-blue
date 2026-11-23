---
title: HarmonyOS 蓝牙 API 速查
slug: api-reference
order: 130
---

# HarmonyOS 蓝牙 API 速查

示例以 HarmonyOS NEXT API 12 为基线，导入 `@kit.ConnectivityKit` 的 `ble`、`access`、`constant`。按动作查看方法和结果，使用更新的 SDK 时核对具体重载和可用版本。

| 操作 | 调用 | 结果或下一步 |
| --- | --- | --- |
| 请求蓝牙授权 | `abilityAccessCtrl.createAtManager().requestPermissionsFromUser(...)` | 等 Promise，再检查 authResults |
| 检查开关 | `access.getState()` | 等于 STATE_ON 后开始实验 |
| 监听和解除扫描结果 | `ble.on('BLEDeviceFind', handler)` / `ble.off(...)` | 回调收到 ScanResult 数组 |
| 开始和停止扫描 | `ble.startBLEScan(filters, options?)` / `ble.stopBLEScan()` | 先注册事件，再启动 |
| 创建客户端 | `ble.createGattClientDevice(deviceId)` | 返回 GattClientDevice |
| 连接 | `client.connect()` | 等 BLEConnectionStateChange 的 STATE_CONNECTED |
| 发现服务 | `client.getServices()` | Promise 返回服务、特征和描述符 |
| 有响应写 | `client.writeCharacteristicValue(characteristic, ble.GattWriteType.WRITE)` | 等 Promise 结果，实际业务结果按协议检查 |
| 读特征 | `client.readCharacteristicValue(characteristic)` | 返回 BLECharacteristic，从 characteristicValue 取回包 |
| 读写描述符 | `readDescriptorValue` / `writeDescriptorValue` | 使用该特征下的 BLEDescriptor |
| 开关 Notify 或 Indicate | `setCharacteristicChangeNotification` / `setCharacteristicChangeIndication` | 数据在 BLECharacteristicChange |
| 释放客户端 | `disconnect()` / `close()` | 解绑事件并清理会话 |
| 开外设 | `ble.createGattServer()` / `server.addService(service)` | 在广播前准备服务和特征 |
| 启动和停止单路广播 | `ble.startAdvertising(setting, data)` / `ble.stopAdvertising()` | 实战使用不带 ID 的配对重载 |
| 回应读写 | `server.sendResponse(response)` | 从 characteristicRead / characteristicWrite 拿到请求标识 |
| 主动发送更新 | `server.notifyCharacteristicChanged(deviceId, value)` | confirm 选择 Notify 或 Indicate |

[华为 BLE API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-bluetooth-ble/) · [华为开关状态 API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-bluetooth-access/) · [正文目录](#harmonyos/development-guide/overview)
