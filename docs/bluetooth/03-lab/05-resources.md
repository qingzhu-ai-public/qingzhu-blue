---
title: 学习资源与参考索引
order: 40
summary: 官方规范、免费课程、平台文档与 GitHub 工具库的精选索引，每条说清用途和用法。
tags: 资源, 索引
updated: 2026-11-24
---

# 学习资源与参考索引

这一篇回答「学完这里，接下来去哪」。收录的都是本课程编写时实际参考、逐条核对过的资源，按用途分类，每条说清它解决什么问题、怎么用。遇到争议以规范为准，遇到具体问题先查厂商文档，博客用来补经验和思路。

## 官方规范与文档（最终依据）

| 资源 | 解决什么 | 怎么用 |
|---|---|---|
| [Bluetooth SIG 规范门户](https://www.bluetooth.com/specifications/specs/) | Core、CSS、GSS、各 Profile 规范原文，免费下载 | 字段几个字节、错误码什么含义，以这里为准 |
| [Assigned Numbers](https://www.bluetooth.com/specifications/assigned-numbers/) | 16 位 UUID、公司标识符、AD 类型等编号总表 | 见到四位编号先查它，持续更新 |
| [BLE Primer](https://www.bluetooth.com/bluetooth-le-primer/) | SIG 官方的 BLE 入门读本 | 想要官方口径的概念解释时读 |
| [技术概览](https://www.bluetooth.com/learn-about-bluetooth/tech-overview/) | 蓝牙全景、特性与用例的官方介绍 | 给非技术同事解释蓝牙时好用 |
| [SIG 博客](https://www.bluetooth.com/blog/) | 每版 Core 的发布说明和特性解读 | 每年 5 月、11 月新版本发布后看这里，比二手报道准 |

查规范的技巧：Core 在线版按卷分册，Vol 3 是主机（ATT/GATT/GAP/SM），Vol 6 是 LE 链路层；广播字段查 CSS，特征格式查 GSS。别通读，带着问题搜关键词。

## 系统性免费课程（建立框架）

- **[Nordic Developer Academy：Bluetooth LE Fundamentals](https://academy.nordicsemi.com/courses/bluetooth-low-energy-fundamentals/)**。免费，六课覆盖广播、连接、GATT、安全，每课带练习和测验。练习多数要 nRF 开发板，但第一课只要手机加 nRF Connect，和本课程的[无代码实验](#bluetooth/lab/nrf-connect-lab)路线一致。同系列还有低功耗设计课程，做电池产品值得学。中文有官方[博客版第一课](https://www.nordicsemi.cn/blog/bluetooth-le-fundamentals-lesson-1/)。
- **[Adafruit：Introduction to Bluetooth Low Energy](https://learn.adafruit.com/introduction-to-bluetooth-low-energy)**。Kevin Townsend 写的免费图文教程，GAP/GATT 概念讲解和配图非常清楚，2014 年首发、持续修订。概念部分不过时，涉及具体芯片产品的章节按今天的产品线看待。
- **[Silicon Labs：Bluetooth LE Fundamentals](https://www.silabs.com/documents/public/user-guides/ug103-14-fundamentals-ble.pdf)**（UG103.14，后续更新迁到 docs.silabs.com）。厂商视角的 BLE 基础，协议栈各层讲得工整，和 Nordic 课程互为印证。
- **[Novel Bits 博客](https://novelbits.io/)**。专注蓝牙的开发者博客，OTA DFU、连接参数、抓包分析这类工程专题很深。注意部分老文章基于已进入维护模式的 nRF5 SDK，新项目用 nRF Connect SDK，思路照搬、API 别照抄。

书的话，Kevin Townsend 等四人合著的《Getting Started with Bluetooth Low Energy》（O'Reilly，[Adafruit 有售](https://www.adafruit.com/product/1978)）仍是概念层最系统的 BLE 书，协议部分不过时，平台 API 部分以今天的官方文档为准。

## 平台官方文档（写代码时的依据）

- **Android**：[官方蓝牙文档](https://developer.android.com/develop/connectivity/bluetooth)，BLE 数据传输指南和 API 参考。本站 [Android 课程](#android)的附录 D 有按主题整理的官方链接索引。
- **iOS**：[Core Bluetooth 框架文档](https://developer.apple.com/documentation/corebluetooth)。做外设配件必读 [Accessory Design Guidelines](https://developer.apple.com/accessories/Accessory-Design-Guidelines.pdf) 的 BLE 章节，连接参数、广播间隔都有硬性要求；老技术问答 [QA1931](https://developers.apple.com/library/archive/qa/qa1931/_index.html) 把参数规则列成了公式，本课程[连接篇](#bluetooth/fundamentals/connection)引用了它。
- **Web**：[MDN Web Bluetooth](https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API) 查接口和浏览器兼容表，[Chrome 官方教程](https://developer.chrome.google.cn/docs/capabilities/bluetooth)带着写第一个页面。
- **HarmonyOS / Flutter / React Native**：见本站各平台课程的 API 速查，里面登记了对应官方来源。

## GitHub：调试工具

| 项目 | 用途 |
|---|---|
| [NordicSemiconductor/Android-nRF-Connect](https://github.com/NordicSemiconductor/Android-nRF-Connect) | 通用 BLE 调试 App 的源码和功能文档，[实验篇](#bluetooth/lab/nrf-connect-lab)的主力工具 |
| [nRF Sniffer for Bluetooth LE](https://www.nordicsemi.com/Products/Development-hardware/nrf-sniffer-for-802154-bluetooth-le) | 一个 nRF52840 Dongle 加官方固件就是空口抓包器，配 [Wireshark](https://www.wireshark.org/) 看包，排障性价比最高的硬件投入 |

## GitHub：客户端库（写脚本、做工具）

| 项目 | 语言/平台 | 用途 |
|---|---|---|
| [hbldh/bleak](https://github.com/hbldh/bleak) | Python，Win/mac/Linux | 异步 BLE 客户端，验证设备协议、写固件测试脚本的首选，[文档](https://bleak.readthedocs.io/)齐全 |
| [deviceplug/btleplug](https://github.com/deviceplug/btleplug) | Rust，跨桌面 | Rust 生态的跨平台 BLE 客户端 |
| [bluez/bluez](https://github.com/bluez/bluez) | C，Linux | Linux 官方蓝牙栈，bleak 等库的底层 |

移动端各平台的主流库（RxAndroidBle、Android-BLE-Library、flutter_reactive_ble、react-native-ble-manager 等）在本站平台课程里按章节介绍，不在此重复。

## GitHub：固件与外设侧（造一台自己的设备）

- **[ESP-IDF 蓝牙文档（中文）](https://docs.espressif.com/projects/esp-idf/zh_CN/latest/esp32/api-reference/bluetooth/index.html)**。ESP32 是最容易上手的 BLE 外设硬件之一，官方中文文档带 Bluedroid 和 NimBLE 两套协议栈的示例，GATT Server 示例改改就是自己的温度计。
- **[h2zero/NimBLE-Arduino](https://github.com/h2zero/NimBLE-Arduino)**。Arduino 生态的轻量 BLE 库，支持 ESP32 和 nRF5x，几十行代码广播一个传感器。
- **[arduino-libraries/ArduinoBLE](https://github.com/arduino-libraries/ArduinoBLE)**。Arduino 官方 BLE 库，配 Nano 33 BLE 等板子，入门门槛最低。
- **[BTHome](https://bthome.io/)**。传感器广播数据的开放标准，固件按格式发广播，Home Assistant 直接识别。本站 Android 综合实战做的就是它。

想继续挖，[0xor0ne/awesome-list 的 wireless 章节](https://github.com/0xor0ne/awesome-list)收录了协议栈、工具和安全研究的长清单，适合按图索骥。

## 怎么用这些资源

1. **建立框架**靠系统课程：本指南 + Nordic Academy 或 Adafruit 二选一精读。
2. **写代码**以平台官方文档为准，本指南平台课程负责把官方文档串成路线。
3. **解决具体问题**先搜厂商文档和 Novel Bits 这类专题博客，再不行抓包。
4. **裁决争议**回到 Core 规范原文，博客和教程（包括本指南）都只是导读。
5. **注意时效**：nRF5 SDK 已进维护模式、新项目用 nRF Connect SDK；老文章的 API 可能过时，协议原理不受影响。看文章先看日期和 SDK 版本。

## 一句话总结

**规范是法庭，官方文档是操作手册，系统课程是地图，博客是老司机的经验；按问题类型选资源，别拿博客当规范用。**