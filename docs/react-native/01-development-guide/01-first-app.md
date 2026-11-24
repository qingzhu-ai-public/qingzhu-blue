---
title: 00　把带蓝牙原生模块的 App 装到手机
slug: first-app
order: 10
---

# 00　把带蓝牙原生模块的 App 装到手机

先在真机看到「开始扫描」。React Native 页面写在 `App.tsx`，系统 BLE 能力由编进开发包的原生模块提供。实战使用 Expo Development Build。它像装进了自己零件的调试版 App，能加载本课程的蓝牙库。

编译安装以后用 Metro 调试页面。改按钮文字可以继续用快速刷新。改蓝牙库、Expo 配置插件参数或原生代码，要重新生成并构建原生 App。手机端看到旧行为时，先看装的是哪一个包。

**练习**　安装第一次开发构建，修改按钮文字，再扫码或从开发客户端打开 Metro。

**一句话**　TypeScript 写操作，原生模块拿着系统钥匙去执行。

**面试题**　为什么把蓝牙库放到 `package.json` 还不能扫？

包里还有 Android 和 iOS 的原生实现，必须编入客户端。Metro 发送的 JavaScript 代码无法替代这一步。

[react-native-ble-manager API](https://innoveit.github.io/react-native-ble-manager/methods/) · [温湿度计实战](#react-native/thermometer-mvp/overview)
