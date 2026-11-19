---
title: RFCOMM 与 L2CAP Socket
order: 80
summary: RFCOMM 接通后收发的是一串字节，消息从哪儿开始、到哪儿结束，由双方协议约定。
tags: SDK,经典蓝牙
updated: 2026-11-19
---

# 第 7 章　RFCOMM 与 L2CAP Socket

串口模块已经配对。你想在手机上点「发送」，发一行 `PING`，让对方回一行 `PONG`。为了做到这一点，一端要准备好接电话，另一端要找到这一项服务并接通。

经典蓝牙常用 **RFCOMM** 来提供串口式字节流。服务端用 SDP 发布一个服务 UUID，然后监听连接。客户端拿同一个 UUID 创建 Socket 并连接。设备文档给了 SPP UUID 时按文档填。两端都是自己开发，就约定一个自己的 UUID，把它写进双方配置。

一次连接成功后，两端都能拿到输入流和输出流。手机写出的字节会到达对方的输入流，对方回复的字节再从手机的输入流读出来。

## 让两端接上这条字节流

| 方法 | 含义 | 结果与资源 |
| --- | --- | --- |
| `listenUsingRfcommWithServiceRecord(name, uuid)` | API 5，注册 SDP 记录并监听安全 RFCOMM | 返回 `BluetoothServerSocket`，持有到停止监听。 |
| `listenUsingInsecureRfcommWithServiceRecord(name, uuid)` | API 10，监听不要求认证链路的 RFCOMM | 与支持这种模式的对端搭配，评估冒充风险。 |
| `createRfcommSocketToServiceRecord(uuid)` | API 5，根据远端服务 UUID 准备安全客户端 Socket | 此时还未建连，随后调用 `connect()`。 |
| `createInsecureRfcommSocketToServiceRecord(uuid)` | API 10，准备不要求认证链路的 RFCOMM | 接入要求安全的外设时按其规定选择。 |
| `BluetoothServerSocket.accept()` / `accept(timeout)` | API 5，阻塞等待客户端，带参版本单位为毫秒 | 返回独立连接。关闭监听 Socket 可解除等待，已接收的连接单独关闭。 |
| `BluetoothSocket.connect()` | API 5，阻塞到建连成功或抛 `IOException` | 放在 I/O 工作线程，连接前调用 `cancelDiscovery()`。从另一线程 `close()` 可中止阻塞调用。 |
| `getInputStream()` / `getOutputStream()` | API 5，读写连接数据 | 读到 EOF、I/O 失败或取消时关闭 Socket。 |
| `getMaxReceivePacketSize()` / `getMaxTransmitPacketSize()` | API 23，查询传输的包大小 | 可用于缓冲规划，应用消息仍按协议解码。 |

现代系统的 Socket 操作需 `BLUETOOTH_CONNECT`，前置的 `cancelDiscovery()` 另行检查 `BLUETOOTH_SCAN`。以下客户端和服务端分别运行在两台设备的工作线程中。取消句柄由调用方保存并跨线程关闭。

```kotlin
// 服务端
adapter.listenUsingRfcommWithServiceRecord("Echo", serviceUuid).use { listener ->
    listener.accept().use { peer -> runEcho(peer) }
}

// 客户端
adapter.cancelDiscovery()
device.createRfcommSocketToServiceRecord(serviceUuid).use { socket ->
    socket.connect()
    exchangeFrame(socket)
}
```

## 读到几个字节，什么时候算一条消息

假设客户端连续写了两条消息。服务端调一次 `InputStream.read(buffer)`，可能刚读到第一条消息的一部分，也可能两条都在缓冲区里。要从字节流还原一条条消息，可以让发送端在每条消息开头放一个约定好的长度。

例如双方用 4 字节大端长度。接收方先用 `DataInputStream.readInt()` 读长度，检查范围，再用 `readFully(body)` 读够正文。所有发送动作交给一个写线程，让头和正文连续写完。超时或取消时从另一线程关闭连接，解除阻塞。`accept(timeout)` 只限制监听等客户端的时间，读消息需要另设期限。

## LE L2CAP CoC 与 SocketSettings

API 29 起，本机可用 `listenUsingL2capChannel()` 或 `listenUsingInsecureL2capChannel()`。`BluetoothServerSocket.getPsm()` 给出动态分配的 LE PSM，产品要安排对端如何取得它，例如在读特征时返回。客户端用 `createL2capChannel(psm)` 或 `createInsecureL2capChannel(psm)`，再调用 `connect()`。GATT UUID 和 PSM 是两个层次的标识。

API 36 起可以构建 `BluetoothSocketSettings`，用 `BluetoothAdapter.listenUsingSocketSettings(settings)` 或 `BluetoothDevice.createUsingSocketSettings(settings)`。Builder 根据 Socket 类型设置 RFCOMM UUID 或 LE PSM，以及认证、加密等选项。先核对所选类型的参数和权限条件，再走相同的 `accept/connect/close` 生命周期。

例如两端已约定同一个 RFCOMM 服务名及 UUID 时，可分别用以下设置创建监听和客户端 Socket。连接和读写仍在线程中执行，服务端先开始监听。

```kotlin
val settings = BluetoothSocketSettings.Builder()
    .setSocketType(BluetoothSocket.TYPE_RFCOMM)
    .setRfcommServiceName("Echo")
    .setRfcommUuid(serviceUuid)
    .setAuthenticationRequired(true)
    .setEncryptionRequired(true)
    .build()
// 服务端拿到 listener 后调用 accept()
val listener = adapter.listenUsingSocketSettings(settings)
// 客户端拿到 socket 后取消发现，再调用 connect()
val socket = device.createUsingSocketSettings(settings)
```

## 一句话总结

**RFCOMM 接通后收发的是一串字节，消息从哪儿开始、到哪儿结束，由双方协议约定。**

## 面试题

1. 客户端创建了 RFCOMM Socket，什么时候能开始写？
2. 为什么不能用一次 `read()` 判断收完了一条消息？

### 参考答案

1. 在 I/O 线程调用 `connect()` 并成功返回后再使用输出流。连接前按权限要求取消经典发现。
2. 一次读取的字节数取决于数据到达和缓冲区状态。接收端按长度或约定的边界拆帧。

[Android Socket 连接指南](https://developer.android.com/develop/connectivity/bluetooth/connect-bluetooth-devices) · [BluetoothSocket](https://developer.android.com/reference/android/bluetooth/BluetoothSocket) · [BluetoothSocketSettings.Builder](https://developer.android.com/reference/android/bluetooth/BluetoothSocketSettings.Builder)
