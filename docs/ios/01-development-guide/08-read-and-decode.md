---
title: 07　点一次读取，把字节变成温度
slug: read-and-decode
order: 80
---

# 07　点一次读取，把字节变成温度

按一次「读取」，屏幕上应该出现当下的温度。先拿到值，再根据设备协议把值换成摄氏度。

## 发起一次读取

确认特征支持 `.read`，然后调用 `peripheral.readValue(for: sample)`。系统通过 `peripheral(_:didUpdateValueFor:error:)` 返回。先看 error 有没有值，再检查特征是不是这次想读的那一项，并从 `characteristic.value` 取出 Data。

读值回调也用于接收订阅更新。实现里要用目标特征、当前阶段和业务规则判断这条结果归谁，尤其避免把主动通知误当作某条读请求的结果。

## 先拆出两个温度字节

示例读数帧 `40 02 5A 0A 03 BF 13` 的温度字段是 `5A 0A`，低字节先到。下面的函数用两个字节组合出一个有符号值。

```swift
func temperature(low: UInt8, high: UInt8) -> Double {
    let bits = UInt16(low) | (UInt16(high) << 8)
    return Double(Int16(bitPattern: bits)) / 100.0
}
```

读数组前检查长度和对象编号。`5A 0A` 拼起来是十六进制 `0A5A`，十进制 2650，所以显示 26.50 °C。协议规定有符号时才按 Int16 解释。湿度字段使用无符号值。

**动手验证**　给函数传 `0x9C, 0xFF`，应得到 -1.00 °C。再给解码器传截断帧，应提示格式错误。

**一句话记住**　蓝牙回来的只是字节，单位、正负号和倍率都由协议决定。

## 自查题

1. **读取方法直接返回温度吗？** 值从 didUpdateValueFor 带回，再由 App 解析。
2. **为什么要检查长度？** 截断数据可能导致数组越界或把下一字段读成当前值。

[Apple CBPeripheral 文档](https://developer.apple.com/documentation/corebluetooth/cbperipheral) · [BTHome 格式](https://bthome.io/format/)

[上一章](#ios/development-guide/services-characteristics) · [正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/write)
