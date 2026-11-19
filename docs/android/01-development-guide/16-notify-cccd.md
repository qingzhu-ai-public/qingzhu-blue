---
title: 让手机上的温度自动更新（Notify、Indicate 与 CCCD）
order: 170
summary: 把温度计发数据想成投递，CCCD 是手机填给温度计的订阅单，Notify 是免签收投递，Indicate 要由手机的蓝牙系统…
tags: SDK,BLE
updated: 2026-11-19
---

# 第 16 章　让手机上的温度自动更新（Notify、Indicate 与 CCCD）

温度计已经连上了。你点一下「刷新」，手机显示 `24.1°C`。过一会儿，温度计上的数字变成了 `24.6°C`，手机上还是 `24.1°C`。再点一次，手机才拿到新读数。

到这里，你已经用上了蓝牙的**读取**。手机问一次，温度计答一次。如果用户只想看一眼当前温度，这就够了。现在给页面加个「自动更新」开关。打开以后，温度计有新数据就可以主动发，手机收到后更新数字。

## Notify 让设备主动发数据

温度计在蓝牙连接中提供了一个可以传数据的项目，叫做**特征**（Characteristic）。这个例子里，我们关心的是温度特征，可以把它理解成设备接口里名为「温度」的那一项。

在设备支持、手机也打开接收之后，温度计可以主动把这项数据发给手机。蓝牙把这种发送方式叫 **Notify**（通知）。这里的「通知」指连接里的数据消息。我们的 App 收到消息后，可以把屏幕上的数字改成 `24.6°C`。

平时做连续刷新的温度、湿度或传感器曲线，就常用这种方式。设备每次什么时候发，由它自己的协议决定。例如它可以每隔一段时间发一次，也可以等读数变了再发。用 App 接入时，按设备文档确认发送时机和数据格式。[Android BLE 数据传输指南](https://developer.android.com/develop/connectivity/bluetooth/ble/transfer-ble-data)

## Indicate 让设备知道手机收到了

还是这台温度计。平时它不断发温度读数，发完一条 Notify 就可以继续做下一次测量。这种消息在蓝牙属性协议里没有逐条确认。

现在增加一个功能。用户点「开始测量」，温度计测完后发一条「测量完成」，设备需要知道手机的蓝牙系统是否收到了这一条。设计设备协议时，可以给这个结果选 **Indicate**（指示）。设备依然主动发数据，手机的蓝牙系统收到后会自动回一个确认，设备等到确认后才在同一条通道上发下一条 Indicate。

```text
Notify     温度计 ──发数据──→ 手机
Indicate   温度计 ──发数据──→ 手机
           温度计 ←──确认收到── 手机的蓝牙系统
```

### 抓包里能看到什么

手机的蓝牙系统会沿着这条连接回一条真正的蓝牙消息，叫 **Handle Value Confirmation**。以下只展示蓝牙属性协议（ATT）这一层的示例字节。

```text
温度计 → 手机    1D 25 00 …    Handle Value Indication
手机 → 温度计    1E            Handle Value Confirmation
```

第一行的 `1D` 表示这是 Indicate。`25 00` 是示例里温度特征的值在设备属性表中的编号（句柄 `0x0025`），后面跟温度数据。第二行的 ATT 确认只有一个字节 `1E`，意思是「刚才那条 Indicate 收到了」。[Bluetooth Core 6.2 ATT，3.4.7.2–3.4.7.3](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/attribute-protocol--att-.html)

Android 的蓝牙协议栈负责回这一个字节，App 在 `onCharacteristicChanged()` 里接收数据。要确认 App 已经保存测量结果，可以约定由 App 在保存成功后另外发回一条业务确认。

接入已有设备时，先看设备协议规定温度特征用哪种方式。定时读数和测量结果也可能放在两个不同的特征里。

## CCCD 告诉设备这台手机想收哪种数据

回到「自动更新」开关。温度计怎么知道这台手机想接收温度？手机要往温度特征下面的一个配置项写值。这个配置项叫 **CCCD**，全名是 *Client Characteristic Configuration Descriptor*，中文叫客户端特征配置描述符。

在本章的例子里，温度计用 Notify 发送读数。用户打开「自动更新」后，**手机 App 向温度计的温度特征下面的 CCCD 写入 `01 00`**，订阅这个特征的 Notify。

假如换了一款用 Indicate 发送读数的温度计，**手机 App 就向那台温度计的温度特征下面的 CCCD 写入 `02 00`**。这样就为这台手机开启了温度数据的 Indicate 订阅。之后温度计发来一条读数，手机的蓝牙系统收到后会回一个确认。

用户关闭「自动更新」时，手机 App 向刚才写过的 CCCD 写入 `00 00`，关闭这台手机对该特征的订阅。如果温度计同时连着两台手机，其中一台取消订阅，另一台可以继续接收。

到这里可以把三件事连起来。**Notify 和 Indicate 是设备发数据的方式。CCCD 是手机在设备上设置接收方式的地方。** 设备支持哪些方式，要看特征声明的能力。[Bluetooth Core 6.2 GATT，3.3.3.3](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/generic-attribute-profile--gatt-.html)

## 在 Android 上打开自动更新

按钮按下以后，App 要做两件事。

1. **让手机准备接。** 调用 `gatt.setCharacteristicNotification(temperature, true)`，让 Android 把这项数据的通知交给当前连接的回调。返回 `true` 表示手机这边登记成功。
2. **让温度计知道可以发。** 从温度特征找到 CCCD，调用 `gatt.writeDescriptor(...)` 写入开启值。等到这个 CCCD 对应的 `onDescriptorWrite()` 回报 `GATT_SUCCESS`，才把页面状态改成「已订阅」。

实际调用时，从[服务发现](#android/development-guide/service-discovery)拿到温度特征，并检查[连接权限](#android/development-guide/permissions)。用 Notify 查 `PROPERTY_NOTIFY`，用 Indicate 查 `PROPERTY_INDICATE`。两种都调用同一个 `setCharacteristicNotification()`，远端接收方式由 CCCD 的值决定。它的标准短 UUID 是 `0x2902`。Android 已定义开启值，Notify 用 `BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE`，Indicate 用 `BluetoothGattDescriptor.ENABLE_INDICATION_VALUE`。

两个示例都用 API 33 或更高版本的 SDK 编译。Android 13（API 33）起，可以直接把字节数组传给 `writeDescriptor`。旧系统先把值放到描述符对象，再调用旧重载。接入设备时，按该特征的上报方式选一个版本。

### Notify 版本

温度计用 Notify 发读数时，手机 App 调用 `startTemperatureNotifications(gatt, temperature)`，向温度特征的 CCCD 写入 `01 00`。

```kotlin
private val cccdUuid = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

@Suppress("DEPRECATION")
fun startTemperatureNotifications(
    gatt: BluetoothGatt,
    temperature: BluetoothGattCharacteristic
): Boolean {
    val supportsNotify =
        (temperature.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0
    if (!supportsNotify) return false
    val cccd = temperature.getDescriptor(cccdUuid) ?: return false

    if (!gatt.setCharacteristicNotification(temperature, true)) return false

    val value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
    val submitted = if (Build.VERSION.SDK_INT >= 33) {
        gatt.writeDescriptor(cccd, value) == BluetoothStatusCodes.SUCCESS
    } else {
        cccd.setValue(value) && gatt.writeDescriptor(cccd)
    }

    if (!submitted) {
        gatt.setCharacteristicNotification(temperature, false)
    }
    return submitted
}
```

### Indicate 版本

如果温度计用 Indicate 发读数，手机 App 在打开「自动更新」时调用 `startTemperatureIndications(gatt, temperature)`。`temperature` 是服务发现拿到的温度特征。函数共用上面的 `cccdUuid`。

留意代码里的两个地方。先检查温度特征有没有 `PROPERTY_INDICATE`，再用 `ENABLE_INDICATION_VALUE`，把 `02 00` 写入这个温度特征下面的 CCCD。

```kotlin
@Suppress("DEPRECATION")
fun startTemperatureIndications(
    gatt: BluetoothGatt,
    temperature: BluetoothGattCharacteristic
): Boolean {
    val supportsIndicate =
        (temperature.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0
    if (!supportsIndicate) return false
    val cccd = temperature.getDescriptor(cccdUuid) ?: return false

    if (!gatt.setCharacteristicNotification(temperature, true)) return false

    val value = BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
    val submitted = if (Build.VERSION.SDK_INT >= 33) {
        gatt.writeDescriptor(cccd, value) == BluetoothStatusCodes.SUCCESS
    } else {
        cccd.setValue(value) && gatt.writeDescriptor(cccd)
    }

    if (!submitted) {
        gatt.setCharacteristicNotification(temperature, false)
    }
    return submitted
}
```

### 等设备确认订阅设置

两个示例返回 `true` 时，界面都可以先显示「正在订阅」。写入结果稍后从 `onDescriptorWrite(gatt, descriptor, status)` 回来。排队写入前记下当前的连接、目标 CCCD 以及正在执行的操作，收到对应回调再推进。写失败时撤销本地登记。一直没有回调时，让[会话超时处理](#android/development-guide/thread-state-machine)结束这次尝试。设备可能很快就发来第一条数据，应用应在发起订阅前准备好接收。[BluetoothGatt](https://developer.android.com/reference/android/bluetooth/BluetoothGatt) · [BluetoothGattCallback](https://developer.android.com/reference/android/bluetooth/BluetoothGattCallback)

## 收到温度以后更新页面

无论设备发 Notify 还是 Indicate，数据都从 `onCharacteristicChanged()` 进来。先确认它来自当前连接的温度特征，再按设备协议把字节解析为温度，交给页面更新。做跨端应用时，原生层可以把解析结果发给 Flutter 或 React Native 的页面订阅。

API 33 起使用 `onCharacteristicChanged(gatt, characteristic, value)`，数据在 `value` 参数里。旧系统用两参数的 `onCharacteristicChanged(gatt, characteristic)`，进入回调后复制 `characteristic.value` 再交给解析代码。[BluetoothGattCallback](https://developer.android.com/reference/android/bluetooth/BluetoothGattCallback)

关掉自动更新时，用 `BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE`（`00 00`）写 CCCD。成功后调 `setCharacteristicNotification(temperature, false)`。如果已经断开，就清理本次会话。绑定设备的远端 CCCD 可能跨连接保留，下次连接时手机仍要重新登记本地接收。

## 看一次数据有没有走完整条路

点开自动更新，等温度计发出一条新读数。如果页面还停在 `24.1°C`，先看 CCCD 写回调是否成功，再看 `onCharacteristicChanged()` 有没有进来。已经收到字节，接下来查解析和页面更新。

手边没有温度计时，可以用[双机 BLE Echo 实验](#android/development-guide/appendix-e-labs)。一台手机订阅后发送一串字节，另一台用 Notify 原样发回。你能在客户端看到订阅完成，再看到实际收到的数据。

## 一句话总结

**把温度计发数据想成投递，CCCD 是手机填给温度计的订阅单，Notify 是免签收投递，Indicate 要由手机的蓝牙系统签收。**

实际操作时，手机 App 把自己想收的上报方式写到设备上对应特征的 CCCD。温度计有数据要发时，就按订阅的方式发给手机。Indicate 的「签收」只到手机的蓝牙系统这一层。页面有没有刷新、结果有没有保存，还要看 App 怎么处理收到的数据。

## 面试题

1. 点一次「刷新」读取温度，和订阅温度 Notify，有什么区别？
2. 设备用 Indicate 发出「测量完成」后收到了确认，这个确认能说明什么？如果还要确认 App 已经保存结果，该怎么做？
3. 手机想订阅温度特征的 Indicate，谁向哪里写什么值？改用 Notify 或取消订阅时，分别写什么值？
4. `setCharacteristicNotification(temperature, true)` 返回了 `true`，但一直没收到温度。接下来先查哪两处？
5. API 33 起，`writeDescriptor(cccd, value)` 返回 `BluetoothStatusCodes.SUCCESS`。这时页面适合显示「正在订阅」还是「已订阅」？温度值又从哪个回调拿？

### 参考答案

1. 读取由手机发起，手机问一次，设备回一次。Notify 由设备主动发送。页面需要随着设备上报持续更新时，可以订阅设备支持的 Notify。
2. 确认表示这条 Indicate 到达了手机的蓝牙协议栈，栈会自动回复。要确认结果已保存，可以约定由 App 在保存成功后再向设备发送一条业务确认。
3. 手机 App 向设备上温度特征的 CCCD 写入 `02 00`，为这台手机订阅 Indicate。订阅 Notify 写 `01 00`，取消订阅写 `00 00`。
4. 先查手机 App 有没有向该特征的 CCCD 提交正确的写入，再查对应的 `onDescriptorWrite()` 是否报告 `GATT_SUCCESS`。这两处都通过后，再查设备有没有发送上报。
5. 先显示「正在订阅」，因为返回值只说明 Android 受理了写入。当前连接上这个 CCCD 的 `onDescriptorWrite()` 报告 `GATT_SUCCESS` 后，再显示「已订阅」。实际温度数据从 `onCharacteristicChanged()` 取得。

按方法名查订阅 API · [通知收不到时查哪里](#android/development-guide/appendix-f-faq)
