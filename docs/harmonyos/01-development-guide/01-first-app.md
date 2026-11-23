---
title: 00　先把一个按钮装到手机上
slug: first-app
order: 10
---

# 00　先把一个按钮装到手机上

打开应用，点一下按钮，看到文字变化。先用一个页面验证工程、签名和真机安装。

## 建一个 Stage 工程

DevEco Studio 欢迎页选 **Create Project → Application → Empty Ability**。语言选 ArkTS，模块保留 `entry`。示例以 HarmonyOS NEXT API 12 为基线。使用支持目标真机的 HarmonyOS SDK。工程中的 `EntryAbility` 负责加载页面，`pages/Index.ets` 是默认首页。

```typescript
@Entry
@Component
struct Index {
  @State message: string = '还没开始';

  build() {
    Column({ space: 12 }) {
      Text(this.message)
      Button('查找设备').onClick(() => { this.message = '按钮已收到点击'; })
    }
    .padding(24)
  }
}
```

`@State` 让 ArkUI 在文字变化后刷新页面。`onClick` 里的代码会等用户按下按钮才执行。把这件事跑通以后，同一个按钮就能拿来发起扫描。

## 上真机

手机打开开发者选项和 USB 调试，连线后解锁并允许调试。工程按 DevEco 提示配置调试签名，运行目标选这台手机，点 Run。第一次看到「查找设备」且能改变文案就通过。电脑找不到手机时，先查数据线、调试授权和 DevEco 设备列表。

**一句话记住**　先看到按钮有反应，再接蓝牙。

## 自查题

1. **点按钮能改文字，蓝牙就能用了么？** 这一步只验证页面、构建和安装。蓝牙权限和状态下一章再判断。

[华为 ArkTS Stage 入门](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/start-with-ets-stage/)

[正文目录](#harmonyos/development-guide/overview) · [下一章](#harmonyos/development-guide/roles-and-advertising)
