---
title: 01　点扫描前，把权限和开关分开检查
slug: permission-and-state
order: 20
---

# 01　点扫描前，把权限和开关分开检查

Android 端的 Expo 配置插件负责生成清单。运行时由 `PermissionsAndroid.requestMultiple` 问用户是否授权。Android 12 以上申请扫描和连接权限，在 Android 11 及以下，本示例统一申请前台精确位置权限。排查扫描为空时，同时检查系统定位开关。

iOS 用途说明由 `bluetoothAlwaysPermission` 写入原生配置。启动 `BleManager` 后，Core Bluetooth 根据系统授权记录处理提示。用 `checkState()` 检查蓝牙状态，如果此时还在初始化，等状态更新或让用户重试。

**练习**　拒绝权限后再次点击。分别看系统是否允许重问，以及去设置手动授权后的变化。

**一句话**　配置文件写用途，用户的同意通过系统授权流程拿到。

**面试题**　开关是开的，App 就能连吗？

还要有当前系统版本要求的授权，外设也得处于可连接状态。

[react-native-ble-manager API](https://innoveit.github.io/react-native-ble-manager/methods/) · [温湿度计实战](#react-native/thermometer-mvp/overview)
