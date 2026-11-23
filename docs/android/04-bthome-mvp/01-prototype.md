---
title: 原型与工程入口
slug: prototype
order: 10
summary: 看完整原型代码，点通流程，再运行 Android 工程。
---

# 原型与工程入口　先看这个 App 怎样使用

手机 A 打开 App 后先看到附近设备。找到教学温湿度计，点连接进入详情，再点请求新读数。手机 B 用同一个 App 的模拟外设模式回应它。

先在浏览器打开[交互原型](https://qingzhu-ai-public.github.io/qingzhu-blue/examples/android/bthome-mvp/prototype/index.html)，点通一次。原型使用模拟数据，可以先观察每次点击后页面应该发生什么。

## 本篇完整代码

下面是原型页面的完整文件，保存为 HTML 后可以用浏览器打开。后面的 Android App 按这个操作顺序实现。

```html
<!doctype html>
<html lang="zh-CN">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>蓝牙温湿度计 · 交互原型</title>
<style>
:root{color-scheme:light;font-family:Inter,"Microsoft YaHei",sans-serif;color:#182b24;background:#e4ede7}
*{box-sizing:border-box}body{margin:0;padding:32px 16px}
main{display:grid;grid-template-columns:minmax(0,290px) minmax(0,400px);gap:52px;align-items:center;justify-content:center;min-height:calc(100vh - 64px)}
h1{font-size:34px;line-height:1.25;letter-spacing:-.05em;margin:8px 0 14px}p{line-height:1.65;margin:0}aside p,small{color:#4d6359}aside small{font-size:14px}
.phone{background:#f5f8f4;border:1px solid #bdcdc3;border-radius:30px;padding:24px;min-height:575px;box-shadow:0 20px 44px #294d3420;display:flex;flex-direction:column}
header{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:20px}
h2{font-size:23px;margin:0;line-height:1.25}h3{font-size:16px;margin:0 0 6px}
button{font:inherit;cursor:pointer;min-height:46px;border:0;border-radius:12px;padding:10px 14px}
button:focus-visible{outline:3px solid #3b6f55;outline-offset:2px}button:disabled{opacity:.55;cursor:default}
.primary{background:#216045;color:white;font-weight:650;width:100%}.quiet{background:#e1ebe4;color:#234d3a}
.card{margin:14px 0;padding:16px;background:white;border:1px solid #d8e5dc;border-radius:16px;width:100%;color:inherit;text-align:left}
.reading{font-size:35px;font-weight:750;letter-spacing:-.05em;display:block;margin:8px 0;font-variant-numeric:tabular-nums}
code{font-family:"IBM Plex Mono",monospace;color:#3a6250;line-height:1.5}
.label{color:#476355;font-size:14px}nav{margin-top:auto;padding-top:24px}
nav button{width:100%}[hidden]{display:none!important}
@media(max-width:740px){main{grid-template-columns:minmax(0,400px);gap:20px;min-height:auto}h1{font-size:26px}.phone{min-height:520px;padding:20px}body{padding-top:20px}}
</style>
<main>
  <aside>
    <small>Android 蓝牙实战 · 交互原型</small>
    <h1>读到第一组温湿度</h1>
    <p>先看广播读数，点选设备连接，再主动请求一组新数据。原型使用模拟数据。</p>
  </aside>
  <section class="phone" aria-label="蓝牙温湿度计">
    <header><h2 id="title">附近设备</h2><button id="back" class="quiet" hidden>返回列表</button></header>
    <p id="status" role="status" class="label">扫描附近的 BTHome 设备。</p>
    <section id="list">
      <button id="device" class="card" hidden>
        <strong>教学温湿度计</strong> <small>· 可连接</small>
        <span class="reading">25.00 °C</span><code>40 02 C4 09</code>
      </button>
      <div id="empty" class="card"><h3>还没有扫描结果</h3><small>也可以用第二台手机模拟温湿度计。</small></div>
      <button class="primary" id="scan">开始扫描</button>
    </section>
    <section id="detail" hidden>
      <div class="card">
        <h3>连接读数</h3><span class="reading" id="temperature">等待测量</span>
        <p id="humidity" class="label"></p><code id="payload"></code>
      </div>
      <button class="primary" id="request" disabled>请求新读数</button>
    </section>
    <section id="peripheral" hidden>
      <div class="card"><h3>广播温度</h3><span class="reading">25.00 °C</span><code>40 02 C4 09</code></div>
      <button class="primary" id="broadcast">启动广播</button>
    </section>
    <nav><button class="quiet" id="mode">模拟温湿度计</button></nav>
  </section>
</main>
<script>
const byId = id => document.getElementById(id);
const status = byId("status");
let pending, requestCount = 0, broadcasting = false;
function showPage(page, actionStatus) {
  clearTimeout(pending);
  for (const name of ["list", "detail", "peripheral"]) byId(name).hidden = (name !== page);
  byId("title").textContent = {list:"附近设备",detail:"教学温湿度计",peripheral:"模拟温湿度计"}[page];
  byId("back").hidden = page === "list";
  byId("mode").hidden = page !== "list";
  status.textContent = actionStatus;
}
byId("scan").onclick = () => {
  clearTimeout(pending);
  byId("device").hidden = true;
  status.textContent = "正在扫描附近设备…";
  pending = setTimeout(() => {
    byId("device").hidden = false;
    byId("empty").hidden = true;
    status.textContent = "找到 1 台设备。点选教学外设连接。";
    byId("scan").textContent = "重新扫描";
  }, 500);
};
byId("device").onclick = () => {
  showPage("detail", "正在连接并查找温湿度特征…");
  requestCount = 0;
  byId("temperature").textContent = "等待测量";
  byId("humidity").textContent = "";
  byId("payload").textContent = "";
  byId("request").disabled = true;
  pending = setTimeout(() => {
    status.textContent = "已就绪，可以请求新读数。";
    byId("request").disabled = false;
  }, 420);
};
byId("request").onclick = () => {
  byId("request").disabled = true;
  status.textContent = "正在发送 01，等待设备回包…";
  pending = setTimeout(() => {
    const warmer = ++requestCount % 2 !== 0;
    byId("temperature").textContent = warmer ? "26.50 °C" : "25.00 °C";
    byId("humidity").textContent = "50.55% RH";
    byId("payload").textContent = warmer ? "40 02 5A 0A 03 BF 13" : "40 02 C4 09 03 BF 13";
    status.textContent = "读数已更新。";
    byId("request").disabled = false;
  }, 480);
};
byId("mode").onclick = () => showPage("peripheral", "等待启动广播。");
byId("broadcast").onclick = () => {
  broadcasting = !broadcasting;
  status.textContent = broadcasting ? "正在广播，等待另一台手机连接。" : "广播已停止。";
  byId("broadcast").textContent = broadcasting ? "停止广播" : "启动广播";
};
byId("back").onclick = () => {
  broadcasting = false;
  byId("broadcast").textContent = "启动广播";
  byId("device").hidden = true;
  byId("empty").hidden = false;
  byId("scan").textContent = "开始扫描";
  showPage("list", "扫描附近的 BTHome 设备。");
};
</script>
</html>
```

## 页面先分成三处

附近设备负责找设备，设备详情负责发请求和显示结果，模拟外设负责让另一台手机有东西可连接。这三个页面围绕同一条流程。

设备列表里的 25.00 °C 来自广播。详情里按按钮后显示的 26.50 °C 和湿度来自一次连接后的请求。两处的字节都显示出来，学到解析时可以直接对照。

## 按钮点下去，结果要等多久

原型里的扫描按钮暂时显示正在扫描，随后出现一台设备。JavaScript 的 setTimeout 用一小段延时模拟等待，真实 App 要等 Android 蓝牙回调。

进入详情后先禁用请求按钮，等模拟连接完成才允许点。请求期间再次禁用，结果出现后恢复。这就对应后面代码的连接、发现服务、等待操作结果几个阶段。

返回列表时清除等待中的定时任务，避免上一页已经关了、旧结果又跑出来。原生 App 同样需要处理旧回调和退出清理。

## 工程里该打开哪些文件

在 Android Studio 打开 bthome-mvp 目录，等 Gradle 同步完成，运行 app。构建需要 JDK 17+ 和 Android SDK Platform 36，手机最低 Android 8.0。

| 文件 | 它在这个功能里做什么 |
| --- | --- |
| SensorActivity.java | 接收点击、申请权限、显示页面 |
| SensorClient.java | 手机 A 扫描、连接和读写 |
| SensorPeripheral.java | 手机 B 广播服务并回应请求 |
| DemoProtocol.java | 两端约定的编号和指令 |
| BthomeDecoder.java | 按字节解释温湿度 |

各篇开头直接列出本篇涉及的完整文件，后面按点击顺序解释关键方法。在完整代码中遇到下一篇的功能，可以等用到时再读它的讲解。

## 先让 App 跑在手机上

按[安装步骤](https://github.com/qingzhu-ai-public/qingzhu-blue/tree/main/examples/android/bthome-mvp)把同一个 APK 装到两台手机。手机 B 开模拟外设并启动广播，手机 A 开始扫描。至少一台手机要支持 BLE 外设广播，扫描不到时可以交换角色。两台先保持前台。

普通明文 BTHome 设备也能用来观察广播。主动连接与请求使用教学服务，手机 B 的模拟外设实现了它。

**一句话记住**　先把每次点击后应该出现的结果想清楚，再用真实蓝牙回调实现这些变化。

## 面试题

1. **原型里的温度能证明手机蓝牙工作正常吗？** 原型展示的是模拟交互，真实扫描与收发要在 Android 手机验收。
2. **为什么请求期间要禁用按钮？** 避免用户重复点击，让两次请求重叠，导致界面难以判断结果属于哪次操作。

继续读[扫描篇](#android/bthome-mvp/scanning)。
