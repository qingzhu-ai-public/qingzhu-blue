---
title: 快速接入
order: 20
summary: 克隆工程、接入源码模块、初始化、扫描和提交第一条任务
tags: 必读,接入
updated: 2026-11-17
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

## 6. 提交第一条任务

```java
QCommand command = QCommand.builder()
        .send("{\"action\":\"echo\",\"text\":\"hello\"}")
        .keepConnected(false)
        .build();

QTask task = QingzhuSdk.submit("AA:BB:CC:DD:EE:FF", command);
```

只给 MAC 也可以：SDK 会先扫描寻人，再自动连接和发送。

## 7. 订阅任务状态

```java
QingzhuSdk.subscribe(tasks -> {
    for (QTask task : tasks) {
        String state = task.getState().name();
        int progress = task.getProgress();
        String error = task.getError();
    }
});
```

## 8. 构建与测试

```bash
./gradlew :qingzhu-core:testDebugUnitTest
./gradlew :qingzhu-demo-main:assembleDebug
```

下一步：[任务与意图](#android/sdk-guide/task-and-intent) · [多设备调度](#android/sdk-guide/multi-device)
