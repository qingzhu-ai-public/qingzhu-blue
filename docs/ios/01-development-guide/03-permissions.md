---
title: 02　为什么点查找设备会弹出权限提示
slug: permissions
order: 30
---

# 02　为什么点查找设备会弹出权限提示

第一次点「查找设备」，iPhone 可能弹出蓝牙用途说明。用户点允许也要等系统告诉 App 蓝牙是否可用。

## 填用途说明

在 Xcode 选 App target，打开 **Info**。新增 **Privacy - Bluetooth Always Usage Description**，键名为 `NSBluetoothAlwaysUsageDescription`，内容写清 App 为什么需要访问蓝牙。如果工程有 Info.plist 文件，也可以加在其中。系统使用这句话显示授权提示。

## 让系统回报状态

创建 `CBCentralManager(delegate: self, queue: nil)` 并保存到属性上。`delegate` 是系统要通知的对象，`queue: nil` 让回调走主队列，方便下一步更新界面。以下方法放在实现 `CBCentralManagerDelegate` 的类中。

```swift
func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .poweredOn: print("可以启动扫描")
    case .poweredOff: print("请在设置打开蓝牙")
    case .unauthorized: print("请检查 App 的蓝牙权限")
    case .unsupported: print("当前设备不支持")
    default: print("等待系统状态更新")
    }
}
```

`CBManager.authorization` 能单独查看 App 的授权状态。真正启动扫描前仍要等管理器报告 `.poweredOn`。一个负责回答用户有没有授权，另一个回答蓝牙此刻能不能工作。

## 验证三个分支

在真机上依次观察首次允许、设置里撤销权限、关闭系统蓝牙时的表现。权限弹窗由系统决定何时展示，重试扫描不会强制再弹一次。

**一句话记住**　先说明用途，再等系统报告可用，收到 poweredOn 后才开始扫描。

## 自查题

1. **授权允许，为什么仍会收到 poweredOff？** 授权和蓝牙开关是两个条件。
2. **为什么要把管理器保存为属性？** 回调稍后到来，App 需要持有负责本次操作的管理器。

[Apple Core Bluetooth 权限说明](https://developer.apple.com/documentation/corebluetooth)

[上一章](#ios/development-guide/advertising) · [正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/scanning)
