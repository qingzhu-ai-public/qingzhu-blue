---
title: Android BLE 总览
order: 10
summary: 平台能力边界、开发准备，以及一条最小可跑链路
tags: 必读, 首篇
updated: 2026-09-22
---

# Android BLE 总览

这一篇不谈细节，只回答三件事：Android 的蓝牙到底给了你什么、从零到跑通要准备什么、一条完整链路长什么样。后面的每一篇都在拆这里的某一段。

## Android 上有两套蓝牙栈

新手最容易踩的第一个坑，是把 Classic 和 BLE 当成同一套 API 的两档强度。它们从协议到 API 都是分开的：

| 维度 | Classic（BR/EDR） | BLE（低功耗） |
|---|---|---|
| 典型用途 | 音频、串口透传、HID | 手环、传感器、配网、OTA |
| 发现方式 | `startDiscovery()` 广播发现 | `BluetoothLeScanner` 扫描广播包 |
| 连接模型 | Socket（RFCOMM / L2CAP） | GATT Client / Server |
| 数据通道 | 流式 Socket | Characteristic 读写 + Notify |
| 典型带宽 | 数百 kbps ~ 2 Mbps | 几 kbps ~ 几十 kbps |

**结论**：如果你的设备是「连上之后当成一根串口用」，那是 Classic；如果是「读几个值、写几条指令、偶尔推个通知」，那是 BLE。两套不能混用，`BluetoothDevice` 这个类只是它们共用的一个外壳。

> 只做 BLE 的话，`android.bluetooth.le` 包才是你要看的全部。

## 最小可跑链路

BLE 的工作流是固定的五步，跳步一定出问题：

```
扫描设备  →  建立连接  →  发现服务  →  订阅通知  →  读写数据
  ↑                                                      │
  └──────────────  断连后按策略重连  ←───────────────────┘
```

对应到代码骨架：

```kotlin
// 1. 扫描：必须有 ScanCallback，超时自己收
val scanner = adapter.bluetoothLeScanner
scanner.startScan(null, ScanSettings.Builder()
    .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
    .build(), scanCallback)

// 2. 连接：拿 BluetoothDevice，注册 GATT 回调
val gatt = device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)

// 3. 服务发现：连接成功后才能拿到 services
override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
    if (newState == BluetoothProfile.STATE_CONNECTED) g.discoverServices()
}

// 4. 订阅 Notify：先写 CCCD，再等 onDescriptorWrite
override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
    val ch = g.getService(SERVICE_UUID).getCharacteristic(NOTIFY_UUID)
    g.setCharacteristicNotification(ch, true)
    ch.getDescriptor(CCCD_UUID).value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
    g.writeDescriptor(ch.getDescriptor(CCCD_UUID))
}

// 5. 读写在 onDescriptorWrite 之后才开始，别提前
```

**第 4 步是最容易写错的**：`setCharacteristicNotification()` 只是让本地栈把回调转给你，真正让设备开始推送的是写 CCCD 描述符。写完必须等 `onDescriptorWrite` 回调，在那之前发读写指令十有八九返回 `GATT_BUSY`。

## 开发准备

| 项目 | 要求 |
|---|---|
| 最低 API | 18（BLE 引入）；工程实践建议 21+ |
| 编译 SDK | 33+（Android 12 起权限模型换了，见下一篇） |
| 真机 | **必须**。模拟器没有蓝牙适配器 |
| 权限 | `BLUETOOTH` + `BLUETOOTH_ADMIN`；扫描还需要定位权限 |
| 设备侧 | 一个能广播、能被连接的外设（开发板/成品都行） |

蓝牙相关的坑有个共性：**几乎全部只在真机上暴露**。模拟器跑不出 `GATT 133`，也复现不了 Android 各厂商 ROM 的后台限制。所以从第一天起就用真机。

## 三种角色，别混着理解

BLE 的话题里会同时出现三种身份。混着用，沟通和排错都会对不上号。

### Central / Peripheral —— 谁主动

Central 是发起扫描、发起连接的一方，手机通常扮演这个角色；Peripheral 是被连接的一方，也就是你的硬件产品。这一层由 GAP 定义。

### GATT Client / Server —— 谁发请求

GATT 交互里，Client 发请求，Server 存数据。Central 通常是 Client，但**这两种身份不是同一回事**：设备侧完全可以既是 Server（对手机提供数据），又主动当 Client 去读另一个设备。

### 一个常见误判

> 「连不上一定是手机这边的问题」—— 不一定。服务发现为空、CCCD 写不进去，都可能是设备侧暴露的数据结构有问题。把角色先分清，再谈「蓝牙连不上」才有意义。

## 术语速查

| 术语 | 含义 |
|---|---|
| GAP | 广播与连接建立的规则，决定「设备怎么被发现」 |
| GATT | 连上之后的数据组织方式，Service / Characteristic / Descriptor 三层 |
| CCCD | Client Characteristic Configuration Descriptor，控制 Notify 开关的那个描述符 |
| MTU | 单次传输的最大字节数，默认 23（实际可用 20），可协商 |
| RSSI | 信号强度，单位 dBm，负值越接近 0 越强 |
| `autoConnect` | 传 `true` 让系统低功耗后台等待，传 `false` 立即直连 |

## 下一步

- 权限与系统版本差异 → [权限与版本适配](#android/getting-started/permissions)
- 连不上的那些报错 → [常见问题排查](#android/experience/common-issues)
