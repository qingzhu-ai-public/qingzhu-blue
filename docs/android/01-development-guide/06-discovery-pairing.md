---
title: 经典蓝牙发现、配对与绑定
order: 70
summary: 发现把设备找出来，绑定让下次还能认出它，连上目标服务才有数据可读。
tags: SDK,经典蓝牙
updated: 2026-11-19
---

# 第 6 章　经典蓝牙发现、配对与绑定

把目标换成一台使用经典蓝牙的串口模块。第一次打开页面，希望能在附近找到它。点击设备时系统可能弹出配对界面。第二天再来，用户通常希望直接从「已配对」里选。

这里发生了三件事。**发现**找的是附近能被发现的设备。**配对**让两端建立安全连接需要的密钥。**绑定**保存配对产生的密钥供以后使用。App 可以调用 `adapter.bondedDevices` 列出已有绑定的设备，但设备此刻可能没开机。实际能不能读写，要等下一章的 Socket 连接结果。

## 手机怎样找到第一次见的模块

1. 注册 `BluetoothDevice.ACTION_FOUND`、`BluetoothAdapter.ACTION_DISCOVERY_STARTED` 和 `ACTION_DISCOVERY_FINISHED` 的接收器。
2. 检查蓝牙和扫描权限，调用 `adapter.startDiscovery()`。返回 `false` 时处理立即失败。
3. `ACTION_FOUND` 中从 `BluetoothDevice.EXTRA_DEVICE` 取设备，并按需求读取 `EXTRA_RSSI`、`EXTRA_CLASS` 等字段。API 33 起可用类型化的 `getParcelableExtra(key, BluetoothDevice::class.java)`，旧版本用旧重载。
4. 用户选中后调用 `adapter.cancelDiscovery()`，再发起配对或 Socket 连接。结束页面或超时时也取消自己启动的发现。

`startDiscovery()` 自 API 5 可用，现代应用需 `BLUETOOTH_SCAN`。发现是较重的系统操作，连接前调用 `cancelDiscovery()` 可降低干扰。系统文档建议连接前取消发现，即使发现由其他应用启动。

通常经典蓝牙的服务端先监听 RFCOMM。想让客户端通过发现找到**本机**，可用 `ACTION_REQUEST_DISCOVERABLE`，以 `EXTRA_DISCOVERABLE_DURATION` 提供请求秒数，交由用户确认。现代版本需要 `BLUETOOTH_ADVERTISE`。已知地址的客户端和已配对设备通常可以直接尝试连接。

## 用户选中模块以后

| 方法 | 版本与结果 | 读写时机 |
| --- | --- | --- |
| `getBondedDevices()` | API 5，返回已绑定设备集合 | 先等适配器 `STATE_ON`。现代应用需 `CONNECT`。 |
| `getBondState()` | API 5，返回 `BOND_NONE`、`BOND_BONDING`、`BOND_BONDED` | 使用设备对象和 `ACTION_BOND_STATE_CHANGED` 配对观察。 |
| `createBond()` | API 19，布尔值表示是否开始 | 监听 `ACTION_BOND_STATE_CHANGED`，结合 `EXTRA_BOND_STATE` 与 `EXTRA_PREVIOUS_BOND_STATE`。系统处理必要的用户交互。 |
| `createBond(TRANSPORT_BREDR)` | API 37，新重载提供传输选择 | 在旧系统使用无参重载。现代应用需 `CONNECT`。 |
| `getUuids()` | API 15，读取系统缓存 | 缓存可能为空，也可能不完整。 |
| `fetchUuidsWithSdp()` | API 15，发起异步 SDP 查询 | 查 `ACTION_UUID` 和 `EXTRA_UUID`。观察到广播后仍应考虑缓存和发现失败。 |

用户点「配对」时，App 对选中的 `BluetoothDevice` 调用 `createBond`。系统负责必要的确认流程。等 `ACTION_BOND_STATE_CHANGED` 里该设备的状态变成 `BOND_BONDED`，再更新列表并尝试连接。安全 RFCOMM 连接本身也可能触发配对。要知道模块开放了哪些经典服务，还可以通过 SDP 查询 UUID。最终以目标服务能否建立 Socket 为准。

## 一句话总结

**发现把设备找出来，绑定让下次还能认出它，连上目标服务才有数据可读。**

## 面试题

1. `startDiscovery()` 返回 `true`，从哪里取得发现的设备？
2. 怎么判断 `createBond()` 的本次结果？

### 参考答案

1. 监听 `ACTION_FOUND`，从广播的 `EXTRA_DEVICE` 取设备。返回值仅表示发现请求已启动。
2. 监听目标设备的 `ACTION_BOND_STATE_CHANGED`，结合前后状态判断绑定成功、取消或失败。

[查找蓝牙设备](https://developer.android.com/develop/connectivity/bluetooth/find-bluetooth-devices) · [BluetoothDevice](https://developer.android.com/reference/android/bluetooth/BluetoothDevice)
