---
title: 权限、版本与清单配置
order: 50
summary: 先看用户要做什么，再申请这一步真用得到的权限。
tags: SDK,平台,协议
updated: 2026-11-19
---

# 第 4 章　权限、版本与清单配置

给温度计页面加一个「搜索附近设备」按钮。用户点下去，会先遇到 Android 的权限窗口。直到系统允许 App 搜索，扫描代码才有机会收到设备。

把用户会做的动作拆开，就能理解权限为什么分成几项。用户按「搜索」时，App 要查看附近设备，需要扫描权限。用户选中温度计后，App 要连接和读数据，需要连接权限。让这台手机自己当温度计、发广播给别人看，才会用到广播权限。

下面的例子面向 `targetSdk >= 31` 的普通 App，也兼容 Android 11 及更早版本。在 Android 12 及以上，留意「附近设备」权限。在旧系统上扫描，根据系统规则申请位置权限并检查位置开关。

| 功能 | 运行在 API 31+ 且目标 API 31+ | API 23–30 上的典型要求 |
| --- | --- | --- |
| 经典发现或 BLE 扫描 | 运行时 `BLUETOOTH_SCAN`。用于推导物理位置时另需位置权限 | `BLUETOOTH`、`BLUETOOTH_ADMIN`，运行时申请 `ACCESS_FINE_LOCATION` 并检查系统位置状态 |
| 已配对列表、设备名称、配对、GATT、Socket、Profile | 运行时 `BLUETOOTH_CONNECT`，配对和部分调用的特权条件另查 | `BLUETOOTH`，配对及管理调用按方法需要 `BLUETOOTH_ADMIN` |
| 让本机可发现或发 BLE 广播 | 运行时 `BLUETOOTH_ADVERTISE` | `BLUETOOTH_ADMIN` 及所用 API 的旧版权限 |
| Android 10–11 后台发现 | 现代系统按对应后台规则 | 从后台执行发现还要按系统规则申请 `ACCESS_BACKGROUND_LOCATION` |

运行系统、目标版本和是否从位置推导中使用扫描结果都影响判定。维护目标 API 30 或更早的旧 APK 时，单独查该方法的权限段落。API 22 及以下按安装时权限模型处理。

## 先在清单里声明搜索与连接

下面的应用扫描、连接并能当外设，扫描结果从不用于推导物理位置。系统可能在 `neverForLocation` 模式过滤部分 BLE 信标。用得到这些数据时，调整声明并按实际用途申请位置权限。

```xml
<uses-feature android:name="android.hardware.bluetooth_le" android:required="false" />

<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />

<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
```

产品必须依赖 BLE 时，可以把 `required` 设为 `true`，让分发系统过滤设备。可选功能用 `PackageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)` 检查。位置是产品能力时，按实际精度要求声明位置权限。Android 12 起同时请求粗略与精确位置，并处理用户只给近似位置的选择。Android 10–11 如需后台位置，按系统规定的独立授权流程处理。

## 用户点「搜索」时怎么申请

`ActivityResultContracts.RequestMultiplePermissions()` 应在 Activity 或 Fragment 初始化时注册。按钮触发后按当前功能计算应申请的权限。以下以「扫描并连接」为例，纯广播功能会换一组。

```kotlin
val required = when {
    Build.VERSION.SDK_INT >= 31 -> arrayOf(
        Manifest.permission.BLUETOOTH_SCAN,
        Manifest.permission.BLUETOOTH_CONNECT
    )
    Build.VERSION.SDK_INT >= 23 -> arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
    else -> emptyArray()
}
val missing = required.filter {
    ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
}
if (missing.isEmpty()) startScanSession()
else permissionLauncher.launch(missing.toTypedArray())
```

系统授权窗口关闭后，回到 App 再检查这次操作需要的每一项权限。都已授权才去看蓝牙开关，然后开始扫描。用户也可以中途撤回权限，实际调用仍可能抛 `SecurityException`。界面可以分别提示「请允许搜索设备」「请打开蓝牙」「扫描启动失败」或「这次没有找到温度计」。

## 一句话总结

**先看用户要做什么，再申请这一步真用得到的权限。**

## 面试题

1. Android 12 及以上的现代目标版本，搜到设备后还要连它，涉及哪两项权限？
2. 用了 `neverForLocation`，为什么有些信标可能扫不到？

### 参考答案

1. 搜索要 `BLUETOOTH_SCAN`，连接和 GATT 操作要 `BLUETOOTH_CONNECT`。两项都检查再开始完整流程。
2. 这是应用声明不会用扫描结果推导位置的标志。Android 可能过滤部分 BLE 信标，接入时应按实际用途选择声明并复测。

[Android 蓝牙权限](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions) · [请求应用权限](https://developer.android.com/training/permissions/requesting)
