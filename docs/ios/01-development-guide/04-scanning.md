---
title: 03　把附近的设备显示在列表里
slug: scanning
order: 40
---

# 03　把附近的设备显示在列表里

点「查找设备」，几秒内列表出现一行温度计。把蓝牙结果接到界面上，需要一次发起调用和一个接收结果的回调。

## 让系统开始搜索

在上一章的 `.poweredOn` 分支中调用以下代码。首次观察周围设备时可传 `nil`，下一章再按服务过滤。

```swift
central.scanForPeripherals(withServices: nil, options: nil)
```

第一个参数是允许出现的服务 UUID 列表，第二个参数是扫描选项。方法本身没有设备列表返回值。请在 App 里安排扫描窗口，比如 12 秒，结束时调用 `central.stopScan()`。点击连接或离开扫描页时也应结束本次扫描。

## 收到设备再更新列表

下面的方法和上一章的状态回调属于同一个委托。`peripheral` 是可用于后续连接的对象，`advertisementData` 是本次收到的广播字段字典。`RSSI` 是本次信号强度，单位 dBm。127 表示当前值不可用。

```swift
func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
    let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
    print(peripheral.identifier, name ?? "未命名设备", RSSI)
}
```

先用 Xcode 控制台确认有回调，再把值交给界面。列表需要留住设备对象，不能只保存名字。第一次拿到某个 identifier 时加一行，后续同一个 identifier 更新该行。综合实战里的 `SensorCentral.devices` 就是这样做的。

**动手验证**　启动扫描，至少看到一条结果。停止后保留列表，观察页面是否停止更新。

**一句话记住**　发起扫描就像打开收音机，真正听到了什么要等回调告诉你。

## 自查题

1. **扫描按钮点完立刻拿到列表吗？** 结果分批到达，逐条处理 didDiscover。
2. **RSSI 可以直接换算精准距离吗？** 环境、天线和遮挡都会影响它，先把它当信号强弱的近似指标。

[Apple 中心端扫描实例](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/PerformingCommonCentralRoleTasks/PerformingCommonCentralRoleTasks.html)

[上一章](#ios/development-guide/permissions) · [正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/scan-filters)
