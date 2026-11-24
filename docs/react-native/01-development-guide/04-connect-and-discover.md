---
title: 03　连接成功后，再找可读写的特征
slug: connect-and-discover
order: 40
---

# 03　连接成功后，再找可读写的特征

点设备，先停止这次扫描，然后将 `device.id` 传给 `connect`。连接成功后调用 `retrieveServices`，用服务 UUID 和特征 UUID 找目标条目，再检查 `Read` 和 `Write` 属性。

连接、查服务分别有自己的超时。用 `onDisconnectPeripheral` 处理外设走远或主动断开的情况。等旧 Promise 结束时，还要确认它仍属于这次会话。让连接和发现各有一条状态消息，读者才看得出失败发生在哪里。

**练习**　把特征 UUID 改错，确认列表仍能扫出设备，读数按钮不会亮。

**一句话**　接通电话以后，还要找到能回答这个问题的人。

**面试题**　调用 `connect` 后可以直接读吗？

这个库的读写 API 要求先完成服务发现。业务层还要确定目标特征满足读写条件。

[react-native-ble-manager API](https://innoveit.github.io/react-native-ble-manager/methods/) · [温湿度计实战](#react-native/thermometer-mvp/overview)
