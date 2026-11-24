---
title: 线程、状态机、命令队列与取消
order: 240
summary: 一条连接交给一个地方管，按钮、回调和超时都来报消息，每个命令只结一次账。
tags: SDK,工程实践
updated: 2026-11-24
---

# 第 23 章　线程、状态机、命令队列与取消

手机还在给标签写图，用户点了取消。差不多同一时间，蓝牙断开，写入超时的计时器也响了。如果这三个入口都各自清理并通知页面，用户可能先看到「已取消」，又看到一条「失败」。

让同一个串行执行环境持有这次连接。按钮、定时器和蓝牙回调只把事件交给它，由它按顺序决定状态。**状态机**就是列出现在在哪一步、接下来允许去哪一步。取消或失败进入关闭流程以后，再来的事件按已经记录的状态处理。每个正在执行或排队的命令只交付一次最终结果。

```text
CONNECTING → DISCOVERING → CONFIGURING → READY
      任一状态遇到超时、断开或取消 → CLOSING → CLOSED
```

例如服务发现成功后才能配置订阅，订阅成功后才进入可发送状态。发 API 之前先记录自己正在等什么并设置期限。同步拒绝、成功回调、取消和超时都交给同一个处理入口，先更新内部状态再通知页面。即便页面收到结果后立刻发下一单，队列也已经准备好。

## 一次只提交一条属性操作

如果用户先改阈值又点刷新，应用可以先排两项，等第一项结束再发第二项。这就是命令队列。每项保存操作类型、目标对象、不可变的输入数据、会话代次、截止时间和调用者可见的结果。命令取出后发起 API，立即拒绝就终结。接受后等待与 GATT 实例、操作类型和目标属性相符的回调。通知、断开和链路参数事件分别处理。队列存储有限，满时向调用方返回明确的忙状态。

```text
submit → validate → enqueue
  → start next → rejected / wait callback
  → matching callback / timeout / cancel / disconnect
  → complete once → next or close session
```

`operationId` 用于本地日志和等待者，系统回调没有同一个 ID。GATT 实例相同、特征相同的两个写操作，靠回调参数往往无法区分先后。调用方取消等待也不会替它撤回已经进入协议栈的请求。能继续等终态时，保留在途槽位直到它真正完成。超时后无法得知终态时，结束该 GATT 会话再重试。

## 两块标签各排各的队，手机再限制总量

连接会话之间可并发。全局连接数量、同时建连数量和同时传输数量各有预算。先把扫描、建连和传输分阶段记录，资源紧张时限制占用最重的阶段。业务解码、磁盘 I/O 和大文件校验放到工作线程，结果再带代次回到会话。在 Android 26+ 可通过 Handler 指定旧式 GATT 回调线程，API 37+ 通过 Executor，其他版本在回调入口复制必要数据再投递。

测试时构造迟到回调、重复回调、同步拒绝、取消正在写的操作、连接失败后旧回调到达。检查每条命令只完成一次，旧代次没有推进新连接。[BLE 连接生命周期](#android/development-guide/connection-lifecycle) · [GATT 读写](#android/development-guide/characteristic-rw)

## 把串行环境落到代码

骨架不大，关键在「所有入口只投递，不直接改状态」：

```kotlin
private val worker = Handler(
    HandlerThread("ble-session").apply { start() }.looper
)

// 按钮、定时器、蓝牙回调都只做一件事：把事件投进同一个队列
fun onUserCancel() { worker.post { handle(Event.Cancel) } }
fun onWriteTimeout(opId: Long) { worker.post { handle(Event.Timeout(opId)) } }
override fun onCharacteristicWrite(gatt: BluetoothGatt, c: BluetoothGattCharacteristic, status: Int) {
    worker.post { handle(Event.WriteDone(gatt, c.uuid, status)) }
}

private var state = State.CONNECTING
private var generation = 0L          // 每次新建 GATT 递增
private var inflight: Command? = null
private val queue = ArrayDeque<Command>()

private fun handle(e: Event) {
    // 1. 先验代次：旧 GATT 的迟到事件直接丢弃并记日志
    // 2. 已进 CLOSING 的事件只走清理路径，不再推进状态
    // 3. WriteDone 要同时匹配 GATT 实例、操作类型、特征 UUID 才算 inflight 的终态
    // 4. 每条命令 complete 恰好一次：成功回调、同步拒绝、超时、取消四选一
    // 5. 完成后从 queue 取下一条；队列满时 submit 直接返回忙
}
```

`Command` 里带上不可变的输入字节、会话代次、截止时间和一个只允许调用一次的完成回调。`handle` 的五条注释就是实现清单，[第 27 章](#android/development-guide/test-lab)的模拟传输测试逐条验收它们。注意 `HandlerThread` 只是让事件串行，真正的等待仍靠系统回调；不要用 `Thread.sleep` 在队列里等结果，那会把后面所有事件堵住。

## 一句话总结

**一条连接交给一个地方管，按钮、回调和超时都来报消息，每个命令只结一次账。**

## 面试题

1. 发送时取消，是否能马上把当前 GATT 请求的位置让给下一条？
2. `operationId` 为什么配不上 Android 的写回调？
3. 内存里同时排了两项写，为什么还需要限制总队列长度？

### 参考答案

1. 已经提交到平台的请求可能还在进行。要等待明确终态，或结束旧会话再恢复队列。
2. 它是 App 生成的日志和等待标识，平台回调没有这个字段。归属按 GATT、操作种类和目标属性判断。
3. 队列有内存和等待时间成本。限制容量并返回忙，可以防止生产速度长期超过蓝牙处理速度。
