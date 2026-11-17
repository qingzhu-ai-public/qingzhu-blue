---
title: 任务与意图
order: 30
summary: QTask、QCommand、意图排队、终态回调和取消删除
tags: SDK,进阶
updated: 2026-11-17
---

# 任务与意图

## 一台设备一个任务

同一台物理设备只对应一个 `QTask`。重复 `submit` 会复用任务，避免两个页面同时连同一台设备。

```java
QTask task = QingzhuSdk.submit(mac, command);
```

## 任务状态

`TaskState` 表示任务当前在做什么：

```text
UNKNOWN / READY / SEARCHING / QUEUED / CONNECTING / CONNECTED / SENDING
```

状态不是结果。失败后任务会回到 `READY` / `UNKNOWN`，失败原因在 `getError()`，终态分类在 `getOutcome()`。

## 命令

`QCommand` 描述一次意图：

```java
QCommand command = QCommand.builder()
        .send("{\"action\":\"echo\",\"text\":\"hello\"}")
        .keepConnected(true)
        .disconnectAfter()
        .build();
```

也可以只连接：

```java
QCommand connect = QCommand.builder().connect().build();
```

## 意图排队

同一台设备正在发送时，再次提交连接或发送不会被覆盖。

```java
TaskIntentResult result = task.executeIntent(command);
```

| 当前状态 | 新意图 | 结果 |
|---|---|---|
| 已连接 | 连接 | `ALREADY_SATISFIED`，保持连接 |
| 发送中 | 连接 | `ALREADY_SATISFIED`，发送继续，完成后保持连接 |
| 连接中 | 连接 | `IN_PROGRESS` |
| 发送中 | 发送 | `QUEUED`，进入有界 FIFO |
| 队列已满 | 发送 | `BUSY` |
| 任务已删除 | 任意 | `CLOSED` |

队列默认最多 8 条，可通过 `setMaxPendingIntents()` 调整。

## 命令级回调

`executeIntent()` 可以带回调，跟踪每一条意图自己的终态：

```java
task.executeIntent(command, (intentId, status, result, error) -> {
    if (status == TaskIntentStatus.SUCCEEDED) {
        // result 是设备回执
    } else if (status == TaskIntentStatus.FAILED) {
        // error 是失败原因
    } else {
        // CANCELLED
    }
});
```

## 取消与删除

```java
task.cancel(); // 停止当前动作，清空待办，任务保留
task.delete(); // 删除任务，断开连接，后续提交返回 CLOSED
```

取消、删除会给当前、待办和连接等待中的意图发送 `CANCELLED` 回调。

## 回调线程

任务和扫描回调都在主线程。不要在回调里做重活；需要解析大包时先入队，再交给工作线程。

下一步：[多设备调度](#android/sdk-guide/multi-device) · [协议插件](#android/sdk-guide/protocol-plugin)
