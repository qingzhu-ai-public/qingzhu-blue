---
title: 07　让跨端页面调用已有的原生蓝牙任务
slug: native-bridge
order: 80
---

# 07　让跨端页面调用已有的原生蓝牙任务

想给一组价签下发数据时，页面要能看到任务正排队、正在发送和最终结果。可以继续用 Flutter 画列表，由已有 Android SDK 控制建连窗口、排队和重试。先挑一台已知设备，把一条测试命令和两种回调打通。

## Android 端做一次任务

把 SDK 加进原生 Android 工程，按项目说明在应用启动时调用 `QingzhuSdk.init(applicationContext)`。提前准备好设备支持的协议插件和已授权的测试机。下面使用 SDK 文档里的 echo 命令，适用于接好对应回显协议的测试外设。

```java
QTask task = QingzhuSdk.getTask(mac);
if (task == null) {
    task = QingzhuSdk.createTask(mac);
}
Subscription progress = task.observe(owner, snapshot -> {
    publishProgress(snapshot.state().name(), snapshot.progress());
});
QCommand command = QCommand.builder().send("{\"action\":\"echo\"}").build();
task.send(command, result -> {
    progress.cancel();
    publishResult(result.isSuccess(), result.payload(), result.error());
});
```

`owner` 是原生宿主自己的订阅所有者。`mac` 来自 Android 扫描或业务登记。`publishProgress` 和 `publishResult` 是你在桥接层实现的出口。将阶段和进度送给页面，将本条命令的最终结果单独返回。这里用的是 SDK 的真实任务 API，桥接注册和宿主配置按下面的官方步骤接入。

## Flutter 端接回调

先订阅 `EventChannel('qingzhu/task-events')`，再用 `MethodChannel('qingzhu/task')` 的 `invokeMethod('runEcho', {'mac': mac})` 发起任务。原生 `MethodCallHandler` 从参数拿 MAC，提交后在最终回调调用 `result.success(...)` 或 `result.error(...)`。进度用 `EventSink.success(...)` 逐条送回 Dart。

先把 Android 平台的进度和终态各跑通一次。如果还要支持 iOS，由 iOS 宿主实现同一业务接口，设备标识和协议能力按 Core Bluetooth 的约束处理。页面退出时移除监听。下发任务是否继续由业务决定，取消监听只表示页面停止收消息。

**练习**　让测试设备离开范围。确认页面能区分正在连接、命令失败和已经恢复空闲。

**一句话**　页面像显示屏，原生 SDK 按次序把指令送到设备。

**面试题**　进度到 100%，可以直接把业务任务标成成功吗？

应看该条命令的 `TaskResult.isSuccess()`。进度表示任务推到哪一步。

[青竹 Android BLE SDK](https://github.com/qingzhu-ai-public/qingzhu-ble-android) · [Flutter 原生接入说明](https://docs.flutter.dev/platform-integration/platform-channels)
