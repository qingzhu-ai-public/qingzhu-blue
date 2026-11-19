---
title: BLE 扫描全流程
order: 110
summary: 把扫描当成一个有开始、有结束的搜索窗口，每条回调都是窗口内收到的一次广播。
tags: SDK,BLE
updated: 2026-11-19
---

# 第 10 章　BLE 扫描全流程

上一章已经知道一条广播里可以有什么。现在把它接到列表上。用户点「找温度计」，看到设备一台台出现。选中目标、点取消或等到搜索结束，手机就停止扫描。

把从点按钮到停止这一段叫一次**扫描会话**。同一台温度计可能反复发广播，每次回调都是一次新的观测。页面可以合并到同一行，更新信号和最后出现时间。这样也能看出列表中的设备是刚刚看见的，还是几分钟前留下来的。

## 开一轮扫描，接住每次发现

确认蓝牙打开后，用 `adapter.bluetoothLeScanner` 拿本机扫描器。Android 5.0（API 21）起可用，蓝牙未开启时可能返回 `null`。现代目标版本启动扫描前检查 `BLUETOOTH_SCAN`，读设备系统名称或建立连接时再检查 `BLUETOOTH_CONNECT`。

```kotlin
val scanner = adapter.bluetoothLeScanner ?: return
val settings = ScanSettings.Builder()
    .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
    .build()
val callback = object : ScanCallback() {
    override fun onScanResult(callbackType: Int, result: ScanResult) {
        publishObservation(result)
    }
    override fun onBatchScanResults(results: MutableList<ScanResult>) {
        results.forEach(::publishObservation)
    }
    override fun onScanFailed(errorCode: Int) {
        finishScanWithError(errorCode)
    }
}
scanner.startScan(filters, settings, callback)
// 选中设备、取消或达到扫描期限时，调用 scanner.stopScan(callback)。
```

把 `scanner` 和 `callback` 保存到本轮会话里，到结束时用它们调用 `scanner.stopScan(callback)`。[双机实验](#android/development-guide/appendix-e-labs)里可以看到这两个动作怎样接到不同事件上。`startScan(callback)` 使用默认配置，适合前台排查。`startScan(filters, settings, callback)` 给出过滤条件和结果交付方式，返回 `Unit`。会话接受后依然可能等不到任何结果，应用要自行安排截止时间。立即抛出的权限或参数异常、`onScanFailed` 和扫描窗口为空要分开上报。

| API / 参数 | 什么时候用 |
| --- | --- |
| `onScanResult(callbackType, result)` | 处理单条报告，`callbackType` 指明全部匹配、首次匹配等交付方式。 |
| `onBatchScanResults(results)` | 使用批量交付时同时处理这一回调。每条结果用自己的单调时间。 |
| `setReportDelay(0)` | 尽快交付。大于零时用毫秒描述报告延迟，系统可批量交付。 |
| `flushPendingScanResults(callback)` | 请求交付已缓存的批量结果，异步到达同一个回调。 |
| `setScanMode(LOW_LATENCY)` | 前台用户触发的短窗口。持续搜寻优先评估 `LOW_POWER` 或 `BALANCED`。 |
| `setCallbackType(FIRST_MATCH / MATCH_LOST)` | API 23 起，涉及匹配状态和硬件资源。按设备支持配置非空有效过滤器，并处理配置失败。 |
| `setLegacy(false)` / `setPhy(...)` | API 26 起，扩展广播扫描选项。通常先测默认传统扫描，再按目标广播切换。 |
| `setScanType(SCAN_TYPE_PASSIVE)` | 36.1 起可选被动扫描。依赖 Scan Response 的字段要验证主动扫描的交付结果。 |
| `setRssiThreshold(int)` | 36.1 起可提供 RSSI 阈值。在旧系统可以在应用层过滤，并记录过滤位置。 |

## 用户选中设备以后停止搜索

界面的扫描按钮、防重入、计时器与 Scanner 回调交给同一个会话所有者。会话按「开始 → 收集 → 终态」推进。结束时取消该会话的计时器，使用原 Scanner 和原 Callback 调用 `stopScan`，对已排队事件按会话标识丢弃。页面需要更新列表时做合并和限频，避免每条高频广播都刷新 UI。

设备选中后优先保留 `ScanResult.device`。要连接的设备广播可能已经轮换地址，列表里十分钟前的条目需要重新找。用单调时间计算观测年龄，墙上时间的跳变不参与超时判断。

## 一句话总结

**把扫描当成一个有开始、有结束的搜索窗口，每条回调都是窗口内收到的一次广播。**

## 面试题

1. 回调重载的 `startScan` 返回后，在哪里知道扫到了设备？
2. 点击取消时为什么要用原来的 `ScanCallback`？

### 参考答案

1. 单条结果从 `onScanResult` 返回，批量结果从 `onBatchScanResults` 返回。启动错误还可通过 `onScanFailed` 或抛出的异常反映。
2. 扫描按本次注册的回调管理。用原回调调用 `stopScan`，并在 App 侧过滤已经入队的旧会话事件。

[BluetoothLeScanner](https://developer.android.com/reference/android/bluetooth/le/BluetoothLeScanner) · [ScanCallback](https://developer.android.com/reference/android/bluetooth/le/ScanCallback) · [ScanSettings.Builder](https://developer.android.com/reference/android/bluetooth/le/ScanSettings.Builder)
