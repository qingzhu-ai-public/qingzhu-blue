# 青竹蓝牙开发指南

**《青竹全栈开发指南》的蓝牙分支** —— 目标是把所有技术栈里的蓝牙知识收进一处，让学习蓝牙开发的人，以后只要来这里浏览就够了。

本站覆盖经典蓝牙、BLE、协议栈、Android / iOS / Web / 嵌入式等平台视角、权限、后台、抓包、测试、性能与工程实践；同时提供 **青竹 Android BLE SDK**，把扫描、连接、队列、重试、多设备调度和异常治理收进一个任务式内核。学完教程，就能直接使用现成框架落地。

未来还会有《青竹AI应用开发指南》，各指南分支共用同一套「知识讲全、工程做实、工具交到手里」的方法。

> **当前内容**：[Bluetooth 通用知识](https://qingzhu-ai-public.github.io/qingzhu-blue/#bluetooth) 8 篇，覆盖选型、发现与连接、数据收发、安全和排障。Android 有 50 篇文档，包含《Android 蓝牙指南》30 章书系。SDK 和试玩 App 见 [青竹 Android BLE SDK](https://github.com/qingzhu-ai-public/qingzhu-ble-android)。

**Android 综合实战**：[温湿度计教程](https://qingzhu-ai-public.github.io/qingzhu-blue/#android/bthome-mvp/overview) · [Android Studio 示例](examples/android/bthome-mvp/README.md)

**iOS**：[24 章开发指南](https://qingzhu-ai-public.github.io/qingzhu-blue/#ios/development-guide/overview) · [API 速查](https://qingzhu-ai-public.github.io/qingzhu-blue/#ios/development-guide/api-reference) · [温湿度计实战](https://qingzhu-ai-public.github.io/qingzhu-blue/#ios/thermometer-mvp/overview) · [Xcode 示例](examples/ios/thermometer-mvp/README.md)

**HarmonyOS**：[12 章开发指南](https://qingzhu-ai-public.github.io/qingzhu-blue/#harmonyos/development-guide/overview) · [API 速查](https://qingzhu-ai-public.github.io/qingzhu-blue/#harmonyos/development-guide/api-reference) · [温湿度计实战](https://qingzhu-ai-public.github.io/qingzhu-blue/#harmonyos/thermometer-mvp/overview) · [ArkTS 示例](examples/harmonyos/thermometer-mvp/README.md)

**线上地址**：<https://qingzhu-ai-public.github.io/qingzhu-blue/>　（Pages 源 = 本仓 `main` 根目录）

## 目录结构

```
index.html                       站点外壳：导航 + 首页（静态），其余页面运行时渲染
assets/styles.css                样式表（沿用「青竹 Buddy 官网」设计系统，品牌色统一为青竹绿系）
assets/md.js                     迷你 Markdown 渲染器（零依赖）
assets/site.js                   站点控制器：读清单 → 渲染类目树 / 类目页 / 文档页 / 路由
assets/docs-bundle.js            🔧 生成物：清单 + 正文（勿手改）
assets/logo.svg                  Logo
docs/platforms.json              平台表（Tab 顺序、平台名、未上线时的规划目录）
docs/<平台>/categories.json      类目表（文件夹 → 中文名 + 顺序 + 摘要）
docs/<平台>/<类目>/*.md          文档正文 ← 平时只动这里
tools/build-docs.js              🔧 扫描 docs/ → 生成 docs-bundle.js
.github/workflows/               push docs/ 后自动重建清单
_e2e_site.js                     站点验收脚本（真浏览器）
_ref/                            样式来源：色值迁移脚本 + 增量样式
```

**目录即结构**：`docs/<平台>/` 下的每个**文件夹就是一个类目**，文件夹里的 `.md` 就是该类目下的文章。站点上的一切（左栏目录、类目页、首页卡片）都由这个目录树推导出来。

```
docs/android/
├── categories.json          ← 给文件夹配中文名与顺序
├── 01-development-guide/    ← 类目「开发指南」（37 篇书系）
│   ├── 00-guide.md
│   ├── 01-overview.md
│   ├── …
│   └── 95-appendix-f-faq.md
├── 02-sdk-guide/            ← 类目「SDK 使用指南」
│   ├── 01-overview.md
│   ├── 02-quickstart.md
│   ├── 03-task-and-command.md
│   ├── 04-multi-device.md
│   └── 05-protocol-plugin.md
└── 03-experience/           ← 类目「工程实践」
    ├── 01-from-runnable-to-production.md
    └── 01-common-issues.md
```

文件夹名的 `NN-` 前缀只用来给文件夹排序，站点上不显示；真实显示名来自 `categories.json`。

## 加一篇文档

**两步，不用碰任何代码。**

1. 把 `.md` 丢进某个类目文件夹（没有合适的就新建一个，见下一节）
2. 顶部写 front matter：

```markdown
---
title: MTU 协商与分包
order: 40
summary: 一行摘要，会显示在目录卡片上
tags: 必读, 进阶
updated: 2026-09-25
---

# MTU 协商与分包

正文……
```

就完了。跑一次构建（或推到 GitHub 等 Actions 跑），文章自动出现在对应类目下 —— **不需要改 index.html，不需要碰任何清单文件**。

### front matter 字段

| 字段 | 必填 | 说明 |
|---|---|---|
| `title` | 否 | 目录里的标题。缺省取正文第一个 `# 标题`，再缺省取文件名 |
| `order` | 否 | **类目内排序用**，整数，越小越靠前。缺省 1000 |
| `summary` | 否 | 目录卡片下的一行摘要 |
| `tags` | 否 | 逗号分隔，目录卡片右侧的小标签。第一个会用高亮样式 |
| `updated` | 否 | 显示在文档页页脚 |
| `slug` | 否 | URL 里的名字（`#android/<类目>/<slug>`）。缺省由文件名推导 |

## 加一个类目

1. 在 `docs/android/` 下建一个文件夹，例如 `04-ota/`（`04-` 只用于排序，可省略）
2. 打开 `docs/android/categories.json`，在数组里登记中文名：

```json
{ "id": "ota", "name": "OTA 升级", "summary": "一类目一句话说明，显示在类目卡片上" }
```

`id` = 文件夹名去掉数字前缀。**数组顺序 = 左栏与类目页的顺序。**

> 不登记也能用：站点会直接拿文件夹名当显示名（并在构建时提示你补中文名）。
> 反过来，`categories.json` 里登记了但文件夹不存在，就是「该类目还没有文章」—— 站上显示「待补」，不是错误。

## 排序怎么做

**两级，各管各的。**

| 层级 | 由谁决定 | 怎么调 |
|---|---|---|
| 类目之间的顺序 | `categories.json` 数组顺序 | 调整数组里那几行的位置 |
| 类目内文章的顺序 | 各篇 front matter 的 `order` | 改那个数字 |

类目内排序规则是 `order` 升序，**`order` 相同时按文件名自然序**（`2-` 排在 `10-` 前面，不是字符串比较）。所以两种写法都能用：

**写法 A：用文件名排序**（不写 `order`，靠 `01-` `02-` 前缀）

```
01-overview.md   02-permissions.md   03-common-issues.md
```

**写法 B：用 `order` 排序**（文件名随便起，顺序由 `order` 决定）

```markdown
---
title: MTU 协商与分包
order: 15          ← 插到 10 和 20 之间，不用重命名任何文件
---
```

> **推荐 B**。想在两篇之间插一篇，只改一个数字，不用给一堆文件重新编号。

构建时会打印每篇的排序结果和排序依据，直接核对：

```
$ node tools/build-docs.js
  50 篇  android      4 个类目
        37 篇  开发指南   #android/development-guide
               10  order 导读 先接通一台设备      ← docs/android/01-development-guide/00-guide.md
               20  order Android 蓝牙全景        ← docs/android/01-development-guide/01-overview.md
               …
              370  order 附录 F 从现象查故障      ← docs/android/01-development-guide/95-appendix-f-faq.md
         5 篇  SDK 使用指南   #android/sdk-guide
               10  order 青竹 BLE SDK 总览      ← docs/android/02-sdk-guide/01-overview.md
               20  order 快速接入               ← docs/android/02-sdk-guide/02-quickstart.md
               30  order 任务与命令              ← docs/android/02-sdk-guide/03-task-and-command.md
               40  order 多设备调度              ← docs/android/02-sdk-guide/04-multi-device.md
               50  order 协议插件               ← docs/android/02-sdk-guide/05-protocol-plugin.md
         2 篇  工程实践   #android/experience
               10  order AI 时代：生产级 BLE SDK ← docs/android/03-experience/01-from-runnable-to-production.md
               30  order 常见问题排查           ← docs/android/03-experience/01-common-issues.md
```

**它还会顺手查死链**：正文里写的 `[xxx](#android/xxx/yyy)` 如果指向不存在的平台 / 类目 / 文档，构建会给出提示 —— 移动文档到另一个类目时最容易漏改这个，而这种链接在页面上是静默失效的。

## 在 GitHub 上怎么操作

### 新建文档（不用装任何东西）

1. 打开 `docs/android/01-development-guide/` 之类的类目文件夹 → 右上角 **Add file → Create new file**
2. 文件名填 `03-mtu.md`（文件名里打 `/` 可以顺手建出新文件夹）
3. 内容里贴 front matter + 正文 → 页面底部 **Commit changes**
4. 等约 1 分钟，Actions 自动重建清单，站点就更新了

### 改排序 / 改类目

| 想做什么 | 在 GitHub 网页上怎么做 |
|---|---|
| 调一篇在类目内的顺序 | 打开那个 `.md` → 铅笔 → 把 `order: 30` 改成 `order: 15` → Commit |
| 用文件名排序 | 打开文件 → 文件名旁的铅笔/下拉 → **Rename** → 改成 `01-xxx.md` → Commit |
| 把一篇换到别的类目 | 打开文件 → 文件名旁的铅笔/下拉 → **Rename** → 在名字里写上新类目路径，如 `03-experience/04-mtu.md` → Commit |
| 调整类目顺序 | 打开 `docs/android/categories.json` → 铅笔 → 调整 `categories` 数组里那几行的先后 → Commit |
| 给类目改中文名 | 同上，改 `"name"` 字段 |
| 一次调多篇 | 建议本地改完一次性 push，比在网页上点十次省事 |

改完提交即可，**不需要动 `assets/docs-bundle.js`** —— Actions 会重新生成并提交它。

### 想加一个新平台 Tab

编辑 `docs/platforms.json`，在数组里加一项：

```json
{
  "id": "rust",
  "name": "Rust",
  "title": "Rust BLE 开发",
  "summary": "未上线时显示在 Coming soon 面板上的说明",
  "plan": ["Overview", "btleplug", "Common Issues"]
}
```

然后建 `docs/rust/categories.json` 与 `docs/rust/<类目>/`。**数组顺序 = 导航栏 Tab 顺序。** 平台下没有任何文档时，该 Tab 自动显示 Coming soon（含上面的 `plan` 作为规划目录）；一旦放了第一篇，Coming soon 自动消失。

## 本地

```bash
# 加了/改了文档后，重新生成清单
node tools/build-docs.js

# 只校验不写盘（CI 用）
node tools/build-docs.js --check

# 改了 _ref/extra.css 后重新生成样式表
python _ref/build_css.py

# 真浏览器验收（截图到 _shots/）
node _e2e_site.js
```

预览：**直接双击 `index.html` 即可**。站点不联网、不发任何运行时请求（清单和正文都在构建期打进了 `assets/docs-bundle.js`），`file://` 下和 GitHub Pages 上行为完全一致。

## 站点形态

```
首页 | Bluetooth | Android | iOS | HarmonyOS | Flutter | React Native
```

**首页**是《青竹蓝牙开发指南》门户，主线是「全技术栈蓝牙知识 → 青竹 Android BLE SDK 落地」；**其余所有页面共用同一套文档双栏版式**（不跟首页共用门户版式）。

首页七个板块**全部是手写在 `index.html` 里的静态内容**，改文案直接改那里：

| 板块 | 说什么 |
|---|---|
| Hero | 「学蓝牙，来这里就够了」+ 指南分支关系 + 任务式 SDK 代码卡 |
| Why This Guide | 知识散 / 经典蓝牙缺 / BLE 只到 Demo / 学完还要造轮子 / 教程框架割裂 |
| Guide → Framework | 3 个学习入口 + 3 个 SDK 落地入口 |
| Android BLE SDK | 指南体系 / 任务式内核 / 多设备调度 / 异常兼容 / 协议扩展 |
| Learning Path | 30 章指南 → 10 个实验 → 任务式 SDK → 自有协议插件 |
| All Bluetooth Stacks | 平台卡，由各平台文档篇数驱动 |
| START HERE | 从教程入门，用 SDK 交付 |

> 只动首页板块时**不需要碰构建**：`assets/site.js` 只负责往 `[data-home="platforms"]` 里填平台卡、以及给 hero 主按钮选落地页。
> 新板块的样式加在 `_ref/extra.css`（类名前缀 `scene*` / `hp-*`），改完跑 `python _ref/build_css.py` 重新生成。

```
┌──────────────────────┬────────────────────────────────────────┐
│ Android 文档             │                                        │
│ ▾ 蓝牙入门与连接   4 │  #bluetooth                     平台页 │
│    导读              │  #bluetooth/fundamentals         类目页 │
│    …                 │  #bluetooth/fundamentals/reading-guide  │
│ ▾ BLE 数据与安全   4 │                                 文档正文 │
│ ▾ 开发指南        37 │                                        │
│ ▾ SDK 使用指南     5 │  空平台显示 Coming soon，左栏收起       │
│ ▾ 工程实践         2 │                                        │
└──────────────────────┴────────────────────────────────────────┘
```

- **左栏**：只列**有内容的平台**，一级是类目、二级是文章；空类目标「待补」。桌面下 sticky 跟随滚动，
  当前项自动高亮；点类目前的 **▾** 可折叠/展开（跳进该类目的文章时会自动展开，不会把当前项藏起来）
- **右栏**：平台页（类目卡片）/ 类目页（文章列表）/ 文档正文；没有内容的平台只有一张 Coming soon，左栏整块收起
- **深链**：`#android` → 平台页，`#android/experience` → 类目页，`#android/experience/common-issues` → 某篇正文，都可直接分享
- **≤900px**：左栏折成顶部「文档目录」按钮，点开抽屉
- **SDK 不做一级 Tab**：SDK 属于平台，归到对应平台页下
- 平台页上那些「不属于文档」的固定板块（如 Android 的 SDK 仓结构）写在
  `index.html` 的 `<template data-platform-intro="android">` 里，渲染完类目卡后追加进右栏

## 关联仓库（规划中）

| 仓库 | 说明 |
|---|---|
| `qingzhu-blue` | 本仓：官网 + 文档 + Bluetooth 通用知识 |
| `qingzhu-ble-android` | Android SDK（`qingzhu-core` / `qingzhu-company-sdk` / 协议插件）+ 3 个试玩 App |
| `qingzhu-ble-ios` / `-harmonyos` / `-flutter` / `-react-native` | 暂不创建，站点留位 |

**Example 不单独成仓**：Demo 是 SDK 的一部分，跟 SDK 一起发版。

## 协议

**尚未选定** —— 本仓当前没有 `LICENSE` 文件，未附许可证即默认「保留所有权利」。
SDK 仓（`qingzhu-ble-android`）若要让别人真正使用 SDK，需要单独选定并附上许可证（MIT / Apache-2.0 等）。
