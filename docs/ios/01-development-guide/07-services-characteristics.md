---
title: 06　连上之后，去哪里找温度
slug: services-characteristics
order: 70
---

# 06　连上之后，去哪里找温度

手机显示连上了，读取按钮仍然是灰的。现在要找到设备上真正可以读取温度的那一项。

## 从服务分组找具体的数据项

服务像一组功能，特征像其中一个有编号的读写入口。服务和特征的 UUID 要从设备协议获取。先把 `peripheral.delegate` 指向接收回调的对象，再按以下顺序调用。

```swift
peripheral.discoverServices([serviceUUID])

// 在 didDiscoverServices 中取得匹配的 CBService 后
peripheral.discoverCharacteristics([sampleUUID], for: service)
```

这段代码是两个时刻的摘录，第二行发起操作要等第一次回调成功。两次调用均无直接结果，分别在 `didDiscoverServices` 和 `didDiscoverCharacteristicsFor` 检查 error 后查找对象。已知目标时传指定 UUID，nil 用于按需要探索该层所有条目。

## 有这个特征还要看它允许做什么

找到目标后检查 `characteristic.properties`。`.read` 表示可读，`.write` 表示支持有响应写，`.writeWithoutResponse` 表示支持无响应写，`.notify` 和 `.indicate` 对应订阅能力。教学特征要同时支持读与有响应写，这时才能打开请求按钮。

**动手验证**　用外设端把特征 UUID 改成另一个值。中心端仍可能连成功，但课内的请求按钮应保持禁用。

**一句话记住**　连上是找到设备，发现服务和特征是找到数据该往哪里走。

## 自查题

1. **discoverServices 的下一行能读 services 吗？** 先等发现服务回调成功，再读对象列表。
2. **同一个设备名能推断服务吗？** 应按协议编号和实际发现结果判断。

[Apple 中心设备角色示例](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/PerformingCommonCentralRoleTasks/PerformingCommonCentralRoleTasks.html)

[上一章](#ios/development-guide/connect) · [正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/read-and-decode)
