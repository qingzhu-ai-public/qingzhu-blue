---
title: 04　设备连上后，找到可读写入口
slug: connect-and-discover
order: 50
---

# 04　设备连上后，找到可读写入口

点设备以后，先显示正在连接。等 App 找到了指定服务和特征，请求读数按钮才可用。

## 用扫描提供的设备 ID 建立客户端

```typescript
const client = ble.createGattClientDevice(deviceId);
client.on('BLEConnectionStateChange', onState);
client.connect();
```

创建实例只是拿到后续操作的句柄。连接有没有成功，等 `onState` 中看到 `STATE_CONNECTED` 再判断。已经取消或超时的旧会话收到事件时直接忽略。

## 连接后再查服务表

连接成功后调用 `await client.getServices()`。结果里的每个服务有 `serviceUuid` 和特征列表，按设备协议的两个编号找到目标 `BLECharacteristic`。如果 SDK 结果提供属性，核对读写能力。若属性信息未提供，按设备规格和实际读写结果验证。找不到特征时显示明确提示，保持按钮禁用。

需要退出时清理监听，使用 `disconnect()` 和 `close()` 结束连接与客户端资源。仅把页面关掉不会自动完成这些清理。

**自己试一次**　只改外设的特征 UUID。确认 A 可能连上，但找不到教学特征。

**一句话记住**　连上后还要找到设备里具体能读写的那一项。

## 自查题

1. **为什么 connect 下一行不直接读？** 发起连接之后还要等连接成功和服务发现结果。

[华为 GATT 开发指南](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-guides/gatt-development-guide/)

[上一章](#harmonyos/development-guide/scan-and-filter) · [正文目录](#harmonyos/development-guide/overview) · [下一章](#harmonyos/development-guide/read-write-and-parse)
