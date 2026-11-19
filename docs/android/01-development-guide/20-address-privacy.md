---
title: 地址轮换、稳定身份与隐私
order: 210
summary: 地址记设备这次从哪儿出现，业务身份记它在你的产品里是谁。
tags: SDK,安全,协议
updated: 2026-11-19
---

# 第 20 章　地址轮换、稳定身份与隐私

用户上午给一块电子标签改了名字，下午再扫，列表里居然多出一台同款标签。两条记录的广播地址不一样，设备却可能是同一块。数据库直接用广播地址作为主键时，就会遇到这种问题。

可以把上一轮收到的地址和设备在业务系统里的身份分开保存。地址连同时间放进「这次看到的设备」，用来定位当前连接。已经完成绑定和身份确认的那一项，保存在「我的设备」里，名称、归属和历史任务跟着这个记录走。

## 先理解为什么同一台设备会换地址

设备为减少被长期跟踪，可以使用会变化的私有地址。LE 地址有 public 和 random 两类。random 还分静态随机、可解析私有地址 RPA 和不可解析私有地址 NRPA。知道对应身份解析密钥 IRK 的系统可以解析 RPA。App 实际收到的地址或句柄还受 Android 解析和权限影响，接入时采样核对自己的设备。

| 需要保存什么 | 示例字段 |
| --- | --- |
| 业务设备 | 内部 ID、协议版本、型号、用户或站点归属、已认证身份 |
| 一次观测 | `ScanResult.device`、观察到的地址、时间戳、RSSI、源包、匹配依据 |
| 本次连接 | GATT 实例、会话代次、实测服务和链路状态 |

`BluetoothAdapter.getRemoteDevice(address)` 只构造设备句柄。`getRemoteLeDevice(address, addressType)`（API 33）还接受 public/random 类型。扫描之后可以直接用 `ScanResult.device`。保存历史观测便于诊断，重连时按设备协议获取新鲜观测。

遗留地址字符串进入 API 前用 `BluetoothAdapter.checkBluetoothAddress(address)` 校验。API 36 的 `BluetoothDevice.getIdentityAddressWithType()` 需要 `BLUETOOTH_PRIVILEGED` 等权限。普通应用设计识别逻辑时，可使用扫描句柄和设备协议提供的标识。

## 用户再回来时，怎样选中原来的标签

再点「找我的标签」时，用产品协议认出候选设备，然后用它这次扫描结果带来的句柄建连。产品可选绑定身份、安全连接后读取的标识，或授权端能识别的广播标识。广播里的明文序列号只能帮忙筛候选。要改设置或绑定归属，在认证过的连接中再次确认身份和权限。

如果广告包里始终携带同一个公开序列号，轮换地址仍会暴露可持续跟踪的标记。设备协议设计时把隐私需求、离线寻设备需求和部署流程写清楚。日志用短期随机 ID 或带密钥的脱敏标识，工单避免粘贴用户设备的完整地址、生产数据和配对凭据。

## 一句话总结

**地址记设备这次从哪儿出现，业务身份记它在你的产品里是谁。**

## 面试题

1. 一台设备轮换地址，App 应怎样重连？
2. 设备用了 RPA，却每次广播同一个明文序列号，会怎样？

### 参考答案

1. 按业务标识寻找本次新鲜的扫描观测，用当前 `ScanResult.device` 建连，并按设备协议再次确认身份。
2. 观察者仍可按序列号串联这些观测。设计广播字段时要单独考虑隐私和授权识别。

[BluetoothAdapter](https://developer.android.com/reference/android/bluetooth/BluetoothAdapter) · [Bluetooth Core 6.2 Security Manager](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/security-manager-specification.html)
