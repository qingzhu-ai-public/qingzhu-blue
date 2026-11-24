---
title: GATT 与 ATT 读写、通知和确认
order: 10
summary: 属性表、句柄与 UUID、五种操作的字节示例，分清每层成功各自确认了什么。
tags: GATT, ATT
updated: 2026-11-24
---

# GATT 与 ATT 读写、通知和确认

传感器连接后，手机需要读一次当前温度，并在温度变化时收到更新。固件可以提供一个自定义服务，把温度读数和采样间隔分别放在不同的特征里，手机按双方约定的 UUID 和数据格式访问它们。这一篇讲清连接里的数据世界：对象怎么组织、操作怎么往来、每种「成功」各自确认到哪一层。

## 从服务找到可以操作的值

| 对象 | 在例子里负责什么 |
|---|---|
| Service | 把温度读数和采样间隔组织在一起 |
| Characteristic | 提供一项具体数据及其属性。温度读数可以支持 Read 和 Notify，采样间隔可以支持 Write |
| Descriptor | 给某个特征补充信息或配置。支持 Notify 或 Indicate 的特征使用 CCCD 配置这些操作 |

设备把这些对象摆在一张**属性表**里，每行一个属性，有一个 16 位的**句柄**（Handle）作为行号。温度计的属性表可能长这样。

```text
句柄    类型 UUID   内容
0x0010  0x2800     Primary Service 声明（温度服务）
0x0011  0x2803     Characteristic 声明（温度读数，Read|Notify）
0x0012  自定义      温度读数 值
0x0013  0x2902     CCCD（温度读数的订阅开关）
0x0014  0x2803     Characteristic 声明（采样间隔，Write）
0x0015  自定义      采样间隔 值
```

两个编号体系别混：**UUID 表示类型**，全世界同一类数据用同一个 UUID；**句柄表示位置**，只在这台设备的这张表里有效。一个数据库里可能有多个相同 UUID 的实例（比如两路温度），靠句柄区分。固件升级可能改变句柄，客户端应按平台提供的服务发现和缓存更新机制处理，不要把句柄写死在代码里。

GATT Server 提供属性表，GATT Client 发起对这些属性的操作。温度传感器常同时是 GAP Peripheral 和 GATT Server，手机常同时是 GAP Central 和 GATT Client。两套角色分别描述连接关系和属性访问关系，同一条连接的两端都可以提供属性表——手机也能当 Server，比如给手表提供通知服务。

## 看清操作完成到哪一层

ATT 是真正跑腿的协议，每种操作有自己的字节格式。下面用温度例子过一遍最常见的五种，字节只展示 ATT 层。

```text
读温度      手机 → 温度计   0A 12 00        Read Request，读句柄 0x0012
            温度计 → 手机   0B 6A 09        Read Response，值 6A 09
写采样间隔  手机 → 温度计   12 15 00 3C 00  Write Request，向 0x0015 写 3C 00
            温度计 → 手机   13              Write Response
通知        温度计 → 手机   1B 12 00 6A 09  Handle Value Notification
指示        温度计 → 手机   1D 12 00 6A 09  Handle Value Indication
            手机 → 温度计   1E              Handle Value Confirmation
```

`6A 09` 是小端的 `0x096A`，即 2410，按 0.01 °C 单位解释就是 24.10 °C（这是 SIG 标准温度特征的编码，见[UUID 与标准服务](#bluetooth/communication/uuid-services)）。

| 操作 | 发起方向 | 协议层结果 |
|---|---|---|
| Read | Client → Server | Server 返回属性值或错误 |
| Write Request（有响应写） | Client → Server | Server 返回写入响应或错误 |
| Write Command（无响应写） | Client → Server | ATT 没有对应的写入响应 |
| Notify | Server → Client | ATT 不要求客户端逐条确认 |
| Indicate | Server → Client | Client 在 ATT 层返回确认，收到确认前 Server 不发下一条 Indicate |

「成功」分层是这一篇最重要的观念。写入采样间隔的命令可能先由通信模块接收，再交给设备任务保存和生效。Write Response 只说明 ATT 层接受了写入；如果业务要确认配置已经生效，约定一条带命令编号的结果消息，或读回当前配置。Indication 的确认同样只到 ATT 层——它由手机的蓝牙协议栈自动回复，App 甚至感知不到——应用是否处理并保存了温度还要看应用逻辑。无响应写连 ATT 层的确认都没有，适合高频、可丢的数据，别用来发关键命令。

## 出错了读哪个字节

操作失败时 Server 回 Error Response，格式是 `01 + 出错的操作码 + 句柄 + 错误码`。

```text
温度计 → 手机   01 12 15 00 05
                │  │  │     └ 错误码 0x05 Insufficient Authentication
                │  │  └ 出错的句柄 0x0015
                │  └ 出错的操作是 Write Request
                └ Error Response
```

意思是「向采样间隔的写入需要认证」。常见错误码先记这几个。

| 错误码 | 名称 | 指向 |
|---|---|---|
| `0x02` / `0x03` | Read / Write Not Permitted | 特征根本不允许这个操作，查属性声明 |
| `0x05` | Insufficient Authentication | 需要配对认证，见[配对与加密](#bluetooth/communication/security) |
| `0x0F` | Insufficient Encryption | 需要加密链路 |
| `0x08` | Insufficient Authorization | 设备应用层拒绝，查厂商授权流程 |

区分 `0x05`/`0x0F` 和 `0x08` 很有用：前者是蓝牙安全层的事，配对加密能解决；后者是设备业务层的事，配对了也没用，要走厂商的授权协议。

## 订阅成功后还要验证一次

CCCD 的 UUID 是 `0x2902`，通常由客户端配置。值 `0x0001` 启用 Notify，`0x0002` 启用 Indicate，`0x0000` 关闭（空口上小端传输，即 `01 00`、`02 00`、`00 00`）。设置前先看特征声明支持哪种模式，按平台 API 打开本地接收并完成远端设置——这是两件事，本地登记让系统把数据交给 App，写 CCCD 让设备开始发，缺一件都收不到。

订阅完成后，让传感器产生一个新的读数，再观察客户端是否收到、字节序是否解对。别把「CCCD 写成功」当作「链路通了」的证据，它只证明设备接受了订阅配置。

Android 的具体步骤见[服务发现](#android/development-guide/service-discovery)、[特征读写](#android/development-guide/characteristic-rw)和 [Notify、Indicate 与 CCCD](#android/development-guide/notify-cccd)。下一篇讲[一条温度记录装不下时怎么传](#bluetooth/communication/data-transfer)。

## 一句话总结

**UUID 认类型、句柄认位置；Read/Write 有来有回，Notify 免签收、Indicate 由协议栈签收；每种成功只确认自己那一层，业务生效要另外验证。**

## 面试题

1. 一台设备有两路温度特征，UUID 相同，客户端怎么区分它们？
2. Write Request 收到了 Write Response，能说明采样间隔已经生效吗？
3. Indicate 的确认是谁发的？App 需要写代码回这个确认吗？
4. 收到 `01 12 15 00 05`，逐字节解释，并说出下一步动作。
5. 订阅一个 Notify 特征，手机要做哪两件事？只做一件会怎样？

### 参考答案

1. 靠句柄。UUID 表示类型，句柄是属性表里的位置编号，服务发现返回的每个实例有自己的句柄。
2. 不能。Write Response 只确认 ATT 层接受了写入。配置是否保存生效，要读回配置或等业务回执。
3. 手机的蓝牙协议栈自动回复 Handle Value Confirmation，App 不参与。App 是否处理了数据是另一层的事。
4. `01` Error Response，`12` 出错的操作是 Write Request，`15 00` 句柄 0x0015，`05` 需要认证。下一步按设备要求完成配对或加密后重试。
5. 本地启用接收登记，远端写 CCCD 开启值。只登记本地，设备不会发；只写 CCCD，设备发了但系统不交给 App。两件都做完再触发一条新读数验证。

## 参考

[Bluetooth Core 6.2 GATT](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/generic-attribute-profile--gatt-.html) · [Bluetooth Core 6.2 ATT](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/attribute-protocol--att-.html)