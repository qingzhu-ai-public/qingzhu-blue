---
title: 综合实战　做一个 iPhone 蓝牙温湿度计
slug: overview
order: 0
---

# 综合实战　做一个 iPhone 蓝牙温湿度计

手机 A 找到温湿度计并连接。点「请求新读数」，它写入一条指令，再把返回的字节显示成 `26.50 °C · 50.55% RH`。第二台 iPhone 可以用同一个 App 模拟温湿度计。

| 篇目 | 做完能看到什么 |
| --- | --- |
| [原型与工程入口](#ios/thermometer-mvp/prototype) | 点通原型，把 App 装到第一台 iPhone |
| [扫描篇](#ios/thermometer-mvp/scanning) | 在设备列表看到教学温湿度计 |
| [连接篇](#ios/thermometer-mvp/connection) | 详情页上的「请求新读数」亮起来 |
| [传输篇](#ios/thermometer-mvp/transfer) | 手机收到原始字节，显示温度和湿度 |
| [双机验收篇](#ios/thermometer-mvp/two-device-check) | 另一台 iPhone 模拟设备，验证正常收发与停止 |

每篇实现课先按文件给出完整代码，再跟着一次点击看系统调用、回调和界面变化。也可以直接打开 [Xcode 示例工程](https://github.com/qingzhu-ai-public/qingzhu-blue/tree/main/examples/ios/thermometer-mvp)。

iOS 示例用教学服务 UUID 发现设备，连接后使用自定义 GATT 协议收发。读取结果借用 [BTHome v2](https://bthome.io/format/) 的明文温湿度字段布局。iPhone 外设只在广播中提供设备名称和服务 UUID，温湿度在连接后取得。[Apple 广播 API](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager/startadvertising%28_%3A%29)
