---
title: 协议插件
order: 50
summary: 用 ProtocolPlugin 接入自有设备，不改内核扫描、连接和队列
tags: SDK,协议
updated: 2026-11-19
---

# 协议插件

## 核心原则

公共能力放内核，设备差异放协议：

| 层 | 负责 |
|---|---|
| core | 扫描、连接、GATT、命令队列、重试、超时、并发调度 |
| protocol | 广播识别、稳定身份、编解码、心跳、连接步骤 |

新增一种设备，不需要改 core 的任务池、连接池或扫描引擎。

## 最小接入

只实现两个方法就能跑起来：

```java
public final class MyProtocolPlugin implements ProtocolPlugin {

    @Override
    public ProtocolType protocolType() {
        return ProtocolType.of("my-device");   // 协议 id，进 registry 和路由
    }

    @Override
    public Recognizer recognizer() {
        return (record, name, device) -> {
            // 从广播里认出自家设备：填 metadata、返回 true 表示认领
            // 返回 false 交还给下一个协议
            return false;
        };
    }
}
```

注册：

```java
QingzhuSdk.registerProtocol(new MyProtocolPlugin());
```

`QingzhuSdk.getProtocols()` 可以查看当前已装配的协议 id。

公开示例：

- [GenericProtocolPlugin](https://github.com/qingzhu-ai-public/qingzhu-ble-android/blob/main/qingzhu-protocol-generic/src/main/java/com/qingzhu/protocol/generic/GenericProtocolPlugin.java)
- [EddystoneProtocolPlugin](https://github.com/qingzhu-ai-public/qingzhu-ble-android/blob/main/qingzhu-protocol-eddystone/src/main/java/com/qingzhu/protocol/eddystone/EddystoneProtocolPlugin.java)

## 契约全貌

除了上面两个必须实现的，其余都有默认实现：

| 方法 | 作用 | 默认 |
|---|---|---|
| `protocolType()` | 协议 id | 必须实现 |
| `recognizer()` | 识别广播并解析进 `QDevice` | 必须实现 |
| `identityKey()` | 声明身份存在哪个 metadata key，SDK 据此生成稳定 id | `null`，用 MAC |
| `beforeConnect()` | 建 GATT 之前的钩子，可重寻址、握手 | 直接放行 |
| `onGattReady()` | 发现服务后的钩子：找特征、使能通知、认证 | 直接就绪 |
| `connectSteps()` | 自定义整条连接流程（逃生舱） | `null`，走默认流程 |
| `heartbeatCommand()` / `heartbeatConfig()` | 长连接保活 | 不做心跳 |
| `removeBondOnDisconnect()` | 断开时是否解除系统配对 | `false` |
| `configurableParams()` | 暴露协议可配置项 | 空 |
| `scanConfig()` / `scanManufacturerIds()` | 协议级扫描参数与厂商 ID 硬件过滤 | `null` |
| `install()` | 注册后装配零件，例如注册 `ActionHandler` | 空 |

## 稳定身份

地址会轮换的设备，不要用 MAC 当身份：

```java
@Override
public String identityKey() {
    return "deviceSn";   // 广播里那个跨地址不变的字段
}
```

SDK 会用这个字段生成 16 位 `stableId`，任务寻人、UI 去重都用它。不要在协议里自己造 id，否则同一台设备会被当成两台。

## 发送与路由

命令是文本 JSON，大块数据（固件、图片）放附件里，不进字符串：

```text
task.send(cmd)
  → ActionRouter      按 protocolId 找到 handler
  → ActionHandler     解析 JSON 的 action 字段，按自己的约定取附件
  → JsonResponse      成功带 dataJson，失败带错误码与原因
```

每个协议只注册一个 `ActionHandler`，内部分发由协议自己实现。core 不解析消息内容、不预设字段——这是不同厂商能自由接入的前提。

如果协议没有注册 handler，路由会返回 `PROTOCOL_NOT_FOUND`（1201），不会崩溃。

## 连接前检查和心跳

协议可以声明：

- 连接前检查（缓存地址是否新鲜、要不要等重新广播）；
- 服务发现后的就绪检查；
- 心跳指令和应答判断；
- 主动断开后的重连策略。

这些步骤由插件定义，core 负责把它们放进串行连接和 GATT 队列。

## 插件是可选件

门面按类名装配协议，找不到类会当作正常情况跳过。所以：

- 客户不要再支持某类设备，**删掉对应 AAR 即可**，调用方代码不用改；
- 编译不报错，运行不崩溃；
- 对该设备的命令会明确失败（寻人超时，或返回协议未注册错误码）。

注意依赖关系：有的协议复用了另一个协议的加密实现（例如 TXP 依赖 V3）。删掉被依赖的那个，依赖方会失效——不会崩溃，但用不了。

## 插件边界

当前已经支持协议注册和装配，但还没有完成：

- 插件优先级；
- 冲突告警；
- 启停；
- 版本管理；
- 自动化测试。

所以不要把「插件化」理解成「插件之间已经完全隔离、永远不会冲突」。识别顺序就是注册顺序，先注册的先问。

## 给 AI 的接入提示词

最省事的做法不是让 AI 先写一套 BLE 状态机，而是把**设备协议文档、帧格式和示例数据**交给它，让它在 `ProtocolPlugin` 边界内实现识别、编解码、身份和心跳。

扫描、连接、队列、重试和并发调度已经在内核里，不需要重新实现。你只需要告诉它：

```text
1. 广播里哪些字节能认出这台设备 → recognizer()
2. 哪个字段是跨地址不变的 → identityKey()
3. 连接后要不要认证、要开哪个通知 → onGattReady()
4. 指令的 JSON 长什么样、大块数据放哪个 key → ActionHandler
```
