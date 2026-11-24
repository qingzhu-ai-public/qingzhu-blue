---
title: 原型与工程入口　先看按钮怎么走
slug: prototype
order: 10
---

# 原型与工程入口　先看按钮怎么走

先点原型里的「开始扫描」，选中外设，再点「请求新读数」。网页只演示交互。真机 App 使用手机蓝牙扫描另一台设备。[打开交互原型](https://qingzhu-ai-public.github.io/qingzhu-blue/examples/react-native/thermometer-mvp/prototype/index.html)

<!-- bthome-prototype -->

## 工程配置参考

<details>
<summary>package.json</summary>

[打开工程源码](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/react-native/thermometer-mvp/package.json)

```json
{
  "name": "qingzhu-rn-thermometer",
  "version": "1.0.0",
  "private": true,
  "main": "index.ts",
  "scripts": {
    "start": "expo start --dev-client",
    "android": "expo run:android",
    "ios": "expo run:ios",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "expo": "55.0.32",
    "expo-dev-client": "55.0.41",
    "react": "19.2.0",
    "react-native": "0.83.10",
    "react-native-ble-manager": "12.6.1"
  },
  "devDependencies": {
    "@types/react": "~19.2.2",
    "typescript": "~5.9.2"
  }
}
```

</details>

<details>
<summary>app.json</summary>

[打开工程源码](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/react-native/thermometer-mvp/app.json)

```json
{
  "expo": {
    "name": "青竹蓝牙温湿度计",
    "slug": "qingzhu-rn-thermometer",
    "version": "1.0.0",
    "android": {
      "package": "ai.qingzhu.rnthermometer"
    },
    "ios": {
      "bundleIdentifier": "ai.qingzhu.rnthermometer"
    },
    "plugins": [
      [
        "react-native-ble-manager",
        {
          "neverForLocation": true,
          "bluetoothAlwaysPermission": "用于扫描和连接教学温湿度计。"
        }
      ]
    ]
  }
}
```

</details>

<details>
<summary>index.ts</summary>

[打开工程源码](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/react-native/thermometer-mvp/index.ts)

```typescript
import { registerRootComponent } from 'expo';
import App from './App';

registerRootComponent(App);
```

</details>

<details>
<summary>tsconfig.json</summary>

[打开工程源码](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/react-native/thermometer-mvp/tsconfig.json)

```json
{
  "extends": "expo/tsconfig.base",
  "compilerOptions": { "strict": true }
}
```

</details>

## 装到真机上

1. 把示例工程下载到电脑。打开含 `package.json` 的目录，用 Node.js 20.19 或 Expo SDK 55 支持的更高版本。
2. 执行 `npm install`。这个工程已经包含 Expo 开发客户端和 `react-native-ble-manager` 配置插件。
3. Android 手机打开 USB 调试，执行 `npm run android -- --device`。iPhone 用 Mac 和 Xcode 配好签名，再执行 `npm run ios -- --device`。
4. 用 `npm start` 启动 Metro，然后在手机上打开刚装好的开发客户端。修改插件配置或增加原生库后，重新生成并构建对应平台的原生工程。Expo Go 的安装包不含本课的第三方 BLE 模块。

看到「蓝牙温湿度计」和「开始扫描」按钮，工程入口就跑通了。再准备一台支持外设角色的手机，打开已有的原生温湿度计示例并启动模拟外设。[Android 示例](https://qingzhu-ai-public.github.io/qingzhu-blue/#android/bthome-mvp/overview) · [iOS 示例](https://qingzhu-ai-public.github.io/qingzhu-blue/#ios/thermometer-mvp/overview) · [HarmonyOS 示例](https://qingzhu-ai-public.github.io/qingzhu-blue/#harmonyos/thermometer-mvp/overview)[Expo 开发构建](https://docs.expo.dev/develop/development-builds/introduction/) · [BLE Manager 的 Expo 配置](https://innoveit.github.io/react-native-ble-manager/expo/)

**一句话**　网页原型先走一遍操作，真机 App 再把这些动作接到系统蓝牙。

**面试题**　能在网页原型里扫到手机旁边的真实温度计吗？

这个原型使用模拟数据。真机示例才调用 Android 或 iOS 的蓝牙 API。

[下一篇　扫描](#react-native/thermometer-mvp/scan)
