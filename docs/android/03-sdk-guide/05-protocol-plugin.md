---
title: 协议插件
order: 50
summary: 用 ProtocolPlugin 接入自有设备，不改内核扫描、连接和队列
tags: SDK,协议
updated: 2026-11-17
---

# 协议插件

## 核心原则

公共能力放内核，设备差异放协议：

| 层 | 负责 |
|---|---|
| core | 扫描、连接、GATT、队列、重试、超时、批量调度 |
| protocol | 广播识别、稳定身份、编解码、心跳、连接步骤 |

新增一种设备，不需要改 core 的任务池、连接池或扫描引擎。

## 最小接入

实现 `ProtocolPlugin`，然后注册：

```java
public final class MyProtocolPlugin implements ProtocolPlugin {
    @Override
    public ProtocolType protocolType() {
        return ProtocolType.of("my-device");
    }

    // 广播识别、身份字段、编解码、心跳等按接口声明实现
}

QingzhuSdk.registerProtocol(new MyProtocolPlugin());
```

公开示例：

- [GenericProtocolPlugin](https://github.com/qingzhu-ai-public/qingzhu-ble-android/blob/main/qingzhu-protocol-generic/src/main/java/com/qingzhu/protocol/generic/GenericProtocolPlugin.java)
- [EddystoneProtocolPlugin](https://github.com/qingzhu-ai-public/qingzhu-ble-android/blob/main/qingzhu-protocol-eddystone/src/main/java/com/qingzhu/protocol/eddystone/EddystoneProtocolPlugin.java)

## 稳定身份

地址会轮换的设备，不要用 MAC 当身份。协议需要声明稳定身份字段，SDK 会生成跨地址不变的 `stableId`，任务寻人、UI 去重和批次统计都用它。

## 连接前检查和心跳

协议可以声明：

- 连接前检查（例如缓存地址是否新鲜、是否需要等待重新广播）；
- 服务发现后的就绪检查；
- 心跳指令和应答判断；
- 主动断开后的重连策略。

这些步骤由插件定义，core 负责把它们放进串行连接和 GATT 队列。

## 插件边界

当前已经支持协议注册和装配，但还没有完成：

- 插件优先级；
- 冲突告警；
- 启停；
- 版本管理；
- 自动化测试。

所以不要把“插件化”理解成“插件之间已经完全隔离、永远不会冲突”。

## 给 AI 的接入提示词

最省事的做法不是让 AI 先写一套 BLE 状态机，而是把设备协议文档、帧格式和示例数据交给它，让它在 `ProtocolPlugin` 边界内实现识别、编解码、身份和心跳。

扫描、连接、队列、重试和批量调度已经在内核里，不需要重新实现。
