# BTHome 温湿度计 · HarmonyOS MVP

与 [Android bthome-mvp](../../android/bthome-mvp/)、[iOS bthome-mvp](../../ios/bthome-mvp/) 同一个项目：扫描 [BTHome v2](https://bthome.io/format/) 明文广播，扫到即显示温湿度；也能当**真正的 BTHome 广播源**（serviceData）；教学 GATT 服务的 UUID 和指令与另外两端完全一致，**鸿蒙、Android、iPhone 可以互连**。

- [交互原型](prototype/index.html)（线上：https://qingzhu-ai-public.github.io/qingzhu-blue/examples/harmonyos/bthome-mvp/prototype/index.html）
- [配套课程：D9 综合实战 BTHome](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/harmonyos/09-project.html)

## 鸿蒙平台优势（先读这个）

`AdvertiseData.serviceData`（API 10）让鸿蒙能发出标准 BTHome 服务数据广播——iOS 的 `startAdvertising` 只支持名字和服务 UUID，做不到这一点。所以鸿蒙是三端里角色最全的：

| 角色 | 说明 |
| --- | --- |
| 接收器 | 扫描 FCD2，手解原始 AD（不依赖 API 22 的 serviceDataMap），API 10 起全版本可跑 |
| BTHome 广播源 | serviceData 发真 BTHome 帧，可被鸿蒙/Android/iPhone/Home Assistant 接收 |
| 教学 GATT 从端 | 写 01 回帧，温度交替 25.00/26.50，可被 Android/iPhone 连接 |
| 教学 GATT 中心 | 连接 → 发现 → 写 01 → 读帧 → 解码，对端可以是另外两端的模拟外设 |

## 在真机上运行

使用 ArkTS、ArkUI、Stage 模型和 Connectivity Kit。以 **HarmonyOS NEXT API 12** 为教学基线（核心链路 API 10 即可跑），在 DevEco Studio 中用支持该基线的 HarmonyOS SDK 创建工程。

1. 新建 **Empty Ability**，选 ArkTS，模块名保持 `entry`，保留模板的 `EntryAbility` 和 `pages/Index` 路由。
2. 将本目录 `entry/src/main/ets` 下的 `bluetooth` 与 `pages/Index.ets` 合入工程。
3. 在 `entry/src/main/module.json5` 声明蓝牙权限（reason 必须给字符串资源，先在 `string.json` 加 `bluetooth_reason`）：

```json5
"requestPermissions": [
  {
    "name": "ohos.permission.ACCESS_BLUETOOTH",
    "reason": "$string:bluetooth_reason",
    "usedScene": { "abilities": ["EntryAbility"], "when": "inuse" }
  }
]
```

4. 真机运行。App 首页五个页签：接收器 / 广播源 / 教学从端 / 教学中心 / 自检。同一时刻只跑一个角色（单射频）。

### 双机验收（对照 D9 第 9 步清单）

1. 手机 A「自检」页跑 13 项协议自检，应全 PASS（离线，不碰蓝牙）。
2. 手机 A「广播源」拖滑杆 → 开始广播；手机 B「接收器」开始扫描，列表出现 A 机，读数与滑杆一致。
3. 手机 A「教学从端」启动广播；手机 B「教学中心」扫描 → 连接 → 请求新读数，温度交替 25.00/26.50、湿度 50.55%。
4. 跨端：Android/iPhone 运行各自 bthome-mvp，重复第 2、3 步，验证同一帧三端解出同一读数。
5. 故障注入：接收器收到坏帧（越界湿度/未知 ID）时显示故障原因，不硬显示数字；坏帧行为可先在「自检」页离线验证。

## 工程结构

```
entry/src/main/ets/
├── bluetooth/
│   ├── BthomeProtocol.ets    协议层：对象表 / parse / encode / AD 提取 / 教学协议 / 13 项自检（纯 ArkTS）
│   ├── BthomeScanner.ets     接收器：过滤 FCD2 → 手解 AD → 解码 → 按 deviceId 合并，10s 标离线
│   ├── BthomeAdvertiser.ets  广播源：serviceData 发 BTHome 帧；更新读数 stop → 改帧 → start
│   ├── SensorPeripheral.ets  教学从端：GATT 服务，写 01 换温度，读回帧
│   └── SensorClient.ets      教学中心：扫描 → 连接 → 发现 → 写 01 → 读帧 → 解码（串行 + 会话编号）
└── pages/Index.ets           ArkUI：四角色页 + 自检面板
```

## 按开发顺序学习

| 步骤 | 对应课程 |
| --- | --- |
| 协议与对象 ID 表 | [D9 第 1–2 步](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/harmonyos/09-project.html#format) |
| 解析器与自检 | [D9 第 4 步](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/harmonyos/09-project.html#parser) |
| 接收器扫描 | [D9 第 5 步](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/harmonyos/09-project.html#scanner) + D3 |
| 广播源与平台边界 | [D9 第 6 步](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/harmonyos/09-project.html#advertiser) + D7 |
| 教学 GATT 路线 | [D9 第 8 步](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/harmonyos/09-project.html#connect) + D4–D6 |
| 双机验收 | [D9 第 9 步](https://qingzhu-ai-public.github.io/qingzhu-blue/academy/harmonyos/09-project.html#accept) |

MVP 切后台会停掉会话（简化）；长时任务保活见 D9 第 10 步。标准 1809/2A1C 健康温度计路线见 [thermometer-mvp](../thermometer-mvp/)。

当前已核对源码与原型（协议层 13 项自检在原型中等价实现并通过），DevEco 编译及真机蓝牙收发待验收。