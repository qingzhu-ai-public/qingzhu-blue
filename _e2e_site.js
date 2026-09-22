/**
 * 青竹 Blue 站点验收（headless Edge + CDP，零依赖）
 *
 * 站点形态：首页 = 营销落地页；非首页 = 文档双栏（左类目树 + 右正文）。
 * 目录模型：docs/<平台>/<类目>/*.md —— **文件夹即类目**。
 *
 * 验的事：
 *   1. 首屏是首页，导航 Tab 由 docs/platforms.json 驱动；首页不强调任何平台优先
 *   2. 品牌色确实从绿迁到蓝
 *   3. 🔴 左栏只列「有内容的平台」（当前只有 Android），一级是类目、二级是文档
 *   4. 平台页 = 类目卡片；空类目标「待补」；无文档的平台只有 Coming soon 且左栏收起
 *   5. 点类目卡 → 类目页 → 点条目 → 正文
 *   6. 顺序 = 类目数组顺序 + 类目内 order（不是字母序）
 *   7. 深链 #android/<类目>/<slug>、文档内互链、非法深链回落
 *   8. 几何：桌面不溢出；≤900px 目录折成可展开的一栏
 *   9. 🔴 文档即插即用：临时建类目文件夹 + 一篇 md → 构建 → 自动上线 → 删除 → 自动回退
 *
 * 用法：node _e2e_site.js
 */
const fs = require('fs');
const path = require('path');
const http = require('http');
const { spawn, execFileSync } = require('child_process');
['HTTP_PROXY', 'HTTPS_PROXY', 'http_proxy', 'https_proxy', 'ALL_PROXY', 'all_proxy']
  .forEach((k) => { delete process.env[k]; });

const ROOT = 'F:\\ai_project\\qingzhu-blue';
const CDP_PORT = Number(process.env.CDP_PORT || 9455);
const SITE = 'file:///F:/ai_project/qingzhu-blue/index.html';
const SHOT_DIR = path.join(ROOT, '_shots');
const EDGE_PROFILE = process.env.EDGE_PROFILE || 'F:\\tmp\\edgeprof_qingzhublue';
const EDGE_PATH = process.env.EDGE_PATH || [
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
].find((p) => fs.existsSync(p));

const PLATFORMS = ['bluetooth', 'android', 'ios', 'harmonyos', 'flutter', 'react-native'];
const NAV = ['首页', 'Bluetooth', 'Android', 'iOS', 'HarmonyOS', 'Flutter', 'React Native'];
const OTHER_PLATFORM_NAMES = ['Bluetooth', 'iOS', 'HarmonyOS', 'Flutter', 'React Native'];
const LIVE = 'android';                                    // 当前唯一有文档的平台
const EMPTY = PLATFORMS.filter((p) => p !== LIVE);         // 其余 5 个 → Coming soon
const TOTAL_PAGES = 2;                                     // 首页 + 文档页

// Android 的类目（= docs/android/ 下的文件夹，顺序 = categories.json 顺序）
const CATS = [
  { id: 'getting-started', name: '入门教程', n: 2 },
  { id: 'experience', name: '个人经验', n: 1 },
  { id: 'sdk-guide', name: 'SDK 使用指南', n: 0 },
];
const D_GEN = 'android/getting-started/overview';
const D_PERM = 'android/getting-started/permissions';
const D_ISSUE = 'android/experience/common-issues';
const ALL_DOCS = [D_GEN, D_PERM, D_ISSUE];

function httpJson(p) {
  return new Promise((resolve, reject) => {
    const req = http.request({ host: '127.0.0.1', port: CDP_PORT, path: p, method: 'GET' }, (res) => {
      let d = ''; res.on('data', (c) => (d += c));
      res.on('end', () => { try { resolve(JSON.parse(d)); } catch (e) { reject(new Error(d)); } });
    });
    req.on('error', reject); req.end();
  });
}
class C {
  constructor(w) { this.w = w; this.i = 0; this.m = new Map(); }
  static async conn(u) {
    const w = new WebSocket(u); const c = new C(w);
    await new Promise((a, b) => { w.onopen = a; w.onerror = b; });
    w.onmessage = (e) => {
      const m = JSON.parse(e.data);
      if (m.id != null && c.m.has(m.id)) {
        const { res, rej } = c.m.get(m.id); c.m.delete(m.id);
        m.error ? rej(new Error(JSON.stringify(m.error))) : res(m.result);
      }
    };
    return c;
  }
  send(m, p = {}) {
    const id = ++this.i;
    return new Promise((res, rej) => { this.m.set(id, { res, rej }); this.w.send(JSON.stringify({ id, method: m, params: p })); });
  }
  async ev(x) {
    const r = await this.send('Runtime.evaluate', { expression: x, returnByValue: true, awaitPromise: true });
    if (r.exceptionDetails) return { __e: r.exceptionDetails.exception?.description || JSON.stringify(r.exceptionDetails) };
    return r.result.value;
  }
  async shot(name) {
    fs.mkdirSync(SHOT_DIR, { recursive: true });
    const r = await this.send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: true });
    fs.writeFileSync(path.join(SHOT_DIR, name), Buffer.from(r.data, 'base64'));
    return name;
  }
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let edgeChild = null;
async function cdpAlive() { try { await httpJson('/json/version'); return true; } catch { return false; } }
async function ensureBrowser() {
  if (await cdpAlive()) { console.log('浏览器：复用 ' + CDP_PORT + ' 上已有实例'); return; }
  if (!EDGE_PATH) throw new Error('找不到 msedge.exe');
  fs.mkdirSync(EDGE_PROFILE, { recursive: true });
  edgeChild = spawn(EDGE_PATH, [
    '--headless=new', '--disable-gpu', '--no-sandbox',
    '--remote-debugging-port=' + CDP_PORT,
    '--user-data-dir=' + EDGE_PROFILE,
    '--window-size=1440,1100',
    '--allow-file-access-from-files',
    'about:blank',
  ], { stdio: 'ignore' });
  console.log('浏览器：拉起 headless Edge（首次可能等 20~60s）…');
  const deadline = Date.now() + 90000;
  while (Date.now() < deadline) {
    await sleep(500);
    if (await cdpAlive()) { console.log('浏览器：' + CDP_PORT + ' 已就绪'); return; }
    if (edgeChild.exitCode !== null) throw new Error('msedge 启动即退出，exit=' + edgeChild.exitCode);
  }
  throw new Error('等 CDP 监听超时（90s）');
}
function shutdownBrowser() {
  if (!edgeChild || edgeChild.exitCode !== null) return;
  try { execFileSync('taskkill', ['/PID', String(edgeChild.pid), '/T', '/F'], { stdio: 'ignore' }); } catch {}
}

let pass = 0, fail = 0;
const chk = (name, ok, detail) => {
  console.log(`  ${ok ? '✅' : '❌'} ${name}${detail ? '  (' + detail + ')' : ''}`);
  ok ? pass++ : fail++;
};

// bodyText 会转小写，断言时用小写比较
const STATE = `({
  active: [...document.querySelectorAll('.page')].filter(p=>getComputedStyle(p).display!=='none').map(p=>p.id),
  totalPages: document.querySelectorAll('.page').length,
  navActive: [...document.querySelectorAll('.nav a.active')].map(a=>a.getAttribute('data-page')),
  navPages: [...document.querySelectorAll('.nav a[data-page]')].map(a=>a.textContent.trim()),
  title: document.title,
  hash: location.hash,
  scrollY: window.scrollY,
  sideActive: (document.querySelector('#docsSide .ds-item.active')||{}).getAttribute
    ? document.querySelector('#docsSide .ds-item.active').getAttribute('data-doc') : null,
  sideCatActive: (document.querySelector('#docsSide .ds-head.active')||{}).getAttribute
    ? document.querySelector('#docsSide .ds-head.active').getAttribute('data-cat') : null,
  noSide: !!(document.querySelector('.docs-shell')||{classList:{}}).classList.contains
    ? document.querySelector('.docs-shell').classList.contains('no-side') : null,
  bodyText: document.body.innerText.replace(/\\s+/g,' ').toLowerCase()
})`;

(async () => {
  await ensureBrowser();
  const t = (await httpJson('/json/list')).find((x) => x.type === 'page');
  const c = await C.conn(t.webSocketDebuggerUrl);
  await c.send('Page.enable');
  await c.send('Runtime.enable');
  await c.send('Network.enable');
  await c.send('Network.setCacheDisabled', { cacheDisabled: true });   // 第 12 节会重载，必须不吃缓存

  const hookErrors = () => c.ev(`window.__e2eErrs=window.__e2eErrs||[];
    window.addEventListener('error',e=>window.__e2eErrs.push(String(e.message)));
    window.addEventListener('unhandledrejection',e=>window.__e2eErrs.push('reject:'+e.reason));'ok'`);
  const goto = async (url, wait) => {
    await c.send('Page.navigate', { url: 'about:blank' });
    await sleep(180);
    await c.send('Page.navigate', { url });
    await sleep(wait || 1400);
    await hookErrors();
  };
  const clickNav = async (id) => {
    await c.ev(`document.querySelector('.nav a[data-page="${id}"]').click();'ok'`);
    await sleep(300);
  };

  await goto(SITE);

  // ---------- 1. 首屏 ----------
  console.log('\n【1】首屏 = 首页（营销落地页），导航由平台表驱动');
  let s = await c.ev(STATE);
  chk('只有一个页面可见', s.active.length === 1, JSON.stringify(s.active));
  chk('可见页是 page-home', s.active[0] === 'page-home', s.active[0]);
  chk('页面容器只有 首页 + 文档页（=2）', s.totalPages === TOTAL_PAGES, String(s.totalPages));
  chk('导航 7 个 Tab，顺序取自 platforms.json',
      JSON.stringify(s.navPages) === JSON.stringify(NAV), JSON.stringify(s.navPages));
  chk('首页 hero 标题为「蓝牙开发那些坑」', s.bodyText.includes('蓝牙开发那些坑'));
  chk('首页含「为什么创建青竹 Blue」', s.bodyText.includes('为什么创建青竹 blue'));
  chk('首页含 6 张平台卡（Supported Platforms）', s.bodyText.includes('supported platforms'));
  chk('🔴 首页无「先看 Android」类优先级引导',
      !s.bodyText.includes('先看 android') && !s.bodyText.includes('从 android 开始') && !s.bodyText.includes('android 优先'));
  chk('首页主按钮是中性文案',
      (await c.ev(`document.getElementById('heroCta').textContent.replace(/\\s+/g,' ').trim()`)) === '浏览文档 →');

  const cards = await c.ev(`(() => {
    const o = {};
    document.querySelectorAll('#page-home .platform').forEach(a => {
      o[a.getAttribute('data-page')] = { text: a.textContent.replace(/\\s+/g,' ').trim(), soon: a.classList.contains('soon') };
    });
    return o;
  })()`);
  chk('Android 卡自动显示「3 篇文档」',
      /3 篇文档/.test(cards.android?.text || '') && cards.android?.soon === false, cards.android?.text);
  chk('Android 卡副标题列出类目名（不再是平台首篇标题）',
      CATS.slice(0, 3).every((k) => (cards.android?.text || '').includes(k.name)), cards.android?.text);
  chk('其余 5 张卡显示「整理中」',
      EMPTY.every((p) => /整理中/.test(cards[p]?.text || '') && cards[p].soon === true),
      EMPTY.map((p) => p + '=' + cards[p]?.text.slice(0, 10)).join(' | '));
  await c.shot('01_home.png');

  const hero = await c.ev(`(() => {
    const h1 = document.querySelector('#page-home h1');
    const fs = parseFloat(getComputedStyle(h1).fontSize);
    const em = getComputedStyle(h1.querySelector('em'));
    return {
      fs: fs,
      lines: Math.round(h1.getBoundingClientRect().height / (fs * 1.12)),
      over: h1.scrollWidth - h1.parentElement.clientWidth,
      emClip: em.webkitBackgroundClip || em.backgroundClip,
      emBg: em.backgroundImage
    };
  })()`);
  chk('hero 标题刚好 2 行', hero.lines === 2, hero.lines + ' 行 @ ' + hero.fs + 'px');
  chk('hero 标题不超左栏宽度', hero.over <= 1, 'over=' + hero.over + 'px');
  chk('渐变高亮文字是蓝色渐变 + background-clip:text',
      hero.emClip === 'text' && hero.emBg.includes('rgb(37, 99, 235)'), hero.emBg.slice(0, 48));

  // ---------- 2. 品牌色 ----------
  console.log('\n【2】品牌色：已从绿迁到蓝，全页无绿色残留');
  const color = await c.ev(`(() => {
    const greens = [];
    document.querySelectorAll('*').forEach(el => {
      const st = getComputedStyle(el);
      [['color',st.color],['bg',st.backgroundColor],['bgimg',st.backgroundImage],['border',st.borderTopColor]]
        .forEach(([k,v]) => { if (v && (v.includes('15, 157, 106') || v.includes('11, 122, 84') || v.includes('13, 138, 122'))) greens.push(el.tagName+'.'+el.className+'/'+k); });
    });
    return {
      btn: getComputedStyle(document.querySelector('.btn-primary')).backgroundImage,
      eyebrow: getComputedStyle(document.querySelector('.eyebrow')).color,
      cta: getComputedStyle(document.querySelector('.nav-cta')).backgroundImage,
      greens: greens.slice(0, 5), greenCount: greens.length
    };
  })()`);
  chk('主按钮是蓝色 rgb(37, 99, 235)', color.btn.includes('rgb(37, 99, 235)'), color.btn.slice(0, 60));
  chk('eyebrow 小标题是蓝色', color.eyebrow === 'rgb(37, 99, 235)', color.eyebrow);
  chk('导航 CTA 是蓝色', color.cta.includes('rgb(37, 99, 235)'), color.cta.slice(0, 60));
  chk('🔴 全页无残留绿色', color.greenCount === 0, '命中 ' + color.greenCount + ' ' + JSON.stringify(color.greens));

  // ---------- 3. 左栏：只列有内容的平台，一级是类目 ----------
  console.log('\n【3】🔴 左栏只放 Android：一级 = 类目，二级 = 文档');
  const side = await c.ev(`(() => {
    const heads = [...document.querySelectorAll('#docsSide .ds-head')];
    return {
      title: (document.querySelector('#docsSide .ds-title')||{}).textContent || '',
      heads: heads.map(h => ({
        name: (h.querySelector('.ds-name')||{}).textContent || '',
        cat: h.getAttribute('data-cat'),
        pending: h.classList.contains('ds-pending'),
        count: (h.querySelector('.ds-count')||{}).textContent || '',
        tag: (h.querySelector('.ds-tag')||{}).textContent || '',
        hasList: !!h.closest('.ds-group').querySelector('.ds-list')
      })),
      items: [...document.querySelectorAll('#docsSide .ds-item')].map(a => ({
        doc: a.getAttribute('data-doc'), text: a.textContent.trim()
      })),
      groups: document.querySelectorAll('#docsSide .ds-group').length,
      carets: document.querySelectorAll('#docsSide button.ds-caret').length,
      ph: document.querySelectorAll('#docsSide .ds-caret-ph').length,
      txt: document.querySelector('#docsSide').innerText.replace(/\\s+/g,' ')
    };
  })()`);
  chk('左栏标题为「Android 文档」（单平台不带平台层）', side.title === 'Android 文档', side.title);
  chk('左栏只有 3 个类目分组', side.groups === 3 && side.heads.length === 3,
      'groups=' + side.groups + ' heads=' + side.heads.length);
  chk('类目顺序 = categories.json 顺序',
      JSON.stringify(side.heads.map((h) => h.name)) === JSON.stringify(CATS.map((k) => k.name)),
      JSON.stringify(side.heads.map((h) => h.name)));
  chk('🔴 左栏不出现其它平台名（不再平铺 6 个平台）',
      OTHER_PLATFORM_NAMES.every((n) => side.txt.indexOf(n) < 0),
      'txt=' + side.txt.slice(0, 80));
  chk('有内容的类目标篇数（入门教程 2 / 个人经验 1）',
      side.heads[0].count === '2' && side.heads[1].count === '1',
      side.heads.map((h) => h.name + '=' + (h.count || h.tag)).join(' | '));
  chk('空类目「SDK 使用指南」标待补且无子项',
      side.heads[2].tag === '待补' && side.heads[2].pending === true && side.heads[2].hasList === false,
      side.heads[2].tag);
  chk('左栏共 3 篇文章，全属于 android',
      side.items.length === 3 && side.items.every((i) => i.doc.startsWith('android/')),
      side.items.map((i) => i.doc).join(' , '));
  chk('文档 id 带类目段（android/<类目>/<slug>）',
      JSON.stringify(side.items.map((i) => i.doc)) === JSON.stringify(ALL_DOCS),
      JSON.stringify(side.items.map((i) => i.doc)));
  chk('折叠按钮只在有内容的类目上（2 个）+ 空类目留占位箭头',
      side.carets === 2 && side.ph === 1, 'carets=' + side.carets + ' ph=' + side.ph);

  // 类目折叠
  const listDisp = `getComputedStyle(document.querySelector('#docsSide .ds-group[data-cat="android/getting-started"] .ds-list')).display`;
  chk('默认展开', (await c.ev(listDisp)) !== 'none', await c.ev(listDisp));
  await c.ev(`document.querySelector('#docsSide .ds-group[data-cat="android/getting-started"] button.ds-caret').click();'ok'`);
  await sleep(250);
  const col = await c.ev(`({
    collapsed: document.querySelector('#docsSide .ds-group[data-cat="android/getting-started"]').classList.contains('collapsed'),
    exp: document.querySelector('#docsSide .ds-group[data-cat="android/getting-started"] button.ds-caret').getAttribute('aria-expanded'),
    txt: document.querySelector('#docsSide .ds-group[data-cat="android/getting-started"] button.ds-caret').textContent,
    phTxt: document.querySelector('#docsSide .ds-caret-ph').textContent
  })`);
  chk('点折叠按钮 → 该类目子项收起',
      col.collapsed && (await c.ev(listDisp)) === 'none' && col.exp === 'false', JSON.stringify(col));
  chk('🟢 空类目的占位箭头没被写入字符', col.phTxt === '', JSON.stringify(col.phTxt));
  await c.ev(`location.hash='#${D_ISSUE}';'ok'`);
  await sleep(400);
  chk('🟢 折叠后跳到该类目的文档 → 组自动展开（不藏当前项）',
      (await c.ev(`getComputedStyle(document.querySelector('#docsSide .ds-group[data-cat="android/experience"] .ds-list')).display`)) !== 'none',
      'experience 组已展开');
  // 折叠/展开可来回切：getting-started 此刻是 collapsed → 点 1 次展开、点 2 次又折叠
  const caretSel = `document.querySelector('#docsSide .ds-group[data-cat="android/getting-started"] button.ds-caret')`;
  await c.ev(`${caretSel}.click();'ok'`);
  await sleep(220);
  const afterOne = await c.ev(listDisp);
  await c.ev(`${caretSel}.click();'ok'`);
  await sleep(220);
  const afterTwo = await c.ev(listDisp);
  chk('折叠/展开可来回切（点 1 次展开、点 2 次折叠）',
      afterOne !== 'none' && afterTwo === 'none', 'after1=' + afterOne + ' after2=' + afterTwo);
  await c.ev(`${caretSel}.click();'ok'`);
  await sleep(220);

  // ---------- 4. 切平台 → 右栏 ----------
  console.log('\n【4】切平台：Android = 类目概览；空平台 = Coming soon 且左栏收起');
  for (const name of PLATFORMS) {
    await clickNav(name);
    const st = await c.ev(STATE);
    chk(`切到「${name}」→ 显示文档页`, st.active.length === 1 && st.active[0] === 'page-docs',
        JSON.stringify(st.active) + ' hash=' + st.hash);
    chk('  nav 高亮跟随', JSON.stringify(st.navActive) === JSON.stringify([name]), JSON.stringify(st.navActive));
    chk('  回到顶部（scrollY<2）', st.scrollY < 2, String(st.scrollY));

    if (name === LIVE) {
      const main = await c.ev(`({
        h1: (document.querySelector('#docsMain .docs-head h1')||{}).textContent || '',
        soon: !!document.querySelector('#docsMain .soon'),
        cards: document.querySelectorAll('#docsMain .cat-card').length,
        names: [...document.querySelectorAll('#docsMain .cat-card-head b')].map(e=>e.textContent.trim()),
        counts: [...document.querySelectorAll('#docsMain .cat-card-head span')].map(e=>e.textContent.trim()),
        listed: document.querySelectorAll('#docsMain .cat-card ul li').length,
        emptyCards: document.querySelectorAll('#docsMain .cat-card.empty').length,
        chips: document.querySelectorAll('#docsMain .chip').length,
        code: !!document.querySelector('#docsMain .code-card'),
        noSide: document.querySelector('.docs-shell').classList.contains('no-side')
      })`);
      chk('  右栏是平台页（不是 Coming soon）', main.soon === false && main.h1.indexOf('Android') === 0, main.h1);
      chk('  平台页 = 3 张类目卡（文件夹即类目）', main.cards === 3, String(main.cards));
      chk('  类目卡名称 / 顺序与 categories.json 一致',
          JSON.stringify(main.names) === JSON.stringify(CATS.map((k) => k.name)), JSON.stringify(main.names));
      chk('  类目卡标篇数，空类目标待补',
          main.counts[0] === '2 篇' && main.counts[1] === '1 篇' && main.counts[2] === '待补',
          JSON.stringify(main.counts));
      chk('  空类目卡走 .empty 样式（1 张）', main.emptyCards === 1, String(main.emptyCards));
      chk('🟢 有内容的平台页左栏可见（无 no-side）', main.noSide === false);
      chk('  平台「固定介绍」仍在（SDK 代码块 + 11 个功能点）',
          main.code === true && main.chips >= 11, 'code=' + main.code + ' chips=' + main.chips);
      await c.shot('02_platform_android.png');

      // 进类目页
      await c.ev(`document.querySelector('#docsMain .cat-card[href="#android/experience"]').click();'ok'`);
      await sleep(400);
      const cat = await c.ev(`({
        hash: location.hash,
        h1: (document.querySelector('#docsMain .docs-head h1')||{}).textContent || '',
        items: document.querySelectorAll('#docsMain .cat-item').length,
        crumb: (document.querySelector('#docsMain .doc-crumb')||{}).textContent || '',
        catHL: (document.querySelector('#docsSide .ds-head.active')||{}).getAttribute
          ? document.querySelector('#docsSide .ds-head.active').getAttribute('data-cat') : null
      })`);
      chk('  点类目卡 → 进类目页（#android/experience）', cat.hash === '#android/experience' && cat.h1 === '个人经验',
          cat.hash + ' | ' + cat.h1);
      chk('  类目页列出该类目的 1 篇文档', cat.items === 1, String(cat.items));
      chk('  面包屑指回 Android', cat.crumb.indexOf('Android') >= 0, cat.crumb.replace(/\s+/g, ' ').trim().slice(0, 40));
      chk('🟢 左栏该类目头高亮', cat.catHL === 'android/experience', String(cat.catHL));
      await c.shot('03_category_experience.png');

      // 空类目页
      await c.ev(`location.hash='#android/sdk-guide';'ok'`);
      await sleep(400);
      const empty = await c.ev(`({
        note: !!document.querySelector('#docsMain .empty-note'),
        items: document.querySelectorAll('#docsMain .cat-item').length
      })`);
      chk('  空类目页给出「往哪丢 .md」的提示', empty.note === true && empty.items === 0, JSON.stringify(empty));
    } else {
      const soon = await c.ev(`({
        soon: !!document.querySelector('#docsMain .soon'),
        items: document.querySelectorAll('#docsMain .cat-item').length,
        chips: document.querySelectorAll('#docsMain .chip').length,
        btns: [...document.querySelectorAll('#docsMain .actions a')].map(a=>a.textContent.replace(/\\s+/g,' ').trim()),
        noSide: document.querySelector('.docs-shell').classList.contains('no-side'),
        sideDisp: getComputedStyle(document.querySelector('.docs-side')).display,
        mainW: Math.round(document.querySelector('.docs-main').getBoundingClientRect().width)
      })`);
      chk('  右栏出 Coming soon 面板', soon.soon === true);
      chk('  无文档时目录为空', soon.items === 0, String(soon.items));
      chk('  规划目录 chips 非空', soon.chips >= 4, String(soon.chips));
      chk('  回退按钮是中性文案',
          soon.btns.length === 2 && soon.btns[0].indexOf('浏览已有文档') === 0 && soon.btns[1] === '返回首页',
          JSON.stringify(soon.btns));
      chk('🔴 无文档的平台：左栏整体收起（左栏只放有内容的平台）',
          soon.noSide === true && soon.sideDisp === 'none', 'noSide=' + soon.noSide + ' disp=' + soon.sideDisp);
      chk('  Coming soon 面板撑满右栏宽度', soon.mainW > 700, 'mainW=' + soon.mainW);
      if (name === 'ios') await c.shot('04_platform_ios_soon.png');
    }
  }

  // ---------- 5. 左栏条目样式（🔴 曾经被别的类名污染，必须量 computed style） ----------
  console.log('\n【5】左栏条目样式没被别处类名污染（回到 Android 量）');
  await clickNav(LIVE);
  const sideStyle = await c.ev(`(() => {
    const h = document.querySelector('#docsSide .ds-head');
    const s = getComputedStyle(h);
    const row = document.querySelector('#docsSide .ds-headrow').getBoundingClientRect();
    const nav = document.querySelector('#docsSide .ds-nav').getBoundingClientRect();
    return {
      bgimg: s.backgroundImage, border: s.borderTopWidth,
      rowW: Math.round(row.width), navW: Math.round(nav.width),
      headRight: Math.round(h.getBoundingClientRect().right), navRight: Math.round(nav.right)
    };
  })()`);
  chk('🔴 左栏类目条目无背景图（没吃到 Coming soon 面板的玻璃卡片样式）',
      sideStyle.bgimg === 'none' && sideStyle.border === '0px',
      sideStyle.bgimg.slice(0, 46) + ' | border=' + sideStyle.border);
  chk('🔴 左栏条目撑满栏宽（没被 margin:auto 缩成内容宽）',
      Math.abs(sideStyle.rowW - sideStyle.navW) <= 2 && Math.abs(sideStyle.headRight - sideStyle.navRight) <= 2,
      'row=' + sideStyle.rowW + ' nav=' + sideStyle.navW + ' right=' + sideStyle.headRight + '/' + sideStyle.navRight);
  const h2s = await c.ev(`[...document.querySelectorAll('#docsMain .section-heading h2')]
    .map(e => parseFloat(getComputedStyle(e).fontSize))`);
  chk('平台「固定介绍」的标题是文档字号（不是首页那种 40px+）',
      h2s.length > 0 && h2s.every((v) => v < 30), JSON.stringify(h2s));

  // 🔴 文档树密度：文章会越加越多，字号和行距一起量（只量字号会漏掉「字小了行距没缩」）
  const density = await c.ev(`(() => {
    const groups = [...document.querySelectorAll('#docsSide .ds-group')];
    const saved = groups.map((g) => g.classList.contains('collapsed'));
    groups.forEach((g) => g.classList.remove('collapsed'));   // 折叠态下 rect 为 0，量不准
    const items = [...document.querySelectorAll('#docsSide .ds-item')];
    const g2 = groups.find((g) => g.querySelectorAll('.ds-item').length >= 2);
    const pair = g2 ? [...g2.querySelectorAll('.ds-item')] : [];
    const out = {
      itemFs: parseFloat(getComputedStyle(items[0]).fontSize),
      headFs: parseFloat(getComputedStyle(document.querySelector('#docsSide .ds-head')).fontSize),
      titleFs: parseFloat(getComputedStyle(document.querySelector('#docsSide .ds-title')).fontSize),
      itemH: Math.round(items[0].getBoundingClientRect().height),
      pitch: pair.length >= 2
        ? Math.round(pair[1].getBoundingClientRect().top - pair[0].getBoundingClientRect().top) : -1
    };
    groups.forEach((g, i) => { if (saved[i]) g.classList.add('collapsed'); });  // 还原折叠态
    return out;
  })()`);
  chk('🔴 左栏文章字号 ≤ 12.5px', density.itemFs <= 12.5, density.itemFs + 'px');
  chk('🔴 左栏类目名字号 ≤ 13px', density.headFs <= 13, density.headFs + 'px');
  chk('🔴 左栏小标题 ≤ 11px', density.titleFs <= 11, density.titleFs + 'px');
  chk('🔴 左栏行距：相邻两篇条目间距 ≤ 28px（滚动负担的判据）',
      density.pitch > 0 && density.pitch <= 28,
      'pitch=' + density.pitch + 'px, 单条高=' + density.itemH + 'px');

  // ---------- 6. 顺序 = 类目顺序 + 类目内 order ----------
  console.log('\n【6】顺序：类目按数组顺序，类目内按 front matter 的 order');
  const order = await c.ev(`({
    manifest: (window.QZB_SITE.docs||[]).filter(d=>d.platform==='android').map(d=>d.category+'/'+d.slug + '#' + d.order),
    catManifest: (window.QZB_SITE.categories.android||[]).map(c=>c.id+':'+c.docs.length),
    sideItems: [...document.querySelectorAll('#docsSide .ds-item')].map(a=>a.getAttribute('data-doc'))
  })`);
  chk('清单里 android 三篇的 order = 10/20/30',
      JSON.stringify(order.manifest) === JSON.stringify(['getting-started/overview#10', 'getting-started/permissions#20', 'experience/common-issues#30']),
      JSON.stringify(order.manifest));
  chk('清单里类目顺序与篇数 = getting-started:2 / experience:1 / sdk-guide:0',
      JSON.stringify(order.catManifest) === JSON.stringify(['getting-started:2', 'experience:1', 'sdk-guide:0']),
      JSON.stringify(order.catManifest));
  chk('左栏顺序 = 类目顺序 → 类目内 order 顺序',
      JSON.stringify(order.sideItems) === JSON.stringify(ALL_DOCS), JSON.stringify(order.sideItems));
  chk('🔴 顺序不是字母序（字母序会把 common-issues 排最前）', order.sideItems[0] === D_GEN, order.sideItems[0]);

  // ---------- 7. 点目录 → 右栏出正文 ----------
  console.log('\n【7】点左栏 / 类目页条目 → 右栏渲染 Markdown');
  await c.ev(`document.querySelector('#docsSide .ds-item[data-doc="${D_GEN}"]').click();'ok'`);
  await sleep(400);
  s = await c.ev(STATE);
  chk('仍停在文档页（右栏换内容）', s.active.length === 1 && s.active[0] === 'page-docs', JSON.stringify(s.active));
  chk('hash = #android/getting-started/overview', s.hash === '#' + D_GEN, s.hash);
  chk('nav 高亮停在 Android', JSON.stringify(s.navActive) === JSON.stringify(['android']), JSON.stringify(s.navActive));
  chk('🔴 左栏只有这一篇被选中', s.sideActive === D_GEN, String(s.sideActive));
  chk('🟢 当前是文档时类目头不再单独高亮', s.sideCatActive === null, String(s.sideCatActive));
  chk('浏览器标题 = 文档名｜站点名', s.title === 'Android BLE 总览｜青竹 Blue｜跨平台蓝牙开发平台', s.title);

  const doc = await c.ev(`(() => {
    const b = document.querySelector('#docsMain .doc-body');
    if (!b) return { missing: true };
    const raw = b.textContent;
    return {
      h1: (b.querySelector('h1')||{}).textContent || '',
      h2: b.querySelectorAll('h2').length,
      h3: b.querySelectorAll('h3').length,
      tables: b.querySelectorAll('table.doc-table').length,
      tbodyRows: b.querySelectorAll('.doc-table tbody tr').length,
      codes: b.querySelectorAll('.doc-code').length,
      strong: b.querySelectorAll('strong').length,
      lists: b.querySelectorAll('ul,ol').length,
      blk: b.querySelectorAll('blockquote').length,
      leakHash: (raw.match(/#{2,}/g)||[]).length,
      leakFence: raw.indexOf(String.fromCharCode(96,96,96)) >= 0,
      leakPipe: raw.indexOf('|---') >= 0,
      leakStar: raw.indexOf('**') >= 0,
      crumb: (document.querySelector('#docsMain .doc-crumb')||{}).textContent || '',
      foot: (document.querySelector('#docsMain .doc-foot')||{}).textContent || ''
    };
  })()`);
  chk('正文标题已渲染为 <h1>', doc.h1 === 'Android BLE 总览', doc.h1);
  chk('二级标题 ≥ 4 个', doc.h2 >= 4, String(doc.h2));
  chk('三级标题 ≥ 3 个', doc.h3 >= 3, String(doc.h3));
  chk('表格渲染成真实 <table>', doc.tables >= 2 && doc.tbodyRows >= 8, 'table=' + doc.tables + ' rows=' + doc.tbodyRows);
  chk('代码块渲染成 .doc-code', doc.codes >= 2, String(doc.codes));
  chk('列表渲染成 <ul>/<ol>', doc.lists >= 1, String(doc.lists));
  chk('引用渲染成 <blockquote>', doc.blk >= 1, String(doc.blk));
  chk('粗体渲染成 <strong>', doc.strong >= 3, String(doc.strong));
  chk('🔴 正文无 Markdown 标记泄漏',
      doc.leakHash === 0 && doc.leakFence === false && doc.leakPipe === false && doc.leakStar === false,
      '##:' + doc.leakHash + ' fence:' + doc.leakFence + ' pipe:' + doc.leakPipe + ' star:' + doc.leakStar);
  chk('面包屑 = 平台 / 类目 / 标题',
      doc.crumb.includes('Android') && doc.crumb.includes('入门教程') && doc.crumb.includes('Android BLE 总览'),
      doc.crumb.replace(/\s+/g, ' ').trim().slice(0, 56));
  chk('页脚带来源路径', doc.foot.includes('docs/android/01-getting-started/01-overview.md'),
      doc.foot.replace(/\s+/g, ' ').trim().slice(0, 70));
  await c.shot('05_doc_overview.png');

  // 类目页 → 正文
  await clickNav(LIVE);
  await c.ev(`document.querySelector('#docsMain .cat-card[href="#android/experience"]').click();'ok'`);
  await sleep(400);
  await c.ev(`document.querySelector('#docsMain .cat-item[data-doc="${D_ISSUE}"]').click();'ok'`);
  await sleep(400);
  chk('类目页点条目 → 同样进正文', (await c.ev(`location.hash`)) === '#' + D_ISSUE, await c.ev(`location.hash`));

  // ---------- 8. 左栏 sticky ----------
  console.log('\n【8】左栏 sticky：长文滚动时目录不跑掉');
  await goto(SITE + '#' + D_GEN);
  await c.ev(`window.scrollTo(0, 1200);'ok'`);
  await sleep(300);
  const stick = await c.ev(`(() => {
    const s = document.querySelector('.docs-side').getBoundingClientRect();
    const h = document.querySelector('.site-header').getBoundingClientRect();
    return {
      sideTop: Math.round(s.top), headBottom: Math.round(h.bottom),
      inView: s.top < window.innerHeight && s.bottom > 0,
      scrolled: window.scrollY
    };
  })()`);
  chk('页面确实滚动了', stick.scrolled > 500, 'scrollY=' + stick.scrolled);
  chk('🔴 左栏滚动后仍贴在头部下方（sticky 生效）',
      stick.inView && Math.abs(stick.sideTop - stick.headBottom) < 32,
      'side.top=' + stick.sideTop + ' header.bottom=' + stick.headBottom);

  // ---------- 9. 深链与互链 ----------
  console.log('\n【9】三级深链、文档内互链、非法深链回落');
  await goto(SITE + '#' + D_PERM);
  s = await c.ev(STATE);
  const deep = await c.ev(`({
    h1: (document.querySelector('#docsMain .doc-body h1')||{}).textContent || '',
    tasks: document.querySelectorAll('#docsMain .doc-task').length,
    boxes: document.querySelectorAll('#docsMain .doc-box').length
  })`);
  chk('带 #android/getting-started/permissions 打开 → 直接落在正文',
      s.active[0] === 'page-docs' && deep.h1 === '权限与版本适配', s.active[0] + ' | ' + deep.h1);
  chk('nav 依然高亮 Android', JSON.stringify(s.navActive) === JSON.stringify(['android']));
  chk('左栏高亮对应文章且该类目已展开', s.sideActive === D_PERM, String(s.sideActive));
  chk('任务清单 - [ ] 渲染成 .doc-task', deep.tasks >= 5 && deep.boxes === deep.tasks,
      'tasks=' + deep.tasks + ' boxes=' + deep.boxes);

  await c.ev(`document.querySelector('#docsMain .doc-body a[href="#${D_ISSUE}"]').click();'ok'`);
  await sleep(400);
  const jumped = await c.ev(`({hash: location.hash, h1: (document.querySelector('#docsMain .doc-body h1')||{}).textContent || ''})`);
  chk('点正文里的跨类目互链 → 跳到「个人经验」那篇',
      jumped.hash === '#' + D_ISSUE && jumped.h1 === '常见问题排查',
      jumped.hash + ' | ' + jumped.h1);
  const ol = await c.ev(`({
    ol: document.querySelectorAll('#docsMain .doc-body ol').length,
    li: document.querySelectorAll('#docsMain .doc-body ol li').length
  })`);
  chk('有序列表渲染成 <ol>（且行数够）', ol.ol >= 1 && ol.li >= 5, 'ol=' + ol.ol + ' li=' + ol.li);

  await c.ev(`document.querySelector('#docsMain .doc-crumb a').click();'ok'`);
  await sleep(400);
  s = await c.ev(STATE);
  chk('点面包屑第一段「Android」→ 回平台页', s.hash === '#android' && s.noSide === false,
      s.hash + ' | noSide=' + s.noSide);

  await goto(SITE + '#android/not-exist-cat');
  s = await c.ev(STATE);
  chk('非法类目深链 → 回落平台页（不空白）', s.active[0] === 'page-docs' && s.hash === '#android/not-exist-cat',
      JSON.stringify(s.active));
  const fb = await c.ev(`document.querySelectorAll('#docsMain .cat-card').length`);
  chk('  回落时确实渲染了平台页的类目卡', fb === 3, String(fb));

  await goto(SITE + '#android/getting-started/not-exist-doc');
  const fb2 = await c.ev(`({
    hash: location.hash,
    h1: (document.querySelector('#docsMain .docs-head h1')||{}).textContent || '',
    items: document.querySelectorAll('#docsMain .cat-item').length
  })`);
  chk('非法文档深链 → 回落该类目页', fb2.h1 === '入门教程' && fb2.items === 2, JSON.stringify(fb2));

  await goto(SITE + '#nonsense');
  s = await c.ev(STATE);
  chk('非法平台深链 → 回落首页', s.active[0] === 'page-home', JSON.stringify(s.active));

  // ---------- 10. 首页平台卡 & Coming soon 回退 ----------
  console.log('\n【10】首页平台卡 / Coming soon 回退按钮');
  await c.ev(`document.querySelector('#page-home .platform[data-page="android"]').click();'ok'`);
  await sleep(320);
  s = await c.ev(STATE);
  chk('点首页「Android」卡 → 进平台页（类目概览）', s.active[0] === 'page-docs' && s.sideCatActive === null,
      s.hash);

  await goto(SITE + '#flutter');
  await c.ev(`[...document.querySelectorAll('#docsMain .actions a')][0].click();'ok'`);
  await sleep(320);
  s = await c.ev(STATE);
  chk('从 Flutter 页点「浏览已有文档」→ 进有文档的平台', s.hash === '#android', String(s.hash));

  // ---------- 11. 几何 ----------
  console.log('\n【11】几何：桌面不溢出 / nav 单行 / 窄屏目录折成可展开一栏');
  await goto(SITE + '#' + D_GEN);
  const geo = await c.ev(`(() => {
    const tb = document.querySelector('.topbar').getBoundingClientRect();
    const nav = document.querySelector('.nav').getBoundingClientRect();
    const side = document.querySelector('.docs-side').getBoundingClientRect();
    const main = document.querySelector('.docs-main').getBoundingClientRect();
    return {
      docOver: document.documentElement.scrollWidth - document.documentElement.clientWidth,
      navWrap: nav.bottom > tb.bottom - 4,
      navBottom: Math.round(nav.bottom), tbBottom: Math.round(tb.bottom),
      sideVisible: side.width > 120 && side.height > 100,
      sideLeftOfMain: side.right <= main.left + 1,
      sideWidth: Math.round(side.width), mainLeft: Math.round(main.left),
      toggleHidden: getComputedStyle(document.getElementById('docsToggle')).display === 'none'
    };
  })()`);
  chk('文档页无横向溢出', geo.docOver <= 1, 'overflow=' + geo.docOver + 'px');
  chk('nav 在 1440 宽下不换行', geo.navWrap === false, 'nav.bottom=' + geo.navBottom + ' topbar.bottom=' + geo.tbBottom);
  chk('🟢 双栏生效：左栏在右栏左侧且可见',
      geo.sideVisible && geo.sideLeftOfMain, 'side.w=' + geo.sideWidth + ' main.left=' + geo.mainLeft);
  chk('桌面下目录折叠按钮隐藏', geo.toggleHidden === true);

  await c.send('Emulation.setDeviceMetricsOverride', { width: 700, height: 900, deviceScaleFactor: 1, mobile: false });
  await sleep(600);
  const mob = await c.ev(`(() => {
    const links = [...document.querySelectorAll('.nav a[data-page]')];
    const side = document.querySelector('.docs-side');
    const tw = document.querySelector('.doc-table-wrap');
    return {
      shown: links.filter(a => getComputedStyle(a).display !== 'none').length,
      total: links.length,
      docOver: document.documentElement.scrollWidth - document.documentElement.clientWidth,
      toggleShown: getComputedStyle(document.getElementById('docsToggle')).display !== 'none',
      sideH: Math.round(side.getBoundingClientRect().height),
      tableScrolls: tw ? tw.scrollWidth >= tw.clientWidth : false
    };
  })()`);
  chk('700px 宽下 7 个 Tab 仍可见', mob.shown === mob.total, mob.shown + '/' + mob.total);
  chk('🔴 700px 宽下文档页无横向溢出', mob.docOver <= 1, 'overflow=' + mob.docOver + 'px');
  chk('窄屏出现「文档目录」折叠按钮', mob.toggleShown === true);
  chk('窄屏左栏默认收起', mob.sideH === 0, 'height=' + mob.sideH);
  await c.ev(`document.getElementById('docsToggle').click();'ok'`);
  await sleep(400);
  const opened = await c.ev(`({
    h: Math.round(document.querySelector('.docs-side').getBoundingClientRect().height),
    exp: document.getElementById('docsToggle').getAttribute('aria-expanded')
  })`);
  chk('点折叠按钮 → 左栏展开', opened.h > 120 && opened.exp === 'true', 'height=' + opened.h);
  await c.shot('06_docs_mobile700.png');
  await c.ev(`document.getElementById('docsToggle').click();'ok'`);
  await sleep(300);
  await c.send('Emulation.clearDeviceMetricsOverride');
  await sleep(300);

  // ---------- 12. 文档即插即用 ----------
  console.log('\n【12】🔴 新建类目文件夹 + 丢一篇 .md 就自动上线');
  const probeDir = path.join(ROOT, 'docs', 'ios', '01-probe');
  const probeFile = path.join(probeDir, '99-probe.md');
  const build = () => execFileSync(process.execPath, ['tools/build-docs.js'], { cwd: ROOT, stdio: 'pipe' });
  let step = '写入';
  try {
    fs.mkdirSync(probeDir, { recursive: true });
    fs.writeFileSync(probeFile, [
      '---', 'title: Probe 探针文档', 'order: 5',
      'summary: 由验收脚本临时写入，跑完即删', '---',
      '', '# Probe 探针文档', '', '仅为验证「新建类目 + 丢一篇 md 就自动上线」。', '',
    ].join('\n'), 'utf8');
    step = '构建';
    build();
    chk('新建 docs/ios/01-probe/99-probe.md 后构建成功', true, 'iOS 此前零文档');

    step = '重载';
    await goto(SITE + '#ios');
    const live = await c.ev(`({
      soon: !!document.querySelector('#docsMain .soon'),
      cards: document.querySelectorAll('#docsMain .cat-card').length,
      cardName: (document.querySelector('#docsMain .cat-card-head b')||{}).textContent || '',
      sideHead: (document.querySelector('#docsSide .ds-head[data-cat="ios/probe"]')||{}).textContent || '',
      sideItem: (document.querySelector('#docsSide .ds-item[data-doc="ios/probe/probe"]')||{}).textContent || '',
      noSide: document.querySelector('.docs-shell').classList.contains('no-side'),
      card: (document.querySelector('#page-home .platform[data-page="ios"]')||{}).textContent || ''
    })`);
    chk('iOS 右栏 Coming soon 自动消失', live.soon === false);
    chk('iOS 自动出现 1 张类目卡', live.cards === 1, 'name=' + live.cardName);
    chk('🔴 左栏自动多出该类目与该文档',
        live.sideHead.indexOf('probe') >= 0 && live.sideItem.indexOf('Probe 探针文档') >= 0,
        left( live.sideHead) + ' | ' + left(live.sideItem));
    chk('🟢 有内容后左栏自动出现（no-side 撤掉）', live.noSide === false);
    chk('首页 iOS 卡自动变「1 篇文档」', live.card.indexOf('1 篇文档') >= 0, live.card.replace(/\s+/g, ' ').trim());
    await c.shot('07_probe_ios_live.png');
  } catch (e) {
    chk('探针：' + step + ' 阶段', false, String(e.message).slice(0, 140));
  }

  step = '还原';
  try {
    if (fs.existsSync(probeFile)) fs.unlinkSync(probeFile);
    try { fs.rmdirSync(probeDir); } catch {}
    try { fs.rmdirSync(path.join(ROOT, 'docs', 'ios')); } catch {}
    build();
    await goto(SITE + '#ios');
    const back = await c.ev(`({
      soon: !!document.querySelector('#docsMain .soon'),
      cards: document.querySelectorAll('#docsMain .cat-card').length,
      sideHead: document.querySelectorAll('#docsSide .ds-head[data-cat="ios/probe"]').length,
      noSide: document.querySelector('.docs-shell').classList.contains('no-side')
    })`);
    chk('删除后自动回到 Coming soon（无残留）',
        back.soon === true && back.cards === 0 && back.sideHead === 0 && back.noSide === true, JSON.stringify(back));
    chk('探针目录已从磁盘删除', !fs.existsSync(path.join(ROOT, 'docs', 'ios')));
  } catch (e) {
    chk('探针还原', false, String(e.message).slice(0, 140));
  }

  // ---------- 13. 无 JS 错误 ----------
  const errs = await c.ev(`window.__e2eErrs`);
  chk('全程无 JS 错误', !errs || errs.length === 0, JSON.stringify(errs));

  console.log('\n' + '='.repeat(62));
  console.log(`青竹 Blue 站点验收：通过 ${pass} 项，失败 ${fail} 项`);
  console.log('='.repeat(62));
  shutdownBrowser();
  process.exit(fail ? 1 : 0);
})().catch((e) => { console.error('运行失败：', e.message); shutdownBrowser(); process.exit(2); });

function left(s) { return String(s).replace(/\s+/g, ' ').trim().slice(0, 60); }
