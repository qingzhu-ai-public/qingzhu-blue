# React Native 蓝牙温湿度计示例

## 装到真机上

1. 把示例工程下载到电脑。打开含 `package.json` 的目录，用 Node.js 20.19 或 Expo SDK 55 支持的更高版本。
2. 执行 `npm install`。这个工程已经包含 Expo 开发客户端和 `react-native-ble-manager` 配置插件。
3. Android 手机打开 USB 调试，执行 `npm run android -- --device`。iPhone 用 Mac 和 Xcode 配好签名，再执行 `npm run ios -- --device`。
4. 用 `npm start` 启动 Metro，然后在手机上打开刚装好的开发客户端。修改插件配置或增加原生库后，重新生成并构建对应平台的原生工程。Expo Go 的安装包不含本课的第三方 BLE 模块。

看到「蓝牙温湿度计」和「开始扫描」按钮，工程入口就跑通了。再准备一台支持外设角色的手机，打开已有的原生温湿度计示例并启动模拟外设。[Android 示例](https://qingzhu-ai-public.github.io/qingzhu-blue/#android/bthome-mvp/overview) · [iOS 示例](https://qingzhu-ai-public.github.io/qingzhu-blue/#ios/thermometer-mvp/overview) · [HarmonyOS 示例](https://qingzhu-ai-public.github.io/qingzhu-blue/#harmonyos/thermometer-mvp/overview)[Expo 开发构建](https://docs.expo.dev/develop/development-builds/introduction/) · [BLE Manager 的 Expo 配置](https://innoveit.github.io/react-native-ble-manager/expo/)

[原型](prototype/index.html) · [逐篇实战](https://qingzhu-ai-public.github.io/qingzhu-blue/#react-native/thermometer-mvp/overview)
