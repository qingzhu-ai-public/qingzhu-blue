---
title: 青竹 BLE SDK 总览
order: 10
summary: 任务式 SDK 的定位、架构、模块边界和当前能力
tags: 必读,SDK
updated: 2026-11-17
---

# 青竹 BLE SDK 总览

青竹 BLE SDK 是一套**任务式 Android BLE SDK**。它不把 `connectGatt`、GATT 回调、重试和并发调度直接摊给业务，而是把「一台设备要做什么」收进一个任务。

## 它解决什么问题

普通 BLE 封装通常只处理：

```text
扫描 → 连接 → 发现服务 → 写数据 → 收通知
```

正式项目还会遇到：

- 多台设备同时连接、批量发送；
- 页面反复点击导致命令互相覆盖；
- 设备换地址、硬断电、假在线；
- 扫描假死、连接回调迟迟不来；
- 取消、删除后旧回调仍然到达；
- 每接一类设备就复制一套扫描/连接/重试逻辑。

青竹 SDK 的核心思路是：

> BLE 资源在进程内是共享的，必须有唯一所有者；业务只表达意图。

## 一次任务的心智模型

```java
QTask task = QingzhuSdk.submit(mac, QCommand.builder()
        .send("{\"action\":\"echo\"}")
        .build());
```

任务负责：

```text
扫描寻人 → 排队 → 连接 → 发现服务 → 发送 → 收尾
```

业务只需要观察：

```java
task.getState();       // SEARCHING / CONNECTING / SENDING ...
task.getProgress();    // 发送进度
task.getResult();      // 设备回执
task.getError();       // 最近一次失败原因
task.getOutcome();     // SUCCEEDED / CONNECT_FAILED / OPERATION_FAILED / CANCELLED
```

## 架构

```text
试玩 App
  → 门面 QingzhuSdk
  → 内核 qingzhu-core
      Task Pool / Scan / Connect Gate / GATT Queue
      Intent Queue / Adaptive / Diagnostics
  → 协议插件
      Generic / Eddystone / 自有协议
  → Android BLE Stack
```

模块职责：

| 模块 | 职责 |
|---|---|
| `qingzhu-core` | 任务、扫描、连接、GATT、队列、重试、自适应 |
| `qingzhu-company-sdk` | 开源源码门面，暴露任务和扫描 API |
| `qingzhu-protocol-generic` | Generic 示例协议 |
| `qingzhu-protocol-eddystone` | Eddystone 示例协议 |
| `qingzhu-demo-*` | 1 个主端 + 2 个从端试玩 App |

## 当前已经实现

- 任务式提交、自动寻人、状态/进度/结果/错误；
- 有界意图队列、命令级回调、取消与删除；
- 串行建连、连接容量、传输窗口；
- 自动批次学习；
- 协议插件化和稳定身份；
- 扫描设置：时长、RSSI、名称、协议、stableId 过滤；
- 36 个核心单元测试。

## 仍然是边界

- 大规模真机兼容性、长期浸泡和弱网/丢包数据还在补；
- 插件优先级、冲突告警、启停和版本治理尚未完成；
- iOS / HarmonyOS / Flutter / React Native 目前只是站点预留。

下一步：[快速接入](#android/sdk-guide/quickstart) · [任务与意图](#android/sdk-guide/task-and-intent) · [协议插件](#android/sdk-guide/protocol-plugin)
