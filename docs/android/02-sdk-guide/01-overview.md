---
title: 青竹 BLE SDK 总览
order: 10
summary: 任务式 SDK 的定位、架构、模块边界和当前能力
tags: 必读,SDK
updated: 2026-11-19
---

# 青竹 BLE SDK 总览

青竹 BLE SDK 是一套**任务式 Android BLE SDK**。它不把 `connectGatt`、GATT 回调、重试和并发调度直接摊给业务，而是把「一台设备要做什么」收进一个任务。

## 它解决什么问题

普通 BLE 封装通常只处理：

```text
扫描 → 连接 → 发现服务 → 写数据 → 收通知
```

正式项目还会遇到：

- 多台设备同时连接、批量下发；
- 页面反复进出、连续点击导致命令互相覆盖；
- 设备换地址、硬断电、假在线；
- 扫描假死、连接回调迟迟不来；
- 取消、删除后旧回调仍然到达；
- 每接一类设备就复制一套扫描/连接/重试逻辑。

青竹 SDK 的核心思路是：

> BLE 资源在进程内是共享的，必须有唯一所有者；业务只表达要做什么。

## 一次任务的心智模型

```java
// 1. 拿任务：一台设备一个任务
QTask task = QingzhuSdk.createTask(mac);

// 2. 发命令：结果通过回调拿，每条命令恰好回调一次
task.send(QCommand.builder()
        .send("{\"action\":\"echo\"}")
        .build(),
        result -> {
            if (result.isSuccess()) {
                String payload = result.payload();
            } else {
                TaskStage stage = result.stage();   // 失败发生在哪一步
                String error = result.error();
            }
        });
```

任务负责：

```text
扫描寻人 → 排队 → 连接 → 发现服务 → 发送 → 收尾
```

业务也可以随时读取任务当前状态：

```java
task.getState();        // SEARCHING / CONNECTING / SENDING ...
task.getProgress();     // 发送进度
task.getResult();       // 设备回执
task.getError();        // 最近一次失败原因
task.getOutcome();      // SUCCEEDED / CONNECT_FAILED / OPERATION_FAILED / CANCELLED
```

## 架构

```text
业务 App
  → 门面 QingzhuSdk
  → 内核 qingzhu-core
      任务池 / 扫描 / 建连闸门 / GATT 队列 / 命令队列 / 连接池
  → 协议插件
      Generic / Eddystone / 自有协议
  → Android BLE Stack
```

模块职责：

| 模块 | 职责 |
|---|---|
| `qingzhu-core` | 任务池、扫描、连接池、GATT、命令队列、重试 |
| `qingzhu-company-sdk` | 开源源码门面，暴露任务和扫描 API |
| `qingzhu-protocol-generic` | Generic 示例协议 |
| `qingzhu-protocol-eddystone` | Eddystone 示例协议 |
| `qingzhu-demo-*` | 1 个主端 + 2 个从端试玩 App |

内核不依赖任何协议模块，也不依赖门面。协议只向内核注册，内核不认识具体协议。

## 当前已经实现

- 任务式创建：`createTask` / `getTask` / `deleteTask`；
- 自动寻人、状态 / 进度 / 结果 / 错误；
- 命令结果统一回调：`TaskResult` + 失败阶段 `TaskStage`；
- 有界命令队列，同一设备串行执行，不覆盖正在执行的命令；
- 取消与删除：`cancel` 回到操作前状态，`delete` 断开并移除；
- 连接参数按任务设置：`setConnectParams`；
- 状态观察：任务级 `observe`、池级 `observeAll`，回调不可变快照；
- 串行建连、连接容量、传输窗口；
- 协议插件化和稳定身份；
- 扫描设置：时长、RSSI、名称、协议、stableId 过滤；
- 任务生命周期相关单测 16 个用例。

## 仍然是边界

- **设备主动上报通路没有实现**：`QTask` 没有 `listen`，设备主动推送的数据暂时无法通过任务接收。
- **没有自动并发学习**：启动时会给一个体检建议值，运行期不再根据结果自动调整。
- **`noAck()` 暂不起作用**：只是命令上的标记，还没传给底层。
- **只有 Android 实现**：`BleAdapter` 是平台抽象，但只有一份实现。
- 大规模真机兼容性、长期浸泡和弱网/丢包数据还在补；
- 插件优先级、冲突告警、启停和版本治理尚未完成；
- iOS / HarmonyOS / Flutter / React Native 目前只是站点预留。

下一步：[快速接入](#android/sdk-guide/quickstart) · [任务与命令](#android/sdk-guide/task-and-command) · [协议插件](#android/sdk-guide/protocol-plugin)
