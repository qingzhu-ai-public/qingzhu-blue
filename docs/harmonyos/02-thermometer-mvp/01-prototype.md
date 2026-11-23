---
title: 原型与工程入口　先让页面跑在手机上
slug: prototype
order: 10
---

# 原型与工程入口　先让页面跑在手机上

手机 A 点「开始扫描」，选中教学设备，连上后点「请求新读数」。手机 B 用同一款 App 模拟外设。先用模拟数据把手机端的操作走一遍。[打开交互原型](https://qingzhu-ai-public.github.io/qingzhu-blue/examples/harmonyos/thermometer-mvp/prototype/index.html)

<!-- bthome-prototype -->

## 准备模板工程

在 DevEco Studio 建 **Application → Empty Ability** 工程，选 ArkTS 和手机设备类型。模块保持 `entry`。选择支持所用 API 的 HarmonyOS SDK，本例以 API 12 为基线。保留模板的 `EntryAbility`、`pages/Index` 路由和资源配置。

把示例的 `entry/src/main/ets/bluetooth` 复制进同名目录，将 `ets/pages/Index.ets` 替换模板首页。导入后先确认三份 ArkTS 文件都在工程树中。[下载与源码](https://github.com/qingzhu-ai-public/qingzhu-blue/tree/main/examples/harmonyos/thermometer-mvp)

## 在模块里补权限说明

在 `entry/src/main/module.json5` 的 `module` 对象内合并下面的 `requestPermissions`。如果已有同名数组，只新增对应条目。

```json5
"requestPermissions": [
  {
    "name": "ohos.permission.ACCESS_BLUETOOTH",
    "reason": "$string:bluetooth_reason",
    "usedScene": { "abilities": ["EntryAbility"], "when": "inuse" }
  }
]
```

在 `entry/src/main/resources/base/element/string.json` 的 `string` 数组加入下面这项。EntryAbility 名称若和模板不同，就与模块声明中的实际名称对齐。

```json
{"name":"bluetooth_reason","value":"查找并连接教学温湿度计，或模拟外设供另一台手机连接"}
```

## 装到手机并确认首页

打开手机的开发者选项和 USB 调试。用数据线连接，解锁并确认授权。按 DevEco 的提示配置调试签名，选中真机后点 Run。手机出现「蓝牙温湿度计」和「开始扫描」，就完成第一次安装。

只有一台手机也可以先做首页和权限练习。完整收发时，让 B 装同一工程产出的 App，点「模拟温湿度计」并启动广播。从 A 的扫描页开始，保持两台 App 在前台。[华为 ArkTS Stage 入门](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/start-with-ets-stage/) · [华为权限申请说明](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/request-user-authorization/)

**一句话记住**　先让 App 能装能打开，再验证手机之间能不能通信。

**自查题**　DevEco 没看到手机怎么办？先查数据线是否能传数据、手机是否解锁，以及 USB 调试授权。

继续读[扫描篇](#harmonyos/thermometer-mvp/scan)。
