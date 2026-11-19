---
title: 快速接入
order: 20
summary: 克隆工程、接入源码模块、初始化、扫描和发出第一条命令
tags: 必读,接入
updated: 2026-11-19
---

# 快速接入

## 1. 克隆工程

```bash
git clone https://github.com/qingzhu-ai-public/qingzhu-ble-android.git
cd qingzhu-ble-android
```

公开仓库当前以**源码模块**接入为主，不提供宿主 AAR。

## 2. 引入模块

```groovy
// settings.gradle
include ':qingzhu-core'
include ':qingzhu-company-sdk'
include ':qingzhu-protocol-generic'
include ':qingzhu-protocol-eddystone'
```

```groovy
// app/build.gradle
dependencies {
    implementation project(':qingzhu-company-sdk')
}
```

`qingzhu-company-sdk` 是唯一源码门面；协议模块由门面初始化时装配。

## 3. 权限

```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

Android 12 及以上动态申请扫描/连接权限；Android 11 及以下还需要定位权限和系统定位开关。

## 4. 初始化

```java
public class App extends Application {
    @Override
    public void onCreate() {
        super.onCreate();
        QingzhuSdk.init(this);
    }
}
```

重复调用 `init()` 幂等。

## 5. 扫描

```java
QingzhuSdk.startScan(
        ScanOptions.builder()
                .setTimeoutMs(30_000)
                .setMinRssi(-80)
                .setNamePrefix("ESL")
                .addProtocol("generic")
                .build(),
        new QSdk.ScanListener() {
            @Override
            public void onDevices(List<QDevice> devices) {
                // 用 stableId 去重，不要只依赖 MAC
            }

            @Override
            public void onScanFailed(int errorCode, String message) {
                // 权限、蓝牙关闭或系统扫描失败
            }
        }
);
```

`ScanOptions` 的过滤只作用于 UI 回调，任务池仍然接收完整广播，不影响自动寻人和重寻址。

停止扫描：

```java
QingzhuSdk.stopScan();
```

## 6. 发出第一条命令

```java
QTask task = QingzhuSdk.createTask("AA:BB:CC:DD:EE:FF");

task.send(
        QCommand.builder()
                .send("{\"action\":\"echo\",\"text\":\"hello\"}")
                .build(),
        result -> {
            if (result.isSuccess()) {
                Log.i("SDK", "回执：" + result.payload());
            } else {
                Log.w("SDK", "失败于 " + result.stage() + "：" + result.error());
            }
        }
);
```

只给 MAC 也可以：SDK 会先扫描寻人，再自动连接和发送。

> `createTask()` 会先删除该设备已有的任务再新建。页面里多次点击同一个按钮时，如果希望复用已有任务（保留已建立的连接），改用 `getTask(mac)`，没有才创建。

## 7. 观察任务状态

列表页用池级观察，注册后立即推一次全量快照：

```java
Subscription sub = QingzhuSdk.observeAll(this, snapshots -> {
    for (TaskSnapshot s : snapshots) {
        TaskState state = s.state();
        int progress = s.progress();
        String error = s.error();
    }
});

// 页面销毁
sub.cancel();
```

`owner` 传 Activity 或 Fragment 时，被回收后自动停止回调。

单个页面的退出时机见 [任务与命令：什么时候可以退出页面](#android/sdk-guide/task-and-command)。

## 8. 构建与测试

```bash
./gradlew :qingzhu-core:testDebugUnitTest
./gradlew :qingzhu-demo-main:assembleDebug
```

下一步：[任务与命令](#android/sdk-guide/task-and-command) · [多设备调度](#android/sdk-guide/multi-device)
