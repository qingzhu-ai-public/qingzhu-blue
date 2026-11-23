# 蓝牙温湿度计 · HarmonyOS 实战源码

使用 ArkTS、ArkUI、Stage 模型和 Connectivity Kit。以 **HarmonyOS NEXT API 12** 为教学基线，可在 DevEco Studio 中用支持该基线的 HarmonyOS SDK 创建工程。示例沿用 Empty Ability 的入口、资源及签名配置。

1. 新建 **Empty Ability**，选 ArkTS，模块名保持 `entry`，保留模板的 `EntryAbility` 和 `pages/Index` 路由。
2. 将本目录的 `entry/src/main/ets` 下的 `bluetooth` 与 `pages/Index.ets` 合入工程。
3. 按[原型与工程入口篇](https://qingzhu-ai-public.github.io/qingzhu-blue/#harmonyos/thermometer-mvp/prototype)添加蓝牙权限与用途说明，然后在真机运行。
4. 先让手机 B 点「模拟温湿度计」和「启动广播」，再用手机 A 扫描、连接和请求新读数。两端保持 App 前台。

[打开交互原型](prototype/index.html) · [综合实战目录](https://qingzhu-ai-public.github.io/qingzhu-blue/#harmonyos/thermometer-mvp/overview)

原型用模拟数据演示，源码以教学 UUID 和教学 GATT 命令收发。读数借用 BTHome v2 的温湿度字段格式。当前已核对源码和原型，DevEco 编译及两台 HarmonyOS 真机的蓝牙收发待验收。
