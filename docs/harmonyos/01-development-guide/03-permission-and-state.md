---
title: 02　点击扫描，先检查两件事
slug: permission-and-state
order: 30
---

# 02　点击扫描，先检查两件事

App 请求允许使用蓝牙，用户同意后，还需要确认蓝牙开关已经开启。

## 声明权限，再从按钮请求

在 `entry/src/main/module.json5` 的 `module.requestPermissions` 声明 `ohos.permission.ACCESS_BLUETOOTH`，按要求填写用途和使用场景。真机上点击按钮后，用 UIAbilityContext 发起用户授权。

```typescript
const manager = abilityAccessCtrl.createAtManager();
const result = await manager.requestPermissionsFromUser(context, ['ohos.permission.ACCESS_BLUETOOTH']);
if (result.authResults[0] !== 0) {
  // 显示未授权提示，暂停本次操作。
  return;
}
```

这几行放进 async 方法。`authResults[0]` 对应第一个请求的权限。授权失败时让状态停在当前步骤，引导用户到设置查看。

## 同意以后，再看系统开关

用 `access.getState()` 查看蓝牙状态。本示例只在 `access.BluetoothState.STATE_ON` 时开始操作，没开时请用户去系统设置打开。需要实时刷新开关状态的页面可以注册 `access.on('stateChange', handler)`，离开时用同一函数解除。授权请求和系统开关检查都应处理异常。

**自己试一次**　分别拒绝蓝牙权限、关闭蓝牙开关。确认页面能说清停在了哪一步。

**一句话记住**　权限回答能不能用，开关回答现在有没有开。

## 自查题

1. **为什么写了 module.json5 还要请求？** 清单声明用途，运行时权限仍要征得用户同意。

[华为申请用户授权](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/request-user-authorization/)

[上一章](#harmonyos/development-guide/roles-and-advertising) · [正文目录](#harmonyos/development-guide/overview) · [下一章](#harmonyos/development-guide/scan-and-filter)
