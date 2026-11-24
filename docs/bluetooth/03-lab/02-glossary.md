---
title: 术语表
order: 20
summary: 按主题分组的蓝牙缩写与概念，每个一句话，附正文入口。
tags: 速查
updated: 2026-11-24
---

# 术语表

按主题分组，每个术语一句话。读正文遇到不认识的缩写先来这里，想看细节再点进对应篇目。

## 基础与规范

| 术语 | 全称 / 展开 | 一句话 |
|---|---|---|
| BLE | Bluetooth Low Energy | 低功耗蓝牙，4.0 引入的传输方式，小数据低频次场景的主力。[01](#bluetooth/fundamentals/architecture) |
| BR/EDR | Basic Rate / Enhanced Data Rate | 经典蓝牙的传输方式，音频和存量串口设备在用。[01](#bluetooth/fundamentals/architecture) |
| 双模 | Dual-mode | 同时支持 BR/EDR 和 BLE 的设备，现在的手机基本都是。 |
| SIG | Bluetooth Special Interest Group | 维护蓝牙规范和认证的组织，规范文档都从 bluetooth.com 免费下载。 |
| Core | Core Specification | 核心规范，无线电到 GATT 的协议定义都在里面。 |
| CSS | Core Specification Supplement | 广播 AD 数据类型（Flags、名称、厂商数据等）的定义。 |
| GSS | GATT Specification Supplement | 标准特征的数据格式定义，温度湿度怎么编码查它。 |
| Assigned Numbers | — | SIG 分配的编号总表：16 位 UUID、公司标识符、错误码。 |

## 射频与链路

| 术语 | 全称 / 展开 | 一句话 |
|---|---|---|
| PHY | Physical Layer | 物理层。BLE 有 1M、2M、Coded 三种，速率和距离的取舍。[02](#bluetooth/fundamentals/versions) |
| 广播信道 | Advertising Channel | 37/38/39 三个信道专发广播，避开 Wi-Fi 常用频点。[04](#bluetooth/fundamentals/advertising) |
| AFH | Adaptive Frequency Hopping | 自适应跳频，连接在数据信道间切换躲干扰。 |
| 广播间隔 | Advertising Interval | 设备多久醒一次发广播，20 ms 到 10.24 s。 |
| 扫描窗口/间隔 | Scan Window / Interval | 手机每次听多久、多久听一次，决定扫到的速度。 |
| 连接事件 | Connection Event | 连接后两端按时同时醒来交换数据的时刻。[05](#bluetooth/fundamentals/connection) |
| Connection Interval | — | 相邻连接事件的间隔，7.5 ms 到 4 s（6.2 起可更低）。 |
| Peripheral Latency | — | 外设空闲时可跳过的事件数，省电用。 |
| Supervision Timeout | — | 多久收不到有效包判定断线，100 ms 到 32 s。 |
| DLE | Data Length Extension | 链路层载荷从 27 提到最高 251 字节，4.2 引入。[08](#bluetooth/communication/data-transfer) |
| RSSI | Received Signal Strength Indicator | 接收信号强度，受环境影响大，只适合参考不适合硬过滤。 |

## 协议与角色

| 术语 | 全称 / 展开 | 一句话 |
|---|---|---|
| Host / Controller | — | 协议栈上半段管语义、下半段管无线电时序，中间隔着 HCI。[01](#bluetooth/fundamentals/architecture) |
| HCI | Host Controller Interface | 主机与控制器之间的标准命令/事件接口，抓日志的关键层。 |
| L2CAP | Logical Link Control and Adaptation Protocol | 通道复用与分段，ATT 走它的固定通道，CoC 可自定义传输。 |
| ATT | Attribute Protocol | 属性读写协议，Read/Write/Notify 这些操作的字节格式。[06](#bluetooth/communication/gatt-att) |
| GATT | Generic Attribute Profile | 数据的组织方式（服务/特征/描述符）和访问流程。 |
| GAP | Generic Access Profile | 设备发现与连接的角色和流程。 |
| SM | Security Manager | 配对与密钥管理。[09](#bluetooth/communication/security) |
| Central / Peripheral | — | 发起连接方 / 接受连接方，GAP 角色。 |
| Broadcaster / Observer | — | 只发广播 / 只收广播，不建连接的 GAP 角色。 |
| Client / Server | — | 发起属性操作方 / 提供属性表方，GATT 角色，和 GAP 角色独立。 |
| MTU | Maximum Transmission Unit | 一条 ATT PDU 的最大长度，默认 23，有效值取两端较小者。 |
| EATT | Enhanced ATT | 5.2 引入的多承载 ATT，允许并发操作。 |

## GATT 对象与操作

| 术语 | 全称 / 展开 | 一句话 |
|---|---|---|
| Service | — | 一组相关特征的容器。 |
| Characteristic | — | 一项数据及其属性（Read/Write/Notify 等）。 |
| Descriptor | — | 特征的补充信息或配置项。 |
| Handle | — | 属性在设备属性表里的 16 位行号，只在本设备有效。 |
| UUID | Universally Unique Identifier | 类型编号。16 位是 SIG 标准简写，128 位自定义。[07](#bluetooth/communication/uuid-services) |
| CCCD | Client Characteristic Configuration Descriptor | UUID 0x2902，订阅开关，01 00 开 Notify、02 00 开 Indicate。 |
| Notify | Handle Value Notification | 设备主动发数据，无逐条确认。 |
| Indicate | Handle Value Indication | 设备主动发数据，协议栈逐条确认后才发下一条。 |
| Write Request / Command | — | 有响应写 / 无响应写，关键命令别用无响应。 |
| Long Read / Write | Read Blob / Prepare Write | ATT 标准的长值分段读写流程。 |
| CoC | L2CAP Connection-oriented Channel | 面向连接的自定义通道，credit 流控。 |

## 安全与隐私

| 术语 | 全称 / 展开 | 一句话 |
|---|---|---|
| Pairing | — | 建立共享密钥的过程。 |
| Bonding | — | 保存密钥供重连使用。 |
| LTK | Long Term Key | 重连后启用加密的密钥。 |
| IRK | Identity Resolving Key | 解析对方隐私地址、认出设备身份的密钥。 |
| RPA | Resolvable Private Address | 定期轮换的隐私地址，持有 IRK 才能解析。 |
| LE Secure Connections | — | 4.2 起的配对方案，ECDH 交换密钥。 |
| Just Works | — | 无交互配对，有加密无中间人防护。 |
| MITM | Man-in-the-Middle | 中间人攻击，Numeric Comparison/Passkey 可防。 |
| OOB | Out of Band | 通过 NFC 等带外通道辅助配对。 |

## 新能力与生态

| 术语 | 全称 / 展开 | 一句话 |
|---|---|---|
| LE Audio | — | 5.2 起的 BLE 音频体系，LC3 编码 + 等时信道。[02](#bluetooth/fundamentals/versions) |
| LC3 | Low Complexity Communication Codec | LE Audio 的标准编码器。 |
| Auracast | — | LE Audio 的广播音频，一对多收听。 |
| 等时信道 | Isochronous Channel | 为音频这类定时数据设计的传输通道。 |
| AoA / AoD | Angle of Arrival / Departure | 5.1 的测向手段，室内定位用。 |
| PAwR | Periodic Advertising with Responses | 5.4 的无连接双向一对多通信，电子价签场景。 |
| Channel Sounding | — | 6.0 的厘米级安全测距，相位测距 + 往返时间。 |
| BTHome | — | 传感器广播数据的开放标准，Home Assistant 生态开箱即用。[07](#bluetooth/communication/uuid-services) |
| Bluetooth Mesh | — | 独立的组网规范，架在 BLE 广播上做管理型泛洪，灯控和楼宇网络用，不属于 Core 版本号。[02](#bluetooth/fundamentals/versions) |
| Web Bluetooth | — | 浏览器直连 BLE 设备的 API，Chrome/Edge 系支持，iOS 不支持。[14](#bluetooth/lab/platform-map) |
| Robust Caching | — | 5.1 的 GATT 缓存机制，配合 Service Changed 处理固件升级后的服务表变化。 |

## 工具

| 术语 | 全称 / 展开 | 一句话 |
|---|---|---|
| nRF Connect | — | Nordic 的免费调试 App，扫描/连接/读写/订阅/模拟外设。[11](#bluetooth/lab/nrf-connect-lab) |
| HCI Snoop | — | Android 开发者选项里的 HCI 日志开关。 |
| Sniffer | — | 空口抓包器，如 nRF Sniffer、Ellisys，看实际发射的包。 |
| bleak | — | Python 跨平台 BLE 客户端库，写验证脚本和固件测试的顺手工具。[14](#bluetooth/lab/platform-map) |
| NimBLE | — | 轻量开源 BLE 主机栈，ESP32 和 Arduino 生态常用。[15](#bluetooth/lab/resources) |
| BlueZ | — | Linux 官方蓝牙协议栈，桌面 BLE 库的底层。 |