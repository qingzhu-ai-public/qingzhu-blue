# 青竹蓝牙学堂

面向蓝牙开发者的学习网站，从通用基础到 Android、iOS 和跨平台实战，结合图解、交互演练和自测学习蓝牙开发。

**[进入青竹蓝牙学堂](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/index.html)**

## 课程目录

学堂现有 62 门课程，建议先学习通用基础，再选择自己使用的平台。

| 学习路线 | 课程 | 内容 |
| --- | ---: | --- |
| [通用基础](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/index.html#base) | 12 | 广播、连接、GATT、读写通知、MTU、安全、排障与 nRF Connect 实验 |
| [Android 实战](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/index.html#android) | 14 | 权限、扫描、连接、后台、抓包、兼容性与 BTHome 实战 |
| [iOS 实战](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/index.html#ios) | 11 | CoreBluetooth、连接、读写、后台恢复、安全与 BTHome 实战 |
| [HarmonyOS 实战](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/index.html#harmonyos) | 9 | ConnectivityKit、权限、扫描、连接、外设角色与温湿度计实战 |
| [Flutter 实战](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/index.html#flutter) | 8 | 跨端蓝牙库、连接与读写、生命周期、原生桥接与综合实战 |
| [React Native 实战](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/index.html#rn) | 8 | 跨端蓝牙库、扫描与事件、读写、原生模块桥接与综合实战 |

课程以温湿度计等场景串联知识，包含流程图、可点击演练和自测。各平台的配套示例位于 [examples](examples/) 目录，具体运行方式请查看各示例的 README。

## 相关项目

[Qingzhu-BLE](https://github.com/qingzhu-ai-public/qingzhu-ble-android) 是面向 Android 的 BLE SDK，提供扫描、连接、收发和多设备任务调度等能力。

## 本地浏览与维护

这是静态网站，可直接在浏览器打开仓库根目录的 `index.html`，或打开 `academy/index.html` 进入学堂。根目录入口会跳转至学堂首页。

```text
academy/index.html       学堂首页与课程入口
academy/bluetooth/       通用基础课程
academy/android/         Android 课程
academy/ios/             iOS 课程
academy/harmonyos/       HarmonyOS 课程
academy/flutter/         Flutter 课程
academy/react-native/    React Native 课程
examples/                平台示例工程
```

课程页面为各目录下的 HTML 文件，首页课程入口维护在 `academy/index.html`。仓库仍保留旧版文档站的 `assets/`、`tools/build-docs.js` 和工作流；新版学堂页面不依赖旧版文档构建流程。

## 许可证

本仓库目前未附许可证。使用和分发前，请先联系仓库作者确认授权。
