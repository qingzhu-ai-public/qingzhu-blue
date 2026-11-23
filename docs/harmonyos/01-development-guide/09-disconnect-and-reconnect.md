---
title: 08　设备走远，界面怎样恢复
slug: disconnect-and-reconnect
order: 90
---

# 08　设备走远，界面怎样恢复

手机正在等读数，外设被关掉。App 应停止等待、告诉用户发生了什么，并允许重新扫描连接。

## 让旧任务先失效

收到断开事件或发生超时，把当前连接标记失效。停止计时，禁用读写，解除连接监听，执行 `disconnect` 和 `close`。已发起的异步结果仍可能稍后回来，实战每次开始会话都更换 generation，回包找不到对应代号就忽略。

## 重连后重新确认服务和订阅

重新扫到设备后建立新会话。再次等待连接、查找服务和特征。如果业务用订阅，就重新确认订阅结果。两个设备同时连接时，每个设备应有自己的状态和等待任务。不要使用上一条连接的可写特征直接给新会话发数据。

实战只运行前台，在页面隐藏时停止。产品需要后台持续连接时，按目标设备、系统版本和后台任务规则另做专项测试。

**自己试一次**　拿走 B 或关闭蓝牙，观察 A 停止等待。重开 B，让 A 从新的扫描开始，再读一组值。

**一句话记住**　一条连接结束，属于它的状态和任务也结束。

## 自查题

1. **已经点击返回，为什么旧回调仍可能发生？** 系统操作和页面动作是异步的，需要检查会话是否仍有效。

[华为 GATT 开发指南](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/gatt-development-guide/)

[上一章](#harmonyos/development-guide/peripheral-and-response) · [正文目录](#harmonyos/development-guide/overview) · [下一章](#harmonyos/development-guide/descriptors-and-long-data)
