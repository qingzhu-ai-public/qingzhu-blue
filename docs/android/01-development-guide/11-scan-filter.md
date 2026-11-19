---
title: 过滤、熄屏与后台扫描
order: 120
summary: 先用广播里真实存在的条件找对设备，再选让结果到达页面还是交给后续工作。
tags: SDK,BLE
updated: 2026-11-19
---

# 第 11 章　过滤、熄屏与后台扫描

手机已经能搜到温度计。现在只想显示自己支持的型号，而且希望锁屏以后，系统在看到匹配设备时也有机会把结果交给 App。

先解决列表里混入其他设备的问题。与其收到所有广播再由页面逐条判断，可以告诉扫描器「我想找广播里带这个字段的设备」。这个条件叫 **ScanFilter**。拿上一章真实打印过的广播选字段，例如设备广播里一直存在的服务 UUID。通过这个过滤，再去测试锁屏和后台的行为。

## 让系统只交付匹配的广播

```kotlin
val filter = ScanFilter.Builder()
    .setServiceUuid(ParcelUuid(serviceUuid))
    .build()
scanner.startScan(listOf(filter), scanSettings, scanCallback)
```

假如新旧两款温度计宣布不同 UUID，可以放两个过滤器，命中任一个都算。假如新款还要看公司 ID，就把 UUID 和厂商数据填进同一个 `ScanFilter`，两项都满足才算。`setServiceUuid` 匹配的是实际广播里的 UUID，连接后才出现的服务无法用这个条件提前找出来。

| Builder 方法 | 适合过滤什么 | 使用时检查 |
| --- | --- | --- |
| `setServiceUuid(uuid[, mask])` | 广播里的 Service UUID 列表 | 掩码和 UUID 长度由类型决定。 |
| `setServiceSolicitationUuid(uuid[, mask])` | API 29，按 Service Solicitation UUID 匹配 | 对照实际 AD 类型，普通 Service UUID 列表不会满足这一条件。 |
| `setManufacturerData(id, data[, mask])` | 指定公司 ID 下的数据前缀 | 前缀不含公司 ID，位掩码长度和数据一致。 |
| `setServiceData(uuid, data[, mask])` | 指定 UUID 的 Service Data 前缀 | 和 Service UUID 列表是不同字段。 |
| `setDeviceName(name)` | 广播中的本地名称 | 名称可缺失、截断或更改。 |
| `setDeviceAddress(address)` | 已知且稳定的地址 | 轮换地址会让旧过滤器失效。 |
| `setAdvertisingDataType(type)` / `setAdvertisingDataTypeWithData(type, data, mask)` | API 33，自定义 AD 类型及其数据 | 先在无遮挡的扫描里检查报告字节。 |

掩码某一位为 1 时比较该位，为 0 时忽略。可以先写一个本地解析测试，固定一条广播字节串和预期结果。控制器卸载过滤是能力项，`isOffloadedFilteringSupported()` 可以查询。过滤器是否能分配到硬件还受配置和资源限制。

## 页面离开后，由系统交付扫描事件

把回调绑定在当前页面上，很适合用户正盯着列表搜索。想让系统在后续发现设备时交付结果，API 26 起可以用 `startScan(filters, settings, pendingIntent)`。返回 0 表示请求被接受，非零按扫描错误码记录。它适合进程未运行时接收匹配事件。使用指向自家显式 Receiver 的 PendingIntent，让系统补入扫描 extras。API 31 起按这一用途指定 `FLAG_MUTABLE`。保持相同身份的 PendingIntent 以便调用 `stopScan(pendingIntent)`，创建时避免用 `FLAG_CANCEL_CURRENT` 替换正在扫描的令牌。

接收 `BluetoothLeScanner.EXTRA_ERROR_CODE`、`EXTRA_CALLBACK_TYPE` 和 `EXTRA_LIST_SCAN_RESULT`。Receiver 负责快速转交事件，检查当前是否仍需要连接，再按系统后台规则安排短工作或持续连接。对「强行停止」后的交付和上次扫描存活情况单独测试。

```kotlin
val flags = PendingIntent.FLAG_UPDATE_CURRENT or
    (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
val callbackIntent = Intent(context, BleScanReceiver::class.java)
    .setAction("com.example.guide.ACTION_BLE_SCAN")
val token = PendingIntent.getBroadcast(context, 1, callbackIntent, flags)
val result = scanner.startScan(listOf(productFilter), scanSettings, token)
if (result != 0) reportScanStartError(result)
// 结束同一个会话时 scanner.stopScan(token)
```

在清单注册 `BleScanReceiver` 并设置 `android:exported="false"`，这个示例使用显式组件投递。多个扫描需要独立停止时，给每个请求不同的 requestCode 或 Intent 身份。接收器检查扫描错误字段后再解析列表。API 33 起使用带 `ScanResult::class.java` 的 Parcelable 列表重载。

## 缩小熄屏问题的范围

如果锁屏后列表停了，先看后台是否还收到扫描回调。可以记录 `ScanResult.timestampNanos` 和 App 收到回调的时间，把系统有没有发现和页面有没有刷新分开。Android 文档说明，无过滤扫描会在屏幕关闭时暂停，亮屏后恢复。先复测至少一条真正约束设备的过滤器，避免以空 `ScanFilter` 代替有效过滤。测试电源策略时，记录屏幕、进程、应用前后台、扫描 ID、过滤字段和设备是否仍广播。重复启停可能触发扫描失败，恢复动作应受用户意图、退避和最大次数约束。

## 一句话总结

**先用广播里真实存在的条件找对设备，再选让结果到达页面还是交给后续工作。**

## 面试题

1. 两个过滤器放进同一列表，设备要同时匹配吗？
2. 熄屏扫不到，怎样找第一份证据？
3. 怎样结束用 `PendingIntent` 开启的扫描？

### 参考答案

1. 过滤器列表按「或」匹配。一个过滤器内部设置的多项条件需要同时满足。
2. 记录系统交付时间和广播时间，核对有效过滤条件是否命中，并确认外设仍在广播。
3. 用身份相同的 `PendingIntent` 调 `stopScan`。保留原令牌或按相同身份重建，避免替换掉正在扫描的令牌。

[BluetoothLeScanner](https://developer.android.com/reference/android/bluetooth/le/BluetoothLeScanner) · [ScanFilter.Builder](https://developer.android.com/reference/android/bluetooth/le/ScanFilter.Builder) · [后台 BLE 通信](https://developer.android.com/develop/connectivity/bluetooth/ble/background)
