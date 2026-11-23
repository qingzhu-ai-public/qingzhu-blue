---
title: 12　让另一台 iPhone 扮演温度计
slug: peripheral
order: 130
---

# 12　让另一台 iPhone 扮演温度计

先让手机 B 宣布自己是一台教学温湿度计。手机 A 搜到它后，就能练连接和收发。

## 先建好服务，再开始广播

手机 B 持有 `CBPeripheralManager(delegate: self, queue: nil)`，等 `peripheralManagerDidUpdateState` 报告 `.poweredOn` 再添加服务。

```swift
let sample = CBMutableCharacteristic(type: sampleUUID,
    properties: [.read, .write],
    value: nil, permissions: [.readable, .writeable])
let service = CBMutableService(type: serviceUUID, primary: true)
service.characteristics = [sample]
manager.add(service)
```

这里的 properties 对外声明支持哪些操作，permissions 说明服务器允许怎样访问。`value: nil` 让代码在收到请求时动态提供值。`didAdd service` 回调没有错误后，才能用 `startAdvertising` 启动广播。

```swift
manager.startAdvertising([
    CBAdvertisementDataLocalNameKey: "QZ-Sensor",
    CBAdvertisementDataServiceUUIDsKey: [serviceUUID]
])
```

等待 `peripheralManagerDidStartAdvertising(_:error:)`，成功再通知用户拿另一台手机扫描。iPhone 外设的广播自定义键是名称和服务 UUID，温湿度留在连接后的特征。停止模拟模式时，调用 `stopAdvertising()`，并按需要移除服务。

**动手验证**　手机 B 先完成广告启动。手机 A 按该服务编号扫描，观察是否出现名称或教学默认名称。

**一句话记住**　外设先把读写入口准备好，再发广播让别人来找。

## 自查题

1. **为什么不能 add 后立刻广播？** 服务添加有结果回调，等成功可以避免客户端提前连到未准备好的外设。
2. **停广播就等于断开已连接的客户端吗？** 停止广播和已建立连接的生命周期是不同操作。

[Apple 外设角色示例](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/PerformingCommonPeripheralRoleTasks/PerformingCommonPeripheralRoleTasks.html)

[上一章](#ios/development-guide/reconnect) · [正文目录](#ios/development-guide/overview) · [下一章](#ios/development-guide/peripheral-requests)
