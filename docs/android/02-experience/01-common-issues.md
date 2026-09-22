---
title: 常见问题排查
order: 30
summary: GATT 133、扫描不到设备、Notify 丢包、MTU 协商失败的原因与处理
tags: 排查
updated: 2026-09-22
---

# 常见问题排查

这一篇是排错手册，按「症状 → 原因 → 处理」组织。每个结论都来自真机复现，不是文档转述。

## GATT 133：连不上的万能背锅侠

`onConnectionStateChange` 里拿到 `status = 133`（`GATT_ERROR`）是最常见的报错，但它的含义是「GATT 层出了点事」，**具体原因得靠排除法**。按命中概率从高到低：

| 原因 | 判据 | 处理 |
|---|---|---|
| 上一次连接没关干净 | 同一个 device 反复连 | 每次 `connectGatt` 前先 `close()` 旧 gatt，并让 App 单例持有唯一连接 |
| 连接时正在扫描 | 扫描未停就发连接 | `stopScan()` 之后再 `connectGatt`，中间隔 ~200ms |
| 距上次断开太近 | 断开后立刻重连 | 重连加退避（≥500ms 起，指数增长） |
| 设备侧只允许一个连接 | 换台手机能连 | 设备侧先断开旧连接 |
| 系统缓存了旧状态 | 重启 App 就好 | 只能缓解，根治还是靠连接复用 |

**最有效的单一改动**：把「连接」封装成单例 + 状态机，禁止并发 `connectGatt`。玄学报错会消失一大半。

```kotlin
// 错误示范：每次点击都新建一个连接
fun onClick() { device.connectGatt(ctx, false, cb, TRANSPORT_LE) }

// 正确：全局唯一连接 + 断开后置空
object GattHolder {
    private var gatt: BluetoothGatt? = null
    fun connect(device: BluetoothDevice, ctx: Context, cb: BluetoothGattCallback) {
        close()
        gatt = device.connectGatt(ctx, false, cb, BluetoothDevice.TRANSPORT_LE)
    }
    fun close() { gatt?.close(); gatt = null }
}
```

## 扫描不到设备

按顺序查，前面的排掉再查后面的：

1. **系统定位开关**（Android 6–11）：关了就是扫不到，且不报错。
2. **权限**：`BLUETOOTH_SCAN` 是否授予？用 `checkSelfPermission` 确认，别看清单。
3. **扫描过滤条件**：`ScanFilter` 里的 UUID 是**广播包里的** UUID，不是 GATT Service 的 UUID。很多设备广播包里不带 Service UUID，设了过滤就永远为空。
4. **广播类型**：设备只发 `SCAN_RSP` 而不是 `ADV_IND` 时，某些 ROM 默认不上报。试试 `SCAN_MODE_LOW_LATENCY`。
5. **回调频率**：同一设备在 `onScanResult` 里默认只回调一次，需要 `setReportDelay(0)` 或去重后自己刷新列表。

`ScanSettings` 三个模式的区别：

| 模式 | 功耗 | 延迟 | 用在哪 |
|---|---|---|---|
| `LOW_POWER` | 最低 | 高 | 后台长期监听 |
| `BALANCED` | 中 | 中 | 常规扫描 |
| `LOW_LATENCY` | 最高 | 最低 | 用户点「搜索」时的前台扫描 |

**扫描必须自己设超时**。API 不会帮你停，用户忘关页面就是持续耗电，一晚上掉 30% 电量的投诉都来自这里。

## Notify 收不到 / 丢包

先确认订阅真的成功了：**必须等到 `onDescriptorWrite` 回调**才算订阅完成。很多人 `writeDescriptor` 之后立刻发指令，设备那边 CCCD 还没写进去，自然没有推送。

丢包的常见原因：

- **单包超长**：默认 MTU 23，扣除 3 字节 ATT 头，实际可用 20 字节。业务数据超过 20 字节就必须自己分包，且设备侧要能识别边界。
- **主线程阻塞**：`onCharacteristicChanged` 回调在 binder 线程，往里做重活会拖慢后续包。**只做入队，解析另开线程**。
- **复用 byte 数组**：回调里的 `value` 数组可能被复用，必须立刻拷贝一份再处理：

```kotlin
override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic) {
    val data = c.value.copyOf()   // 🔴 不 copy 就会在下一包到来时被改写
    queue.offer(data)
}
```

## MTU 协商

```kotlin
// 请求 517，实际以 onMtuChanged 为准
gatt.requestMtu(517)

override fun onMtuChanged(g: BluetoothGatt, mtu: Int, status: Int) {
    val payload = mtu - 3   // 3 字节 ATT 头，别忘
}
```

- 请求值不等于生效值：设备侧和系统都会向下取整，**必须用回调里的 `mtu` 反算可用长度**。
- Android 14 起系统把可协商上限提到 517，低于 14 的机器通常上限 512。
- 协商失败（`status != GATT_SUCCESS`）时不要死等，按 23 继续跑，功能降级比卡死好。

## 一个通用排查手法

线上问题无法复现时，**先抓 HCI 日志**：

```
开发者选项 → 启用蓝牙 HCI 信息收集日志
/data/misc/bluetooth/logs/  →  btsnoop_hci.log
```

用 Wireshark 打开这份日志，能看到完整的 ATT 交互：到底有没有发 CCCD 写请求、设备有没有回 ACK、MTU 协商到多少。**比在应用层打十行日志有用得多**。
