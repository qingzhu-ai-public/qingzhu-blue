---
title: 测试实验室与自动化
order: 280
summary: 把「偶尔失败」变成一组能反复触发、能判定通过的操作，再用真实设备验证系统行为。
tags: SDK,工程实践
updated: 2026-11-24
---

# 第 27 章　测试实验室与自动化

双机 Echo 跑通了。现在试一下，在客户端刚写完消息时按「停止」。再启动下一轮，故意让上一轮的回调迟到。你要能在日志里确认两件事。取消只报告一次，旧回调也没让新会话误以为已经完成。

回调顺序这种问题，可以用可控时钟和模拟蓝牙接口反复测。锁屏、控制器资源和实际设备收发，则要用手机和外设验证。先选一个能说清预期结果的小场景，再逐步换成真实的设备和系统组合。

| 测试层 | 用例 | 可判定结果 |
| --- | --- | --- |
| 单元测试 | 广播截断、掩码匹配、分片重复、偏移越界 | 输入固定字节，断言解析结果和释放内存 |
| 模拟传输 | 建连返回空、写立即拒绝、回调延迟、重试取消 | 用可控时钟、模拟回调，断言每条任务只终结一次 |
| 同类双机 | 一台广播并提供 echo 服务，一台扫描连接 | 写入字节与通知返回一致，退出后连接和广播都释放 |
| 产品真机 | 设备固件、功耗策略、熄屏、多个设备、恢复 | 记录每个阶段的成功率、分位耗时和证据 |

## 把偶然失败变成可以按按钮复现

测试时可以让实验外设在某一阶段做一件确定的事。比如已经回了属性写成功，却把业务 ACK 延迟到客户端超时之后。下一次再换成拒绝写入、主动断开或回格式错误的包。每轮只开一项，两端日志带上同一个测试编号。这样能分清失败来自属性写，还是设备应用的处理结果。

测试数据先从单设备开始。运行多设备用例时，记录同一时段建连数和传输数。高负载失败后退回单设备验证，才能确定差异来自并发条件。输出记录保留分母和超时或失败项，避免只用成功样本得出延迟改善结论。

## 修改连接代码后，至少把这些场景走一遍

- 权限拒绝或撤回、蓝牙关闭、用户取消扫描。
- 扫描中退出页面、选中后设备离开、建连回调迟到。
- 服务或 CCCD 缺失、GATT 写立即拒绝、写入超时后又收到回调。
- 收到业务 ACK 前断开，恢复后检查幂等行为。
- Server 断开一个客户端后按协议保留绑定配置，释放其当前在途数据。
- 锁屏与切后台、普通进程回收、强行停止、系统或设备重启。
- 同一手机固件组合连续运行，统计完成数、错误分布和资源回收。

## 把第一批测试写出来

[第 21 章](#android/development-guide/fragmentation-flow)的 `Reassembler` 是纯逻辑，不碰蓝牙，最适合先测。三个用例对应三条规则：

```kotlin
class ReassemblerTest {
    private val image = ByteArray(35) { it.toByte() }   // 故意不是 chunkSize 的整数倍
    private val frames = chunkImage(messageId = 7, image = image, chunkSize = 14)

    @Test fun `乱序到达也能重组`() {
        val r = Reassembler()
        assertNull(r.accept(frames[2], now = 0))
        assertNull(r.accept(frames[0], now = 1))
        assertArrayEquals(image, r.accept(frames[1], now = 2))
    }

    @Test fun `重复片不产生重复数据`() {
        val r = Reassembler()
        r.accept(frames[0], now = 0)
        assertNull(r.accept(frames[0], now = 1))          // 同片重发
        r.accept(frames[1], now = 2)
        assertArrayEquals(image, r.accept(frames[2], now = 3))
    }

    @Test fun `超时的半条消息被丢弃`() {
        val r = Reassembler(timeoutMs = 10_000)
        r.accept(frames[0], now = 0)
        assertNull(r.accept(frames[1], now = 20_000))     // 触发清理，重新开始
        assertNull(r.accept(frames[0], now = 20_001))
        assertNull(r.accept(frames[1], now = 20_002))
        assertArrayEquals(image, r.accept(frames[2], now = 20_003))
    }
}
```

注意 `now` 是参数而不是内部取系统时间——这就是「可控时钟」：测试不用真的等 10 秒。命令队列同理，把蓝牙接口抽成一个可替换的传输接口，测试里用假实现：

```kotlin
interface Transport {
    fun write(bytes: ByteArray): Boolean          // 对应立即结果
    // 完成回调由测试代码决定什么时候、以什么状态触发
}

class FakeTransport : Transport {
    var nextResult = true
    val written = mutableListOf<ByteArray>()
    override fun write(bytes: ByteArray): Boolean { written += bytes; return nextResult }
    // 测试里手动调 listener.onWriteDone(...)，想让它迟到就晚点调
}
```

用它能安排「写立即拒绝」「回调在取消之后才到」「旧代次回调迟到」这些真机上靠运气的场景，断言每条命令只终结一次。真机双机实验仍然要做，但回归靠这批秒级跑完的测试守住。

[实验手册](#android/development-guide/appendix-e-labs) · [机型矩阵](#android/development-guide/vendor-compat)

## 一句话总结

**把「偶尔失败」变成一组能反复触发、能判定通过的操作，再用真实设备验证系统行为。**

## 面试题

1. 想稳定复现迟到回调影响新连接，用哪层测试最方便？
2. 为什么双机 Echo 成功后还要做产品真机测试？

### 参考答案

1. 用模拟传输和可控时钟。主动安排旧回调晚到，断言当前会话及命令状态没有被改变。
2. 它验证基础链路。真实固件、系统后台策略、无线环境及多设备负荷，需要在目标组合中另行验证。
