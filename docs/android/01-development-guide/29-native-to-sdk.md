---
title: 从原生 API 到 SDK 架构
order: 300
summary: 让业务说它要完成什么，让 SDK 负责每一步和资源的归属，失败时还能找到原始证据。
tags: SDK,架构
updated: 2026-11-24
---

# 第 29 章　从原生 API 到 SDK 架构

换图功能已经能跑。现在另一个页面也想用它，后台任务也想用它。三处都各写一套扫描、连接和关闭，最早遇到的问题可能是一个页面退出时把另一个任务正在用的扫描停了。

做成 SDK 时，先让业务只提交它真正想完成的事，比如「给这块标签换图」。SDK 收下这个任务，再依次找设备、连接、准备协议和发送。下层保留每一步的原始结果，上层可以取消任务、显示进度，或者解释为什么没成功。

## 页面和后台都要用，谁负责关连接

| 层 | 输入 | 输出与职责 |
| --- | --- | --- |
| Android 适配层 | 适配器、ScanResult、GATT、Socket | API 版本分支、立即结果、原始状态及关闭 |
| 会话层 | 设备句柄、用户意图 | 建连状态、服务表、在途操作、订阅、取消 |
| 协议层 | 广播/属性数据、版本和设备能力 | 身份识别、认证、命令编码、重组和回执 |
| 任务层 | 业务设备标识和操作 | 寻设备、资源调度、进度、幂等与终态 |
| 调用方 | 用户动作与系统生命周期 | 权限交互、持续任务的可见性、取消意图 |

例如设备列表和换图任务共用扫描。列表关闭，只撤掉列表自己的订阅。任务仍在找标签，就继续扫。等最后一个使用者离开，再停系统扫描。每个 GATT 由创建和持有它的会话负责关闭。协议插件只需要通过会话提供的传输入口收发数据，所需连接参数由配置明确传入。

## 任务失败时，给页面和排查人员各看什么

业务结果应有足够精度。例如 `ConnectFailed(status=133)` 和 `TransferAckTimedOut(messageId=17)` 给调用方的信息不同。向调试人员提供原始阶段和状态码，向用户界面提供对应的动作提示。返回忙、接受排队、已满足、完成、失败和取消时，用类型和文档定义状态能否重复、何时发最后一条事件。

应用已有业务协议时，接入 SDK 先做一个可追踪的最小命令。对照原生实现的时间线，确认 SDK 没吞掉立即错误或必需回调。随后再加批量调度和重试。这个顺序能让每一层出错时找到对应负责的代码。

## 任务接口最小长什么样

把上面的分层落成一个调用方能看懂的接口，核心是「提交意图、观察进度、拿到带阶段的终态」：

```kotlin
interface DeviceTasks {
    /** 提交一个业务任务，立即返回句柄；不阻塞调用线程。 */
    fun submit(task: TaskRequest): TaskHandle
}

data class TaskRequest(
    val deviceId: String,          // 业务身份，不是广播地址
    val operation: Operation,      // 例如 ReplaceImage(bytes, idempotencyKey)
    val timeoutMs: Long,
)

interface TaskHandle {
    val id: Long
    fun progress(): Flow<TaskProgress>   // Found / Connecting / Transferring(sent, total)
    suspend fun await(): TaskResult
    fun cancel()
}

sealed interface TaskResult {
    data class Completed(val deviceReply: ByteArray) : TaskResult
    data class Failed(val stage: Stage, val rawStatus: Int, val detail: String) : TaskResult
    data object Cancelled : TaskResult
    data object Busy : TaskResult        // 队列满，未受理
}
```

三个设计决定值得注意。`deviceId` 用业务身份，寻设备和地址轮换由 SDK 内部处理（[第 20 章](#android/development-guide/address-privacy)）。`Failed` 同时带 `stage` 和 `rawStatus`，页面据此提示用户，排查的人据此查日志，一份结果两种读法。`Busy` 是独立终态而不是失败——调用方可以稍后重提，不会和「设备拒绝」混在一起。

`Operation` 里带幂等键，重试时 SDK 复用同一个键，设备按[第 21 章](#android/development-guide/fragmentation-flow)的规则识别重复任务。会话和命令队列（[第 23 章](#android/development-guide/thread-state-machine)）藏在 `TaskHandle` 后面，调用方不需要知道 GATT。

本站的 SDK 指南就是按这个结构展开的：[青竹蓝牙 SDK 总览](https://qingzhu-ai-public.github.io/qingzhu-blue/#android/sdk-guide/overview)到[协议插件](https://qingzhu-ai-public.github.io/qingzhu-blue/#android/sdk-guide/protocol-plugin)，每篇对应一层职责。

[线程与命令队列](#android/development-guide/thread-state-machine)

## 一句话总结

**让业务说它要完成什么，让 SDK 负责每一步和资源的归属，失败时还能找到原始证据。**

## 面试题

1. 为什么 SDK 不宜只给调用方返回统一的「蓝牙失败」？
2. 页面离开、后台任务仍用同一轮扫描，应该怎样关闭？

### 参考答案

1. 不同阶段要采取不同处理。保留失败阶段和原始状态，调用方才能提示用户开启蓝牙、重试连接或查业务回执。
2. 页面撤销自己的订阅，由扫描所有者在最后一个使用者结束时调用系统停止方法。
