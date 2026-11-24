---
title: 分包、重组、确认与流控
order: 220
summary: 给每一片标上属于哪张图和排第几片，让标签收得下，也能在重发时认出已经收过的内容。
tags: SDK,安全,协议
updated: 2026-11-24
---

# 第 21 章　分包、重组、确认与流控

手机要给一块电子标签换图，手里有 3 KiB 数据。MTU 23 时，普通写一次通常只能放 20 字节。你可以把图片切成很多片，但标签还得知道这些片属于哪张图、第几片、什么时候收齐。否则断线重发以后，它可能把两次任务的数据拼到一起。

**分包**让手机把长消息切成短片段。**重组**让标签按编号还原原来的内容。**流控**让手机按标签接得住的速度发。它们都靠两端共同约定，下面从设计一片数据开始。

## 每一片先写清属于哪条消息

这里约定 `messageId` 标记哪一次传输，`index` 标记这是第几片，从 0 开始计数，`count` 告诉标签总共有多少片。三个字段都用小端，每个占 2 字节。MTU 23 的普通写去掉 ATT 的 3 字节和业务头的 6 字节，剩 14 字节给图片。MTU 247 时余下 238 字节。固件有更小限制时，按照更小的预算切。端序和版本要两边一起约定。

```text
messageId:u16 | index:u16 | count:u16 | chunk:bytes
```

会话协商时约定最大消息字节数、最大片数、首尾帧的规则，以及空消息能否发送。全文件长度和完整性校验可以放在独立的开始/完成消息中。CRC 能发现传输损坏，需要防篡改时用经过审查的认证方案。

## 标签怎么收片，手机什么时候发下一片

标签收到某片时，先按会话和 `messageId` 找到正在拼装的消息，再按 `index` 放到对应位置。检查 `index < count`，限制总片数和累计长度。收到完全相同的一片，可以确认后忽略副本。同一个序号出现不同内容，就暂停本次传输并记录。没有收齐的消息到期释放。收齐以后校验总长度和完整性，再把完整图片交给业务。

写带响应时，等待 ATT 完成能提供基本节奏。无响应写还需要对端业务 ACK、credit 或其他可验证的流控。先实现窗口 1 并测出失败点，再选择扩大窗口。GATT 队列的并发与业务协议允许在途的分片数是两个参数。

## 标签办完了，回复丢了该怎么办

ACK 丢失时，接收端可能已经持久化文件。重发要带同一个传输标识，设备按已提交状态返回结果。涉及换图、开关设备等有副作用的操作，优先提供幂等键或状态查询。连接重建后是否能续传由设备协议明确。应用在确认对端支持前，从安全的边界重新开始。

一次有效实验包含完整发送、重复片、缺片、对端处理后 ACK 丢失以及中途断连。把每条消息的两端状态和次数记下来，确认超时后不会重复提交业务动作。

## 把切片和重组写成代码

发送端按协商好的预算切片。`chunkSize` 由实测 MTU 减去 ATT 和业务头得出，不要写死：

```kotlin
fun chunkImage(messageId: Int, image: ByteArray, chunkSize: Int): List<ByteArray> {
    require(chunkSize > 0 && image.size <= 0xFFFF * chunkSize)
    val count = (image.size + chunkSize - 1) / chunkSize
    return (0 until count).map { i ->
        val from = i * chunkSize
        val part = image.copyOfRange(from, minOf(from + chunkSize, image.size))
        ByteBuffer.allocate(6 + part.size).order(ByteOrder.LITTLE_ENDIAN)
            .putShort(messageId.toShort())
            .putShort(i.toShort())
            .putShort(count.toShort())
            .put(part).array()
    }
}
```

接收端的骨架如下。它处理乱序、重复和超时；同序号不同内容的恶意帧在生产代码里应中止本次传输并记录，这里简化为保留首片：

```kotlin
class Reassembler(private val timeoutMs: Long = 10_000) {
    private class Pending(val count: Int, val parts: Array<ByteArray?>, var lastAt: Long)
    private val pending = HashMap<Int, Pending>()

    /** 收齐返回完整图片；未收齐或帧非法返回 null。now 用单调时钟。 */
    fun accept(frame: ByteArray, now: Long): ByteArray? {
        pending.entries.removeAll { now - it.value.lastAt > timeoutMs }  // 先清过期
        if (frame.size < 6) return null
        val buf = ByteBuffer.wrap(frame).order(ByteOrder.LITTLE_ENDIAN)
        val id = buf.short.toInt() and 0xFFFF
        val index = buf.short.toInt() and 0xFFFF
        val count = buf.short.toInt() and 0xFFFF
        if (count == 0 || index >= count) return null          // 偏移越界
        val p = pending.getOrPut(id) { Pending(count, arrayOfNulls(count), now) }
        if (p.count != count) { pending.remove(id); return null }  // 同 ID 换了总数
        p.lastAt = now
        if (p.parts[index] == null) {
            val part = ByteArray(frame.size - 6)
            buf.get(part)
            p.parts[index] = part
        }
        if (p.parts.all { it != null }) {
            pending.remove(id)
            return p.parts.fold(ByteArray(0)) { acc, part -> acc + part!! }
        }
        return null
    }
}
```

这段代码值得逐行对着上面的规则读：`index >= count` 挡住越界，`count` 不一致丢弃整条消息，重复片只认第一次，超时清理防止半条消息占着内存。[第 27 章](#android/development-guide/test-lab)会给它补上单元测试。发送节奏仍由 GATT 队列和业务窗口控制，这个类只负责拼，不负责发。

## 一句话总结

**给每一片标上属于哪张图和排第几片，让标签收得下，也能在重发时认出已经收过的内容。**

## 面试题

1. MTU 23、普通写、应用帧头 6 字节，一片能放几字节图片数据？
2. 标签已经保存图片，但手机没收到最后一个 ACK，如何安全重试？
3. GATT 每次只等待一条写回调，业务发送窗口一定也是 1 吗？

### 参考答案

1. 23 减去 3 字节 ATT 头和 6 字节业务头，最多放 14 字节。
2. 重发时使用相同事务标识，标签判断该事务已提交后返回原结果。也可先用状态查询确认。
3. 两者分别计数。GATT 队列跟踪属性操作，业务窗口跟踪尚未收到设备业务确认的分片。

[Bluetooth Core 6.2 ATT](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-62/out/en/host/attribute-protocol--att-.html) · [GATT 读写](#android/development-guide/characteristic-rw)
