# 青竹 Blue

**Cross-Platform BLE SDK** —— 一套「什么蓝牙场景都能接、接起来还很省事」的蓝牙开发工具包。

把扫描、连接、并发调度、批量配置、固件升级、实时通知这些底层复杂性封在 SDK 内部，开发者只写几行业务代码。站点同时承载各平台的文档与工程实践。

> **当前状态**：Android 先行（3 篇示例文档 / 3 个类目）；其余平台在站点上预留了 Tab，显示 Coming soon。SDK 处于设计与骨架阶段，进度见 <https://github.com/qingzhu-ai-public/qingzhu-ble-android>。

**线上地址**：<https://qingzhu-ai-public.github.io/qingzhu-blue/>　（Pages 源 = 本仓 `main` 根目录）

## 目录结构

```
index.html                       站点外壳：导航 + 首页（静态），其余页面运行时渲染
assets/styles.css                样式表（沿用「青竹 Buddy 官网」设计系统，品牌色迁移为蓝系）
assets/md.js                     迷你 Markdown 渲染器（零依赖）
assets/site.js                   站点控制器：读清单 → 渲染类目树 / 类目页 / 文档页 / 路由
assets/docs-bundle.js            🔧 生成物：清单 + 正文（勿手改）
assets/logo.svg                  Logo
docs/platforms.json              平台表（Tab 顺序、平台名、未上线时的规划目录）
docs/<平台>/categories.json      类目表（文件夹 → 中文名 + 顺序 + 摘要）
docs/<平台>/<类目>/*.md          文档正文 ← 平时只动这里
tools/build-docs.js              🔧 扫描 docs/ → 生成 docs-bundle.js
.github/workflows/               push docs/ 后自动重建清单
_e2e_site.js                     站点验收脚本（真浏览器，172 项断言）
_ref/                            样式来源：色值迁移脚本 + 增量样式
```

**目录即结构**：`docs/<平台>/` 下的每个**文件夹就是一个类目**，文件夹里的 `.md` 就是该类目下的文章。站点上的一切（左栏目录、类目页、首页卡片）都由这个目录树推导出来。

```
docs/android/
├── categories.json          ← 给文件夹配中文名与顺序
├── 01-getting-started/      ← 类目「入门教程」
│   ├── 01-overview.md
│   └── 02-permissions.md
├── 02-experience/           ← 类目「个人经验」
│   └── 01-common-issues.md
└── 03-sdk-guide/            ← 类目「SDK 使用指南」（还没文章 → 站上显示「待补」）
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
   3 篇  android      3 个类目
         2 篇  入门教程   #android/getting-started
                10  order Android BLE 总览     ← docs/android/01-getting-started/01-overview.md
                20  order 权限与版本适配        ← docs/android/01-getting-started/02-permissions.md
         1 篇  个人经验   #android/experience
                30  order 常见问题排查          ← docs/android/02-experience/01-common-issues.md
          —   SDK 使用指南   #android/sdk-guide
```

**它还会顺手查死链**：正文里写的 `[xxx](#android/xxx/yyy)` 如果指向不存在的平台 / 类目 / 文档，构建会给出提示 —— 移动文档到另一个类目时最容易漏改这个，而这种链接在页面上是静默失效的。

## 在 GitHub 上怎么操作

### 新建文档（不用装任何东西）

1. 打开 `docs/android/01-getting-started/` 之类的类目文件夹 → 右上角 **Add file → Create new file**
2. 文件名填 `03-mtu.md`（文件名里打 `/` 可以顺手建出新文件夹）
3. 内容里贴 front matter + 正文 → 页面底部 **Commit changes**
4. 等约 1 分钟，Actions 自动重建清单，站点就更新了

### 改排序 / 改类目

| 想做什么 | 在 GitHub 网页上怎么做 |
|---|---|
| 调一篇在类目内的顺序 | 打开那个 `.md` → 铅笔 → 把 `order: 30` 改成 `order: 15` → Commit |
| 用文件名排序 | 打开文件 → 文件名旁的铅笔/下拉 → **Rename** → 改成 `01-xxx.md` → Commit |
| 把一篇换到别的类目 | 打开文件 → 文件名旁的铅笔/下拉 → **Rename** → 在名字里写上新类目路径，如 `02-experience/04-mtu.md` → Commit |
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

# 真浏览器验收（172 项断言 + 截图到 _shots/）
node _e2e_site.js
```

预览：**直接双击 `index.html` 即可**。站点不联网、不发任何运行时请求（清单和正文都在构建期打进了 `assets/docs-bundle.js`），`file://` 下和 GitHub Pages 上行为完全一致。

## 站点形态

```
首页 | Bluetooth | Android | iOS | HarmonyOS | Flutter | React Native
```

**首页**是营销落地页，主线是「这套 SDK 解决了什么」；**其余所有页面共用同一套文档双栏版式**（不跟首页共用营销版式）。

首页六个板块**全部是手写在 `index.html` 里的静态内容**，改文案直接改那里：

| 板块 | 说什么 |
|---|---|
| Hero | 价值主张「把复杂交给 SDK，开发者只写几行」+ 一段示意代码（业务侧到底要写多少） |
| Pain Points | 连上之后才暴露的四类难题：并发上限 / 掉线重连 / 地址变更找回 / 批量失败处理 |
| What It Handles | **六类场景**（连一台 / 连多台 / 批量刷配置 / 顺序查询 / 固件升级 / 设备主动上报），每类配生活化比喻 + 开发者用途 + 能力标签 |
| Inside the SDK | 「外面几行，里面是这些」：连接 / 数据 / 批量 / 通用四组内部机制，并标注 Android 先行 |
| Supported Platforms | 平台卡，由各平台文档篇数驱动 |
| GET STARTED | 指向 GitHub 组织 |

> 只动首页板块时**不需要碰构建**：`assets/site.js` 只负责往 `[data-home="platforms"]` 里填平台卡、以及给 hero 主按钮选落地页。
> 新板块的样式加在 `_ref/extra.css`（类名前缀 `scene*` / `hp-*`），改完跑 `python _ref/build_css.py` 重新生成。

```
┌──────────────────┬────────────────────────────────────────────┐
│ Android 文档      │                                            │
│ ▾ 入门教程     2 │  #android                → 平台页：类目卡片    │
│    Android BLE 总览│  #android/<类目>          → 类目页：文档列表   │
│    权限与版本适配  │  #android/<类目>/<slug>   → 文档正文          │
│ ▾ 个人经验     1 │                                            │
│    常见问题排查    │  没文档的平台（iOS 等）→ Coming soon，       │
│    SDK 使用指南 待补│  此时左栏整块收起（左栏只列有内容的平台）  │
└──────────────────┴────────────────────────────────────────────┘
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
| `qingzhu-ble-android` | Android SDK（`qz-ble-sdk/`）+ 完整 Demo（`example/` → QZBleDemo） |
| `qingzhu-ble-ios` / `-harmonyos` / `-flutter` / `-react-native` | 暂不创建，站点留位 |

**Example 不单独成仓**：Demo 是 SDK 的一部分，跟 SDK 一起发版。

## 协议

**尚未选定** —— 本仓当前没有 `LICENSE` 文件，未附许可证即默认「保留所有权利」。
SDK 仓（`qingzhu-ble-android`）若要让别人真正使用 SDK，需要单独选定并附上许可证（MIT / Apache-2.0 等）。
