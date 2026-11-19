---
title: 附录 B Android 蓝牙 API 总索引
order: 330
summary: 用 [方法名索引](API参考/按方法名查阅.md) 查 writeCharacteristic、close 等名称。用 […
tags: SDK,附录
updated: 2026-11-19
---

# 附录 B　Android 蓝牙 API 总索引

用 方法名索引 查 `writeCharacteristic`、`close` 等名称。用 类名索引 查 `BluetoothGatt`、`ScanFilter.Builder` 等类。点到签名表后，可以看到同名重载、引入与弃用版本和官方类链接。

签名表以 **Android SDK Platform 37.2 r02** 为基线，纳入 `android.bluetooth`、`android.bluetooth.le`、`android.companion` 主包及 `android.ranging` 相关公开 SDK 类。当前收录 164 个类与接口、1,029 条方法和构造器。范围包括公开 SDK 的传统、低功耗、系统 Profile 等接口，部分方法仍有系统权限、设备功能、关联资格或调用角色限制。隐藏 API、厂商扩展和 Jetpack 封装由对应资料维护。高频接口在正文中有中文调用说明，签名表提供其余公开接口的定位入口。

## 按任务查调用顺序

| 我正在找 | 原生方法或回调 | 正文 |
| --- | --- | --- |
| 适配器、开关、设备句柄 | `getAdapter`、`isEnabled`、`getState`、`getRemoteDevice`、`getRemoteLeDevice`、`ACTION_REQUEST_ENABLE` | [第 5 章](#android/development-guide/adapter-state) |
| 经典发现、配对、SDP | `startDiscovery`、`cancelDiscovery`、`getBondedDevices`、`createBond`、`getUuids`、`fetchUuidsWithSdp` | [第 6 章](#android/development-guide/discovery-pairing) |
| RFCOMM 和 LE CoC | `listenUsingRfcommWithServiceRecord`、`createRfcommSocketToServiceRecord`、`accept`、`connect`、`close`、`listenUsingL2capChannel`、`createL2capChannel` | [第 7 章](#android/development-guide/rfcomm-socket) |
| 系统 Profile | `getProfileProxy`、`closeProfileProxy`、`getConnectedDevices`、`getConnectionState` | [第 8 章](#android/development-guide/classic-profiles) |
| 读广播和扫描元数据 | `getScanRecord`、`getServiceData`、`getManufacturerSpecificData`、`getRssi`、`getTimestampNanos` | [第 9 章](#android/development-guide/advertising-data) |
| 扫描、批量与失败 | `startScan`、`stopScan`、`flushPendingScanResults`、`onScanResult`、`onBatchScanResults`、`onScanFailed` | [第 10 章](#android/development-guide/scanning) |
| 过滤、熄屏与 PendingIntent | `setServiceUuid`、`setServiceData`、`setManufacturerData`、`setAdvertisingDataType`、扫描的 `PendingIntent` 重载 | [第 11 章](#android/development-guide/scan-filter) |
| 发广播与更新 | `startAdvertising`、`stopAdvertising`、`startAdvertisingSet`、`stopAdvertisingSet`、`setAdvertisingData` | [第 12 章](#android/development-guide/advertiser) |
| 连接与断开 | `connectGatt` 各重载、`onConnectionStateChange`、`connect`、`disconnect`、`close` | [第 13 章](#android/development-guide/connection-lifecycle) |
| GATT 发现和缓存变化 | `discoverServices`、`onServicesDiscovered`、`getService`、`getCharacteristic`、`getDescriptor`、`onServiceChanged` | [第 14 章](#android/development-guide/service-discovery) |
| GATT 读写与可靠写 | `readCharacteristic`、`writeCharacteristic`、`readDescriptor`、`writeDescriptor`、`beginReliableWrite`、`executeReliableWrite`、`abortReliableWrite` | [第 15 章](#android/development-guide/characteristic-rw) |
| CCCD 与通知 | `setCharacteristicNotification`、`writeDescriptor`、`onDescriptorWrite`、`onCharacteristicChanged` | [第 16 章](#android/development-guide/notify-cccd) |
| 链路参数 | `requestMtu`、`setPreferredPhy`、`readPhy`、`requestConnectionPriority`、`requestSubrateMode`、`onConnectionUpdated` | [第 17 章](#android/development-guide/mtu-phy-dle) |
| GATT Server | `openGattServer`、`addService`、`sendResponse`、`notifyCharacteristicChanged`、`onNotificationSent` | [第 18 章](#android/development-guide/gatt-server) |
| Bond 与安全 | `createBond`、`getBondState`、`removeBond`、`ACTION_ENCRYPTION_CHANGE` | [第 19 章](#android/development-guide/pairing-security) |
| 伴生设备与后台 | `associate`、`getMyAssociations`、`disassociate`、`startObservingDevicePresence` | [第 24 章](#android/development-guide/background-service) |
| 音频与测距 | `isLeAudioSupported`、`setCommunicationDevice`、`registerCapabilitiesCallback`、`createRangingSession` | [第 30 章](#android/development-guide/le-audio-ranging) |

## 按包和功能查全部签名

| 参考页 | 内容 |
| --- | --- |
| 适配器、设备与套接字 | Adapter、Device、Manager、Socket、SocketSettings、StatusCodes |
| GATT | Client、Server、服务和属性对象、回调、连接设置 |
| 扫描与广播 | Scanner、Advertiser、过滤器、设置、广播集及回调 |
| Profile、音频与其他 | A2DP、Headset、HID Device、LE Audio 等系统角色 |
| 伴生设备 | CDM、关联、设备存在、过滤器和 CompanionService |
| 测距 | RangingManager、会话、配置、BLE RSSI 和 Channel Sounding 等 |

查到签名后，再确定当前代码需要使用哪个重载。例如 `BluetoothGatt.writeCharacteristic` 在旧系统返回布尔值，API 33 的三参数重载返回 `int`。回调里的 `status` 属于 [另一组状态码](#android/development-guide/appendix-c-codes)。权限列中的「条件」意味着这个方法的不同模式可能需要不同权限，调用时查 [权限章](#android/development-guide/permissions) 和官方方法说明。

[官方来源与索引维护方法](#android/development-guide/appendix-d-refs)
