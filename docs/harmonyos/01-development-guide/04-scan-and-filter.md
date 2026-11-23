---
title: 03　让教学设备出现在列表
slug: scan-and-filter
order: 40
---

# 03　让教学设备出现在列表

手机 B 发广播后，A 点「开始扫描」。列表出现一条设备和信号强度。

## 先接收事件，再发起扫描

本项目用一条短扫描展示 API 12 的写法。`onDevices` 的参数是 `ble.ScanResult[]`。先注册接收结果的函数，再开始扫。

```typescript
ble.on('BLEDeviceFind', onDevices);
ble.startBLEScan([{ serviceUuid: SERVICE }]);
```

过滤条件匹配广播中声明的服务 UUID。用 `deviceId` 合并本轮扫描的重复条目，用 `rssi` 显示信号强度。设备 ID 用来给连接 API 指定目标，跨会话的长期设备身份由协议另定。RSSI 会受距离、环境和遮挡影响。

## 停扫也要解除事件

停止时先 `ble.stopBLEScan()`，再 `ble.off('BLEDeviceFind', onDevices)`。传回注册时的同一个函数。先验证一个窗口，再考虑前后台行为和重复扫描。API 15 起有 `createBleScanner()` 等实例化扫描能力。不同 SDK 版本的事件和生命周期应对照官方文档。

**自己试一次**　把实战的 12 秒窗口改为 5 秒。先确认停止后保留已有列表，再确认重扫时旧结果会清掉。

**一句话记住**　扫描是订阅耳朵、开始听、按时关掉三步。

## 自查题

1. **startBLEScan 会返回设备列表吗？** 结果是在 BLEDeviceFind 事件里送回来的。

[华为 BLE 扫描指南](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ble-development-guide/)

[上一章](#harmonyos/development-guide/permission-and-state) · [正文目录](#harmonyos/development-guide/overview) · [下一章](#harmonyos/development-guide/connect-and-discover)
