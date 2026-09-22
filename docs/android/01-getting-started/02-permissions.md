---
title: 权限与版本适配
order: 20
summary: Android 12 的权限拆分、定位权限的连带关系，以及运行时申请的写法
tags: 必读
updated: 2026-09-22
---

# 权限与版本适配

Android 的蓝牙权限是**改动最频繁、也最容易让老代码直接崩**的一块。Android 12（API 31）做了一次拆分，把「扫描」和「连接」彻底分开，这是必须知道的分水岭。

## 一张表看懂版本差异

| Android 版本 | API | 扫描需要 | 连接需要 | 关键变化 |
|---|---|---|---|---|
| 6.0 – 10 | 23–29 | `ACCESS_FINE_LOCATION` | `BLUETOOTH`/`BLUETOOTH_ADMIN` | 定位权限从「可选」变「必须」 |
| 11 | 30 | `ACCESS_FINE_LOCATION` | 同上 | 后台扫描限制收紧 |
| 12+ | 31+ | `BLUETOOTH_SCAN` | `BLUETOOTH_CONNECT` | 权限拆分，可声明不用于定位 |

`BLUETOOTH` 与 `BLUETOOTH_ADMIN` 在 Android 12 起是**旧接口**：仍然要声明（为了兼容低版本和 `getAdapter()`），但运行时不再需要单独申请。

## 清单怎么写

```xml
<!-- Android 11 及以下需要，用 maxSdkVersion 收口 -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />

<!-- Android 12+ ：拆成两个，各自申请 -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation"
    tools:targetApi="s" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

<!-- Android 11 及以下的扫描依赖定位权限 -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />

<!-- 声明本机需要蓝牙硬件，没有则不上架 -->
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />
```

`neverForLocation` 是 Android 12 的一个实用开关：声明「扫描结果不用来推断位置」后，就**不再需要定位权限**，用户少给一个授权，转化率明显不一样。

代价是：带 `neverForLocation` 的扫描会过滤掉一部分广播包（部分 Beacon 厂商数据会受影响）。如果你的业务只连自家设备、不解析 iBeacon，就大胆开。

## 运行时申请

不同版本要的权限不同，别写成一个固定数组：

```kotlin
private fun requiredPermissions(): Array<String> = when {
    Build.VERSION.SDK_INT >= 31 -> arrayOf(
        Manifest.permission.BLUETOOTH_SCAN,
        Manifest.permission.BLUETOOTH_CONNECT
    )
    Build.VERSION.SDK_INT >= 23 -> arrayOf(
        Manifest.permission.ACCESS_FINE_LOCATION
    )
    else -> emptyArray()
}

fun ensureThenStartScan(activity: ComponentActivity) {
    val need = requiredPermissions().filter {
        activity.checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
    }
    if (need.isEmpty()) return startScan()
    activity.registerForActivityResult(RequestMultiplePermissions()) { result ->
        // 注意：这里要判断「被拒绝」和「被永久拒绝」两种情况
        if (result.values.all { it }) startScan() else showDeniedGuide()
    }.launch(need.toTypedArray())
}
```

## 四个高频坑

**1. 定位服务没开，扫描静默返回空。**
Android 6–11 上，`ACCESS_FINE_LOCATION` 授权通过 ≠ 能扫描。「系统定位总开关」关掉时，扫描不报错、不回调，就是一个设备都发现不了。必须额外检查 `LocationManager.isLocationEnabled()`，并引导用户去打开。

**2. 权限组变了但没重新申请。**
用户在 Android 11 上授权过「定位」，升级到 Android 12 后，`BLUETOOTH_SCAN` 是全新权限，必须重新申请。老用户升级后功能失灵，八成是这个。

**3. 后台扫描要先过 `ACCESS_BACKGROUND_LOCATION`。**
Android 10 起，App 退到后台继续扫描需要后台定位权限；Android 12 起改用 `BLUETOOTH_SCAN` + 前台服务。纯扫描场景更稳的做法是**起一个前台服务**，而不是去要后台定位。

**4. `uses-feature` 缺 `required="true"`。**
漏了这行，没有 BLE 硬件的设备也能装，然后在运行时崩在 `getBluetoothLeScanner()` 返回 `null` 上。要么补上声明过滤掉设备，要么在代码里判空降级。

## 自查清单

- [ ] 清单里 `BLUETOOTH` / `BLUETOOTH_ADMIN` 都加了 `maxSdkVersion="30"`
- [ ] Android 12+ 走 `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT` 双权限
- [ ] 扫描前检查了系统定位开关（Android 6–11）
- [ ] `BLUETOOTH_SCAN` 按业务决定要不要 `neverForLocation`
- [ ] 没有把「定位被拒」处理成「蓝牙没开」

## 下一步

- 返回 [Android BLE 总览](#android/getting-started/overview)
- 权限都对但还是连不上 → [常见问题排查](#android/experience/common-issues)
