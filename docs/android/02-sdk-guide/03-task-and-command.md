---
title: 任务与命令
order: 30
summary: 任务生命周期、命令结果、排队规则、取消删除和页面退出时机
tags: SDK,进阶
updated: 2026-11-19
---

# 任务与命令

## 一台设备一个任务

同一台物理设备在进程内只有一个有效任务。三个入口分工明确：

```java
QTask task = QingzhuSdk.createTask(mac);   // 新建：会先删掉该设备已有任务
QTask same = QingzhuSdk.getTask(mac);      // 只查询：没有任务时返回 null
QingzhuSdk.deleteTask(mac);                // 删除：取消、断开、从任务池移除
```

页面里常见的写法是「有就复用，没有才建」：

```java
QTask task = QingzhuSdk.getTask(mac);
if (task == null) {
    task = QingzhuSdk.createTask(mac);
}
task.send(command, callback);
```

这样不会因为多按一次按钮，就把正在发送的任务替换掉。

任务被删除后不会复活：之后再调 `send` 会立即回调 `CLOSED` 失败。

## 任务状态

```text
UNKNOWN / READY / SEARCHING / QUEUED / CONNECTING / CONNECTED / SENDING
```

| 状态 | 含义 | 常见显示 |
|---|---|---|
| `UNKNOWN` | 只有 MAC，还没找到设备 | 未知设备 |
| `READY` | 已找到设备，空闲、未连接 | 就绪 |
| `SEARCHING` | 占位任务正在扫描寻人 | 寻找中 |
| `QUEUED` | 等连接窗口、传输窗口，或处在重试等待 | 排队中 |
| `CONNECTING` | 正在建立 GATT 连接 | 连接中 |
| `CONNECTED` | 已连接，空闲或保持连接 | 已连接 |
| `SENDING` | 正在发数据 | 发送中 + 进度 |

`TaskState` 只说明**现在在做什么**，不表示结果。SDK 没有 `FAILED` 状态，失败后任务会回到 `READY` 或 `UNKNOWN`。

## 每条命令都有结果

这是新版和旧版最大的区别：**不用再靠 `state + outcome + result + error` 四个字段去猜。**

```java
task.send(command, result -> {
    if (result.isSuccess()) {
        String payload = result.payload();   // 设备回执，可能为 null
    } else {
        TaskStage stage = result.stage();    // 失败发生在哪一步
        String error = result.error();
    }
});
```

`TaskStage` 的取值：

| stage | 含义 |
|---|---|
| `SEARCH` | 寻人超时，没扫到设备 |
| `CONNECT` | 连接失败、服务发现失败、认证失败 |
| `SEND` | 已连接，但发送失败或业务返回错误 |
| `CANCEL` | 被 `cancel()` 中止，或被 `disconnect()` 中止 |
| `DELETE` | 任务被 `delete()` 删除 |
| `BUSY` | 待办队列已满，命令没被接收 |
| `CLOSED` | 任务已删除，命令被拒绝 |

三条规则：

1. **每条被接收的命令，恰好回调一次**，不会重复也不会漏；
2. **回调在主线程**，可以直接更新 UI；
3. `payload` 是设备回显，成功也可能没有回显，不要用 `payload != null` 判断成功——**判断成功只看 `isSuccess()`**。

如果只需要刷新列表、不关心单条命令，用下面的快照字段：

```java
s.state();      s.outcome();    s.result();
s.error();      s.progress();   s.pendingCount();
```

## 命令被接收的规则

同一台设备同一时刻只发一条，后面的命令进待办队列，**不会覆盖正在执行的命令**。

| 当前状态 | 新命令 | 结果 |
|---|---|---|
| `CONNECTED` / `SENDING` | 连接 | 已满足，立即回调成功 |
| `SEARCHING` / `QUEUED` / `CONNECTING` | 连接 | 登记为等待者，连接结果出来时一并回调 |
| `SENDING` 或连接中各状态 | 发送 | 进待办队列；队列满回调 `BUSY` |
| `CONNECTED` 且空闲 | 发送 | 复用连接直接发 |
| `READY` / `UNKNOWN` 且空闲 | 发送 | 开始执行 |
| 任务已删除 | 任意 | 回调 `CLOSED` |

队列默认最多 8 条，用 `setMaxPendingIntents()` 调整。

## 命令

```java
QCommand.builder().send("{\"action\":\"echo\"}").build();          // 发 JSON
QCommand.builder().send(json, bytes).build();                      // 发 JSON + 单块字节
QCommand.builder().send(json, attachments).build();                // 发 JSON + 多附件
QCommand.builder().send(json).keepConnected().build();             // 发完保持连接
QCommand.builder().send(json).disconnectAfter().build();           // 发完明确断开
QCommand.builder().connect().build();                              // 只连接
```

发完断不断，判断顺序是：

```text
保持连接 = 命令没有声明 disconnectAfter
          且（任务上有「保持连接」期望 或 命令声明了 keepConnected）
```

`keepConnected()` 和 `disconnectAfter()` 互斥，同时调用会在 `build()` 抛 `IllegalStateException`。

有些设备（例如发完必须断开才让配置生效的屏）需要在已连接的任务上强制断开，这时用 `disconnectAfter()`，它优先于任务上的保持期望。

## 连接参数

连接参数不属于命令，而是任务的一个属性：

```java
task.setConnectParams(Collections.singletonMap("activeKey", key));
task.connect(callback);
```

设置一次，对该任务之后的所有连接生效。`QCommand` 上没有 `connectParams`。

## 取消、删除、断开

```java
task.cancel();      // 中止当前操作，任务保留
task.delete();      // 取消 + 断开 + 从任务池移除
task.disconnect();  // 真正断开，任务保留
```

区别在于**链路最后停在哪**：

| | `cancel()` | `delete()` | `disconnect()` |
|---|---|---|---|
| 中止当前操作 | 是 | 是 | 是（先 cancel） |
| 之后的链路 | 回到操作开始前的状态 | 断开 | 断开 |
| 任务留在池里 | 是 | 否 | 是 |
| 命令回调的 stage | `CANCEL` | `DELETE` | `CANCEL` |

`cancel` 的回退规则：操作开始前已连接、且正在发送，则只中止发送、保持连接；其余情况（寻人、排队、建连、重试等待，或操作开始前未连接）都断开回到未连接。

如果只是想让设备断开但保留任务（比如发完指令设备必须断开才生效），用 `disconnect()`，不要用 `delete()`。

## 观察任务

```java
// 只看这一台
Subscription s1 = task.observe(this, snapshot -> {
    // 每次状态变化回调一次不可变快照
});

// 看全部（列表页）
Subscription s2 = QingzhuSdk.observeAll(this, snapshots -> {
    adapter.render(snapshots);
});
```

`owner` 是弱引用，`Activity` / `Fragment` 回收后自动停止；也可以手动 `cancel()`。

`TaskSnapshot` 是不可变对象，**不要缓存旧快照当实时状态用**，每次回调都会给新的。

## 什么时候可以退出页面

### 单个设备

一次配置动作绑定一条命令，收到结果再决定：

```java
task.send(configCommand, result -> {
    if (result.isSuccess()) {
        finish();                    // 成功，退出
    } else {
        showError(result.stage(), result.error());   // 失败，留在页面
    }
});
```

`BUSY` 和 `CLOSED` 也会走这个回调，不需要额外判断——它们就是失败的一种。

### 多台设备

没有批量对象，就是一个循环加计数：

```java
List<String> macs = fetchTargets();
int total = macs.size();
AtomicInteger done = new AtomicInteger();
AtomicInteger failed = new AtomicInteger();

for (String mac : macs) {
    QTask task = QingzhuSdk.getTask(mac);
    if (task == null) task = QingzhuSdk.createTask(mac);

    task.send(configCommand, result -> {
        if (!result.isSuccess()) {
            failed.incrementAndGet();
        }
        if (done.incrementAndGet() == total) {
            finish();                        // 全部结束
            // 需要汇总时用 failed.get() 和 total
        }
    });
}
```

退出条件本质上是「**所有命令都回调过了**」。用计数比去轮询任务状态可靠。

要注意的等待时间：

- 设备在范围内：一般几秒内结束；
- 设备不在范围内：寻人 30 秒超时，之后重试，默认最多 3 次，可能等一两分钟；
- 所以配置页最好有「跳过 / 取消」入口，并在等待期间显示每台设备的当前状态。

## 回调线程

命令回调和任务观察回调都投递到主线程。不要在回调里做重活；需要解析大包时先入队，再交给工作线程。

下一步：[多设备调度](#android/sdk-guide/multi-device) · [协议插件](#android/sdk-guide/protocol-plugin)
