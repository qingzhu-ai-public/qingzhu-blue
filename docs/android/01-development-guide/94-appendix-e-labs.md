---
title: 附录 E 实验手册
order: 360
summary: 用两台 Android 8.0 或更高的手机。至少一台支持 BLE 外设广播。外设开 GATT Server 和可连接广播…
tags: SDK,附录
updated: 2026-11-19
---

# 附录 E　实验手册

## 双机 BLE Echo

用两台 Android 8.0 或更高的手机。至少一台支持 BLE 外设广播。外设开 GATT Server 和可连接广播，客户端扫描指定 UUID、发现服务、写 CCCD、写入固定字节、比较 Server 发回的通知。两个角色含 API 33 前后的写入和通知分支。实验只接受一个客户端并控制数据长度在默认 MTU 的单操作预算内。

| 源码 | 阅读点 |
| --- | --- |
| [AndroidManifest.xml](../code/ble-echo/AndroidManifest.xml) | BLE 功能、旧版位置权限和附近设备权限 |
| [EchoActivity.java](../code/ble-echo/EchoActivity.java) | 角色、授权、适配器、启停与页面生命周期 |
| [EchoClient.java](../code/ble-echo/EchoClient.java) | 扫描窗口、按阶段超时、发现、CCCD、写回调和通知 |
| [EchoServer.java](../code/ble-echo/EchoServer.java) | 先建表再广播、按请求应答及按客户端订阅 |

### 构建和安装

Windows 的 [构建脚本](../code/ble-echo/构建.ps1) 使用 JDK 17+、Android SDK Platform 36 和 Build Tools 37.0.0。运行时在系统临时目录产生 APK 和仅供实验的签名，输出可安装 APK 的路径。以下命令从课程根目录 `courses/android-bluetooth/` 运行。

```powershell
$apk = & ".\code\ble-echo\构建.ps1"
adb devices
$serverSerial = '填外设序列号'
$clientSerial = '填客户端序列号'
adb -s $serverSerial install $apk
adb -s $clientSerial install $apk
```

每次运行脚本会生成新的实验签名。同一次构建的 APK 安装到两台手机。需覆盖安装已有实验 App 时，使用原 APK 或按测试设备流程先卸载旧实验 App。也可以在 Android Studio 建一个空应用模块，设置 `namespace/applicationId = guide.bluetooth.echo`、`minSdk = 26`、`targetSdk = 36` 和 `compileSdk >= 36`，把三个 Java 文件放到对应包路径，合并清单中的权限和 Activity。使用 Gradle 配置 SDK 版本时，从清单中去掉 `uses-sdk`，以应用模块配置为准。

1. 两台手机打开应用，允许所选角色需要的权限。API 30 以下含 30 的扫描端要检查系统位置是否开启。
2. 一台点「启动外设」，等广播启动。实验期间保持页面在前台。
3. 另一台点「扫描并验证回声」。记录扫描、连接、发现、订阅和发送的阶段。
4. 客户端出现「通过，GATT 写成功且通知回声一致」。外设端观察通知发送回调。接着停止外设广播。
5. 用 `adb -s <序列号> logcat -s GuideBleEcho` 观察两端日志。比较客户端写回调和回声通知的到达顺序。

客户端等待 GATT 写成功及字节一致的回声。两者任意先到都可完成。实验退出页面就关闭连接和广播。由于没有业务鉴权，使用测试环境和固定字节即可。

### 制造能够定位的失败

- 外设停止，扫描端再开始。预期在扫描阶段超时。
- 将外设的特征 UUID 改掉但保留广播服务 UUID，单独构建外设。预期扫描和建连成功，发现阶段说明目标特征不存在。
- Server 拒绝 CCCD 写。预期客户端收到描述符失败，后续未写特征。
- 改动 Server 通知的固定字节，预期客户端明确报告内容不符。
- 在扫描中点「停止」并立即重开。核对上一轮的回调不会推进下一轮。

## 经典蓝牙 Socket 对照

见 [RFCOMM](#android/development-guide/rfcomm-socket)。两端约定服务 UUID 和长度前缀，服务端先阻塞在 `accept()`，客户端取消发现后在另一条线程 `connect()`。依次发送一条短消息、两条连续消息、一条拆成多次写的消息。接收侧要按消息长度切分。等待输入时从另一线程关闭连接，确认阻塞结束并收口。

## 证据实验

从 [抓包章节](#android/development-guide/hci-log) 取一次 Echo 成功和一次 CCCD 失败的报告。成功应能对出服务准备、CCCD 配置、特征写和回声通知。失败应有明确的错误位置。想研究 MTU，在适用版本上单独调用 `requestMtu` 并记录 `onMtuChanged` 和 HCI 中交换值，用 [MTU 章节](#android/development-guide/mtu-phy-dle) 的公式解释实际数据预算。
