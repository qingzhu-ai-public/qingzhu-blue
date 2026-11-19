---
title: 配对、Bonding 与 LE 安全
order: 200
summary: 配对建立密钥，绑定把密钥留下，当前连接能不能改受保护的设置还要看加密、认证和设备权限。
tags: SDK,安全,协议
updated: 2026-11-19
---

# 第 19 章　配对、Bonding 与 LE 安全

手机连上了一个温度计，普通温度能读到，改报警阈值却失败。看一次写回调，假如设备返回 ATT 的 `0x05`，它在说这项访问还缺认证。设备允许建立连接，仍可以只把部分设置交给通过安全检查的客户端。

从这一条失败往回看，能分清四件事。配对让两端建立密钥。绑定把密钥保存到以后。连接加密用密钥保护当前传输。设备应用还可以单独检查操作的人有没有权限改配置。定位时先找出这个状态来自哪个回调。`onScanFailed(5)` 和属性访问返回 `0x05` 要在不同的状态码表里查。

## 第一次设置和下次重连，各需要什么

第一次写受保护的阈值时，系统可能要求两端配对。下一次重新连上，系统可以用绑定保存的密钥恢复这条链路的加密。产品还要决定是否要求防中间人认证，以及哪位用户能够修改阈值。

LE Secure Connections 和 Legacy Pairing 使用不同的密钥建立过程。Just Works、Numeric Comparison、Passkey Entry、OOB 的使用受双方输入输出能力、配对策略和协议支持影响。Just Works 本身不提供防中间人认证。没有屏幕或输入能力的设备需要在方案阶段约定可信的首次绑定方式。

## 从 Android 发起配对并观察结果

- `device.createBond()`（API 19）发起系统配对。API 37 的 `createBond(TRANSPORT_LE)` 可明确传输。先注册 `ACTION_BOND_STATE_CHANGED`，按目标设备及前后状态匹配，处理立即拒绝、系统交互、成功与撤销。
- API 36 的 `CompanionDeviceManager.removeBond(associationId)` 用于符合条件的伴生设备关联。查文档的关联和权限要求，普通应用可让用户在系统蓝牙设置中忘记设备。API 37 的 `BluetoothDevice.cancelBondProcess()` 和 `setPairingConfirmation(...)` 都涉及特权限制。
- Server 建表时用 `PERMISSION_READ_ENCRYPTED`、`PERMISSION_WRITE_ENCRYPTED` 或带 `_MITM` 的权限表达要求。属性声明的 `PROPERTY_READ/WRITE` 要与实际功能一致。
- GATT 访问受保护属性可能触发系统安全流程。应用等待实际回调，避免在已有配对请求时不断重新发起 `createBond`。同类写请求自动重试前，评估设备副作用。
- API 36 起可监听 `BluetoothDevice.ACTION_ENCRYPTION_CHANGE`，读 `EXTRA_DEVICE`、`EXTRA_TRANSPORT`、`EXTRA_ENCRYPTION_STATUS` 和 `EXTRA_ENCRYPTION_ENABLED`。需要核对安全参数时再读 `EXTRA_KEY_SIZE` 与 `EXTRA_ENCRYPTION_ALGORITHM`。按 `BLUETOOTH_CONNECT` 要求注册，结合当前连接判断该事件是否相关。

双模设备的绑定与加密按传输查询。API 37 的 `getBondStatus(TRANSPORT_LE)` 返回 `BondStatus`，该传输未绑定时返回空。36.1 的 `getEncryptionStatus(TRANSPORT_LE)` 返回 `EncryptionStatus`，未连接或未加密时可能为空。需要区分这两种情况，可以同时查询同版本的 `isConnected(TRANSPORT_LE)`，并结合这次会话的连接回调。三个方法都需要 `BLUETOOTH_CONNECT`。

做一次故障对照。假设温度计恢复了出厂设置，手机仍显示它已配对，却写不了阈值。温度计可能已经清除了旧密钥，手机还保留着。先记录手机和设备端的绑定状态、哪一边重置过、加密事件及属性结果。确认密钥不一致后，安排用户按产品流程在相应两端清理并重新关联。需要区分 0x05（认证不足）、0x08（授权不足）、0x0C（密钥长度不足）和 0x0F（加密不足），并结合 [状态码速查](#android/development-guide/appendix-c-codes) 确认来源。

## 一句话总结

**配对建立密钥，绑定把密钥留下，当前连接能不能改受保护的设置还要看加密、认证和设备权限。**

## 面试题

1. 已收到 `STATE_CONNECTED`，为什么受保护的属性仍可能写失败？
2. 手机显示已绑定，设备恢复出厂后怎么排查？

### 参考答案

1. 连接已建立，属性访问还有加密、认证或授权要求。用当前属性的 ATT 状态和加密事件判断缺哪一步。
2. 对照两端绑定状态和加密事件。确认旧密钥不一致后，按产品流程清理对应记录并重新关联。

[BluetoothDevice](https://developer.android.com/reference/android/bluetooth/BluetoothDevice) · [CompanionDeviceManager](https://developer.android.com/reference/android/companion/CompanionDeviceManager) · [Bluetooth Core 6.2 Security Manager](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/security-manager-specification.html)
