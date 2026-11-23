---
title: 05　发一条指令，再读一组温湿度
slug: read-write-and-parse
order: 60
---

# 05　发一条指令，再读一组温湿度

用户按下请求。A 往教学特征写 01。B 接到后准备数据，A 再读回温度和湿度。

## 等写响应，再发读取

```typescript
await client.writeCharacteristicValue(command, ble.GattWriteType.WRITE);
const response = await client.readCharacteristicValue(sample);
const bytes = response.characteristicValue;
```

`command` 和 `sample` 记录目标服务 UUID、特征 UUID。command 的 characteristicValue 里放指令 `01`。先等有响应写完成，再请求读取。厂商配件的写成功与业务完成可能分开，要和协议的读数、通知或业务应答匹配。

无响应写使用 `WRITE_NO_RESPONSE`，适用于设备声明支持的特征。发送控制和业务确认需要结合协议处理。当前示例在一条请求结束前禁用按钮。

## 从字节算出摄氏度

回包 `40 02 5A 0A 03 BF 13` 中，`02` 后的两字节是温度。用 `DataView.getInt16(2, true)` 从下标 2 按小端读出 2650，除以 100 得 26.50 °C。湿度从下标 5 用 `getUint16(5, true)` 读出 5055，除以 100 得 50.55%。解析前查长度和字段 ID。

**自己试一次**　将外设的 2650 改成 2700，再读。核对显示的 27.00 °C 与回包 `8C 0A`。

**一句话记住**　写入是下指令，读回后才知道要显示多少。

## 自查题

1. **有响应写成功能直接算出温度吗？** 还需要读取响应中的字节并解析。

[华为 GATT API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-bluetooth-ble/) · [BTHome 字节格式](https://bthome.io/format/)

[上一章](#harmonyos/development-guide/connect-and-discover) · [正文目录](#harmonyos/development-guide/overview) · [下一章](#harmonyos/development-guide/notify-and-indicate)
