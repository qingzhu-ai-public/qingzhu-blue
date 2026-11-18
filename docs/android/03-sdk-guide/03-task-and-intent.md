---
title: 任务与意图
order: 30
summary: QTask、QCommand、任务状态判断、意图排队、终态回调和取消删除
tags: SDK,进阶
updated: 2026-11-18
---

# 任务与意图

## 一台设备一个任务

同一台物理设备只对应一个 `QTask`。重复 `submit` 会复用任务，避免两个页面同时连同一台设备。

```java
QTask task = QingzhuSdk.submit(mac, command);
```

## 任务状态从哪里来

任务状态只有一个入口：

```java
QingzhuSdk.subscribe(tasks -> {
    for (QTask task : tasks) {
        TaskState state = task.getState();
        TaskOutcome outcome = task.getOutcome();
        String result = task.getResult();
        String error = task.getError();
        int pending = task.pendingIntentCount();
    }
});
```

`subscribe()` 在任务池状态变化时推送**全量任务快照**。Demo 不靠单独的 `onSuccess()` / `onFailed()` 事件，而是每次拿到快照后，从 `QTask` 字段判断当前阶段和上一次结果。

## `TaskState`：现在在做什么

```text
UNKNOWN / READY / SEARCHING / QUEUED / CONNECTING / CONNECTED / SENDING
```

| 状态 | 含义 | Demo 显示 |
|---|---|---|
| `UNKNOWN` | 只有 MAC，还没找到设备 | 未知设备 |
| `READY` | 已找到设备，空闲、未连接，等命令 | 就绪 |
| `SEARCHING` | 占位任务正在扫描寻人 | 寻找中 |
| `QUEUED` | 等连接窗口、传输窗口，或处在重试等待 | 排队中 |
| `CONNECTING` | 正在建立 GATT 连接 | 连接中 |
| `CONNECTED` | 已连接，空闲或保持连接 | 已连接 |
| `SENDING` | 正在发数据 | 发送中 + 进度条 + 实时速率 |

`TaskState` 不是结果。SDK 没有单独的 `FAILED` 状态；失败后任务会回到 `READY` 或 `UNKNOWN`。

## 成功、失败、取消怎么判断

成功/失败不看单个状态，而看 `state + outcome + result + error` 的组合。

| UI 语义 | 判断条件 | 说明 |
|---|---|---|
| 还没执行过 | `state == UNKNOWN/READY` 且 `outcome == NONE` | 新任务或空闲任务 |
| 正在执行 | `state == SEARCHING/QUEUED/CONNECTING/SENDING` | 不要根据 `result` 判成功 |
| 发送中 | `state == SENDING` | 用 `progress / sentBytes / totalBytes` |
| 有排队命令 | `pendingIntentCount() > 0` | 显示「待执行 N」 |
| 发送成功 | `state != SENDING` 且 `outcome == SUCCEEDED` 且 `error == null` | `result` 是设备回显，可能为 null |
| 保持连接且成功 | `state == CONNECTED` 且 `outcome == SUCCEEDED` | 发完没断开 |
| 连接阶段失败 | `state == READY/UNKNOWN` 且 `outcome == CONNECT_FAILED` | 寻人超时、连接失败、认证失败 |
| 发送/业务失败 | `state == READY/UNKNOWN` 且 `outcome == OPERATION_FAILED` | 已连接后发送失败、重试耗尽 |
| 取消 / 删除 | `outcome == CANCELLED` | 用户取消、删除，或前序失败导致待办取消 |
| 失败原因 | `error != null` | 例如 `查询失败 reason=129` |
| 设备回显 | `result != null` | 成功也可能没有回显 |

> 关键：`result != null` 不等于成功，`error == null` 也不等于成功。
> 成功/失败的权威字段是 `TaskOutcome`；`state` 只说明当前阶段。

## 一个可直接复制的状态函数

```java
static String describeTask(QTask t) {
    TaskState s = t.getState();
    TaskOutcome o = t.getOutcome();

    if (s == TaskState.SENDING) {
        return "发送中 " + t.getProgress() + "%"
                + (t.pendingIntentCount() > 0
                    ? " · 待执行 " + t.pendingIntentCount() : "");
    }
    if (s == TaskState.CONNECTED) {
        return o == TaskOutcome.SUCCEEDED && t.getResult() != null
                ? "已连接 · 回显：" + t.getResult()
                : "已连接 · 保持连接中";
    }
    if (s == TaskState.SEARCHING) return "寻找设备";
    if (s == TaskState.QUEUED) return "排队中 / 重试等待";
    if (s == TaskState.CONNECTING) return "连接中";

    switch (o) {
        case SUCCEEDED:
            return t.getResult() != null
                    ? "发送成功 · 回显：" + t.getResult()
                    : "发送成功";
        case CONNECT_FAILED:
            return "连接失败：" + t.getError();
        case OPERATION_FAILED:
            return "发送失败：" + t.getError();
        case CANCELLED:
            return "已取消：" + t.getError();
        case NONE:
        default:
            return s == TaskState.UNKNOWN ? "未知设备 / 未找到" : "就绪 / 未连接";
    }
}
```

## Demo 里的真实链路

公开 SDK 仓库的 `qingzhu-demo-main` 就是按上面的规则写的：

```text
QTaskPool.notifyChanged()
  → QingzhuSdk.subscribe()
  → SdkManager.taskListeners
  → TaskFragment
  → TaskAdapter.submit(tasks)
```

对应文件：

| 文件 | 作用 |
|---|---|
| `SdkManager.kt` | `QingzhuSdk.subscribe { tasks -> ... }`，缓存并转发任务快照 |
| `TaskFragment.kt` | `addTaskListener { adapter.submit(tasks) }` |
| `TaskAdapter.kt` | 把 `state` 翻译成中文；发送中显示进度；完成后显示大小、耗时、速度或回显 |
| `CommandSheet.kt` | 用 `executeIntent(command)` 的 `TaskIntentResult` 弹「已排队 / 队列满 / 已连接」等即时提示 |

Demo 当前**没有使用** `executeIntent(command, callback)` 的 `TaskIntentStatus`，因为它只需要展示任务列表，不需要把每次点击绑定到业务数据库或命令链。

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

`TaskIntentResult` 是「有没有被受理」，`TaskIntentStatus` 是「这一条命令最终办完没有」。两者都和 `TaskState` 不是同一个维度。

## 单个配置：什么时候可以退出页面

推荐把一次配置动作绑定到一条命令回执：

```java
QTask task = QingzhuSdk.submit(mac, null);

TaskIntentResult accepted = task.executeIntent(configCommand,
        (intentId, status, result, error) -> {
            if (status == TaskIntentStatus.SUCCEEDED
                    && task.getOutcome() == TaskOutcome.SUCCEEDED
                    && task.getError() == null) {
                finish();          // 配置成功，退出
            } else if (status == TaskIntentStatus.FAILED) {
                showError(error);  // 不退出
            } else {
                showCancelled();   // 不退出
            }
        });

if (accepted == TaskIntentResult.BUSY
        || accepted == TaskIntentResult.CLOSED) {
    showRejected(accepted);       // 没被接受，不会收到 callback
}
```

| 组合 | 结果 |
|---|---|
| `BUSY / CLOSED` | 没受理，不回调，不退出 |
| `SUCCEEDED + TaskOutcome.SUCCEEDED + error == null` | 配置成功，退出 |
| `FAILED + CONNECT_FAILED` | 连接阶段失败，不退出 |
| `FAILED + OPERATION_FAILED` | 发送/业务失败，不退出 |
| `CANCELLED` | 取消或前序失败，不退出 |

注意：`result` 可能为 null；`CONNECTED + SUCCEEDED` 也可能是成功，不能一直等 `READY`。

## 批量配置：什么时候可以退出页面

批量配置用显式 `Batch`，不要用自动学习批次来判断业务结束。

```java
QSdk.Batch batch = QingzhuSdk.beginBatch(result -> {
    if (result.isAllSucceeded()) {
        finish();                 // 全部成功，退出
    } else {
        showBatchSummary(result); // 展示成功/失败/取消数量
    }
});

for (String mac : macs) {
    if (batch.submit(mac, configCommand) == null) {
        // BUSY / CLOSED / 被别的批次认领：没有计入本轮
    }
}
batch.finish();
```

`BatchResult`：

| 字段 | 含义 |
|---|---|
| `getTotal()` | 本轮被接受的任务数 |
| `getSucceeded()` | 成功数量 |
| `getConnectFailed()` | 连接失败数量 |
| `getOperationFailed()` | 发送/业务失败数量 |
| `getCancelled()` | 取消、删除或未终态数量 |
| `isAllSucceeded()` | `total > 0 且 succeeded == total` |

结束条件：

```text
所有被接受任务 outcome != NONE
且 pendingIntentCount() == 0
且不再处于 SEARCHING / QUEUED / CONNECTING / SENDING
→ BatchListener.onFinished(result)
```

补充规则：

- `submit()` 返回 null 的命令不会执行，也不计入结果；
- `batch.cancel()` 也会触发 `onFinished()`；
- 10 分钟兜底超时强制结算；
- 回调在主线程触发一次。

## 取消与删除

```java
task.cancel(); // 停止当前动作，清空待办，任务保留
task.delete(); // 删除任务，断开连接，后续提交返回 CLOSED
```

取消、删除会给当前、待办和连接等待中的意图发送 `CANCELLED` 回调。

## 回调线程

任务和扫描回调都在主线程。不要在回调里做重活；需要解析大包时先入队，再交给工作线程。

下一步：[多设备调度](#android/sdk-guide/multi-device) · [协议插件](#android/sdk-guide/protocol-plugin)
