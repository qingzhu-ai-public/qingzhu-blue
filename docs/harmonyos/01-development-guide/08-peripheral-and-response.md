---
title: 07　把另一台手机变成外设
slug: peripheral-and-response
order: 80
---

# 07　把另一台手机变成外设

手机 B 切到模拟温湿度计。先准备 GATT 服务，再让 A 扫到并连接。

## 先注册服务，再广播

`ble.createGattServer()` 建外设端的 GATT 服务实例。构造含 `BLECharacteristic` 的 `GattService`，标明可读写属性并调用 `addService`。再用 `ble.startAdvertising` 发布可连接广播。实战使用与停止广播配对的单广播重载。官方还有返回广播 ID 的重载，需要用对应 ID 停止。

## 回应 A 的读写

注册服务器的 `characteristicWrite` 和 `characteristicRead` 事件。写时先查目标 UUID、偏移和命令字节。`needRsp` 为真才回状态。读时准备字节，从相应偏移返回。两类响应都靠 `deviceId` 和 `transId` 对上本次请求。

```typescript
server.sendResponse({ deviceId: request.deviceId, transId: request.transId,
  offset: request.offset, status: 0, value: buffer });
```

以上是一次成功读响应。`value` 应按协议提供字段，失败时填合适的 ATT 状态。停止实验时释放广播、事件监听和服务实例。

**自己试一次**　先只运行 B，等它报发起广播。用 A 验证找到设备再继续请求。

**一句话记住**　先准备可读写的入口，再请另一台手机来找。

## 自查题

1. **发送写响应时如何知道给谁？** 用本次请求里的 deviceId 和 transId 回应。

[华为 BLE API 参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-bluetooth-ble/)

[上一章](#harmonyos/development-guide/notify-and-indicate) · [正文目录](#harmonyos/development-guide/overview) · [下一章](#harmonyos/development-guide/disconnect-and-reconnect)
