---
title: 05　离开页面后，停止谁的扫描和监听
slug: lifecycle
order: 60
---

# 05　离开页面后，停止谁的扫描和监听

扫描状态属于原生模块，页面移除监听并不会自动停止系统扫描。卸载时调用 `stopScan` 并移除事件监听。示例的连接也由该页持有，退出时主动断开。

`useState` 用来渲染，`useRef` 可以让下一次点击立即看见正在执行的操作。示例用 `locked.current` 拦住重复点按，用会话编号筛掉晚到的数据。JavaScript 的超时也不会替你取消原生调用，于是连接或读写超时时还会断开当前设备。

**练习**　快速连续点扫描和读数，确认一次只处理一轮。然后手动让外设断开。

**一句话**　页面关门之前，先把仍在外面跑的活停下来。

**面试题**　`remove()` 和 `stopScan()` 各负责什么？

前者让 JavaScript 不再收事件，后者要求原生模块结束扫描。

[react-native-ble-manager API](https://innoveit.github.io/react-native-ble-manager/methods/) · [温湿度计实战](#react-native/thermometer-mvp/overview)
