---
title: 附录 D 官方文档、规范与版本基线
order: 350
summary: 以下列出正文涉及的主要变化。方法初次提供或弃用的版本以 [签名索引](附录B-API速查.md) 中的重载为单位查询。
tags: SDK,附录
updated: 2026-11-19
---

# 附录 D　官方文档、规范与版本基线

## 按问题找一手资料

| 问题 | 来源 |
| --- | --- |
| 普通应用怎么开始、需要什么权限 | [Android 蓝牙总览](https://developer.android.com/develop/connectivity/bluetooth) · [蓝牙权限](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions) |
| BLE 怎样扫描、连接和在后台工作 | [BLE 概览](https://developer.android.com/develop/connectivity/bluetooth/ble/ble-overview) · [查找 BLE 设备](https://developer.android.com/develop/connectivity/bluetooth/ble/find-ble-devices) · [后台通信](https://developer.android.com/develop/connectivity/bluetooth/ble/background) |
| 某个方法的真实签名与权限 | [android.bluetooth](https://developer.android.com/reference/android/bluetooth/package-summary) · [android.bluetooth.le](https://developer.android.com/reference/android/bluetooth/le/package-summary) · [伴生设备](https://developer.android.com/reference/android/companion/package-summary) · [测距](https://developer.android.com/reference/android/ranging/package-summary) |
| 手机和外设为何出现不同协议现象 | [Bluetooth Core 6.2](https://www.bluetooth.com/specifications/specs/core-specification-6-2/) · [Assigned Numbers](https://www.bluetooth.com/specifications/assigned-numbers/) |
| Android 栈的实现与诊断 | [AOSP Bluetooth 模块](https://android.googlesource.com/platform/packages/modules/Bluetooth/) · [AOSP 调试指南](https://source.android.com/docs/core/connect/bluetooth/verifying_debugging) |
| FGS、音频和测距如何接入 | [前台服务类型](https://developer.android.com/develop/background-work/services/fgs/service-types) · [LE Audio](https://developer.android.com/develop/connectivity/bluetooth/ble-audio/overview) · [设备测距](https://developer.android.com/develop/connectivity/ranging) |

## 平台版本沿革

以下列出正文涉及的主要变化。方法初次提供或弃用的版本以 [签名索引](#android/development-guide/appendix-b-api) 中的重载为单位查询。

| API | 与本书相关的变化 |
| --- | --- |
| 5 / 10 / 11 | 经典蓝牙、非安全 RFCOMM 重载、Profile proxy 陆续提供。 |
| 18 / 19 | GATT Client、Server 与公开配对入口。 |
| 21 / 23 | BLE Scanner、Advertiser 和 MTU 等功能。API 23 有 transport 选择及运行时权限模型。 |
| 26 | 扩展/周期广播、扫描 PendingIntent、PHY、带 Handler 的 GATT 连接、Companion 配对。 |
| 29 | LE L2CAP CoC Socket。在 Android 10–11 上留意后台位置。 |
| 31 | 附近设备权限，Service Changed 回调，后台 FGS 限制。 |
| 33 | GATT 显式字节数组重载和回调。限制普通新目标应用调用 adapter 的 enable/disable。 |
| 34 | Android 14 MTU 请求行为变更。target 34+ 的前台服务类型约束。 |
| 35 | 公开 `GATT_CONNECTION_TIMEOUT`。 |
| 36 / 36.1 | 测距、SocketSettings、新的 Companion presence 请求。36.1 加入 LE Subrate 及扫描配置。 |
| 37 / 37.2 | 基于设置对象和 Executor 的 GATT 连接。37.2 增加建连阈值和公开连接参数回调等。 |

[API 37 蓝牙差异报告](https://developer.android.com/sdk/api_diff/37/changes/pkg_android.bluetooth) · [API 37.2 蓝牙差异报告](https://developer.android.com/sdk/api_diff/37.2/changes/pkg_android.bluetooth) · [SDK 发布与下载](https://developer.android.com/studio/intro/update#sdk-manager)

## 如何扩展和核对 API 索引

使用官方 SDK Platform 目录中的 `android.jar`、`data/api-versions.xml` 和 `data/annotations.zip`。签名从公开 stub 获取，XML 给出按重载记录的版本及权限注解。索引收录 SDK 公开方法、构造器、字段，以及部分类中覆盖的蓝牙接口或关闭方法。Object 与 Parcelable 的常规继承成员可在官方类参考查看。

安装新平台后，在书稿目录执行下列命令，需要 Python 3.9+ 和 JDK 的 `javap`。生成目录和文档入口由脚本定位。

```powershell
python "API参考/生成索引.py" "F:/asdk/platforms/android-37.2"
```

生成后比较新增、删除、弃用和注解变化，再按需要更新对应正文的参数、权限和回调说明。小版本判断按 `Build.VERSION.SDK_INT_FULL` 和 `Build.VERSION_CODES_FULL`，使用普通 `SDK_INT` 时只能判断主 API。权限注解是线索，实际适用条件仍要核对方法文档。

```kotlin
// compileSdk 使用 36.1 或更高平台。先检查主版本，再读小版本字段。
if (Build.VERSION.SDK_INT >= 36 &&
    Build.VERSION.SDK_INT_FULL >= Build.VERSION_CODES_FULL.BAKLAVA_1
) {
    scanBuilder.setScanType(ScanSettings.SCAN_TYPE_PASSIVE)
}
```

核对厂商表现时，在 行业经验库 保留复测环境、证据和发布日期。引用 AOSP 具体实现时尽量使用固定提交链接，便于回看。
