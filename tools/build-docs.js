#!/usr/bin/env node
/**
 * 青竹 Blue —— 文档构建脚本
 *
 * 扫描 docs/<平台>/<类目>/*.md，解析 front matter，生成 assets/docs-bundle.js。
 * 站点不联网、不做运行时目录请求：加文档 = 加一个 .md + 跑一次本脚本。
 *
 * 目录约定（**文件夹 = 类目**）：
 *
 *   docs/
 *   ├── platforms.json              平台表（Tab 顺序 / 名称 / 未上线时的规划目录）
 *   └── android/
 *       ├── categories.json         类目表（文件夹 id → 显示名 + 顺序 + 摘要）
 *       ├── 01-getting-started/     ← 目录名去掉 NN- 前缀 = 类目 id
 *       │   ├── 01-overview.md
 *       │   └── 02-permissions.md
 *       └── 02-experience/
 *           └── 01-common-issues.md
 *
 * 加一篇文档 = 把 .md 丢进某个类目文件夹 + 跑一次本脚本。
 * 加一个类目 = 建一个类目文件夹（顺手在 categories.json 里登记显示名，不登记就用文件夹名）。
 *
 * 路由：#<平台> / #<平台>/<类目> / #<平台>/<类目>/<slug>
 *
 * 用法：
 *   node tools/build-docs.js            # 生成 assets/docs-bundle.js
 *   node tools/build-docs.js --check    # 只校验不写盘（CI 可用）
 *
 * 排序：类目按 categories.json 的数组顺序（未登记的排在最后，按文件夹名）；
 *       类目内文档按 front matter 的 order 升序（缺省 1000），同 order 按文件名自然序。
 *
 * 🔴 输出必须**确定性**（不含时间戳），否则 GitHub Actions 每次都会产生无意义提交。
 */
'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const DOCS_DIR = path.join(ROOT, 'docs');
const OUT_FILE = path.join(ROOT, 'assets', 'docs-bundle.js');
const CHECK_ONLY = process.argv.includes('--check');

const DEFAULT_ORDER = 1000;
const UNLISTED_CAT_ORDER = 9000;   // 未在 categories.json 登记的类目排最后
const warn = [];
const fail = [];

function rel(p) { return path.relative(ROOT, p).replace(/\\/g, '/'); }

/* ---------------------------------------------------------------- 读取平台表 */

function readPlatforms() {
  const f = path.join(DOCS_DIR, 'platforms.json');
  if (!fs.existsSync(f)) { fail.push('缺少 docs/platforms.json'); return []; }
  let json;
  try { json = JSON.parse(fs.readFileSync(f, 'utf8')); }
  catch (e) { fail.push('docs/platforms.json 解析失败：' + e.message); return []; }
  const list = Array.isArray(json.platforms) ? json.platforms : [];
  list.forEach((p, i) => {
    if (!p || !p.id) fail.push('platforms.json 第 ' + (i + 1) + ' 项缺少 id');
    if (p && p.id && !/^[a-z0-9-]+$/.test(p.id)) {
      warn.push('平台 id「' + p.id + '」建议只用小写字母 / 数字 / 连字符（它会进 #hash 路由）');
    }
  });
  return list.filter((p) => p && p.id);
}

/* ---------------------------------------------------------------- 读取类目表 */

// 返回 null = 该平台没有 categories.json（类目全按文件夹名推导）
function readCategories(platformId) {
  const f = path.join(DOCS_DIR, platformId, 'categories.json');
  if (!fs.existsSync(f)) return null;
  let json;
  try { json = JSON.parse(fs.readFileSync(f, 'utf8')); }
  catch (e) { fail.push('docs/' + platformId + '/categories.json 解析失败：' + e.message); return []; }
  const list = Array.isArray(json.categories) ? json.categories : [];
  list.forEach((c, i) => {
    if (!c || !c.id) { fail.push('docs/' + platformId + '/categories.json 第 ' + (i + 1) + ' 项缺少 id'); return; }
    if (!/^[a-z0-9-]+$/.test(c.id)) {
      warn.push('类目 id「' + c.id + '」建议只用小写字母 / 数字 / 连字符（它会进 #hash 路由）');
    }
  });
  return list.filter((c) => c && c.id);
}

/* ------------------------------------------------------------- front matter */

function parseFrontMatter(raw) {
  const meta = {};
  const m = raw.match(/^\uFEFF?---[ \t]*\r?\n([\s\S]*?)\r?\n---[ \t]*(?:\r?\n|$)/);
  if (!m) return { meta, body: raw, hasFm: false };
  m[1].split(/\r?\n/).forEach((line) => {
    if (!line.trim() || /^\s*#/.test(line)) return;
    const kv = line.match(/^([A-Za-z_][\w-]*)\s*[:：]\s*(.*)$/);
    if (!kv) return;
    const v = kv[2].trim().replace(/^["']|["']$/g, '');
    meta[kv[1].toLowerCase()] = v;
  });
  return { meta, body: raw.slice(m[0].length), hasFm: true };
}

function firstHeading(body) {
  const m = body.match(/^\s*#\s+(.+?)\s*$/m);
  return m ? m[1].trim() : '';
}

function slugOf(filename) {
  return filename
    .replace(/\.md$/i, '')
    .replace(/^\d+[-_.\s]+/, '')   // 去数字前缀：01-overview -> overview
    .replace(/[^\w\u4e00-\u9fa5-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .toLowerCase() || 'doc';
}

// 目录名 -> 类目 id（去掉排序用的数字前缀）
function catIdOf(dirName) {
  return dirName.replace(/^\d+[-_.\s]+/, '').trim();
}

function listMd(dir) {
  if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) return [];
  return fs.readdirSync(dir)
    .filter((f) => /\.md$/i.test(f) && !/^_/.test(f) && f.toLowerCase() !== 'readme.md')
    .sort((a, b) => a.localeCompare(b, 'zh', { numeric: true }));
}

/* ------------------------------------------------------------------ 扫描 */

function scan() {
  const platforms = readPlatforms();
  const ids = platforms.map((p) => p.id);
  const docs = [];
  const src = {};
  const categories = {};       // { platformId: [ {id,name,summary,docs:[docId]} ] }
  let scanned = 0;

  // docs/ 根目录下直接放 .md：不会进站
  fs.readdirSync(DOCS_DIR, { withFileTypes: true })
    .filter((d) => d.isFile() && /\.md$/i.test(d.name))
    .forEach((d) => warn.push(
      'docs/' + d.name + ' 在 docs/ 根目录下，不会被收录 —— 请移到 docs/<平台>/<类目>/ 里'));

  for (const p of platforms) {
    const pdir = path.join(DOCS_DIR, p.id);
    const declared = readCategories(p.id);

    // 类目容器：先按 categories.json 铺好（顺序 = 数组顺序），再让实际文件夹往里填
    const catMap = {};
    (declared || []).forEach((c, i) => {
      catMap[c.id] = {
        id: c.id, name: c.name || c.id, summary: c.summary || '',
        seq: i, listed: true, items: [],
      };
    });
    if (fs.existsSync(pdir) && fs.statSync(pdir).isDirectory()) {
      // 平台根下直接放的 .md：不会被收录（必须进类目文件夹）
      fs.readdirSync(pdir, { withFileTypes: true })
        .filter((d) => d.isFile() && /\.md$/i.test(d.name) && d.name.toLowerCase() !== 'readme.md')
        .forEach((d) => warn.push(
          'docs/' + p.id + '/' + d.name + ' 直接躺在平台目录下，不会被收录 —— ' +
          '请放进类目文件夹，例如 docs/' + p.id + '/01-' + (catMap[Object.keys(catMap)[0]] || { id: 'getting-started' }).id + '/'));

      const dirs = fs.readdirSync(pdir, { withFileTypes: true })
        .filter((d) => d.isDirectory() && !/^[_.]/.test(d.name))
        .sort((a, b) => a.name.localeCompare(b.name, 'zh', { numeric: true }));

      for (const d of dirs) {
        const cid = catIdOf(d.name);
        if (!cid) {
          warn.push('docs/' + p.id + '/' + d.name + '/ 目录名去掉数字前缀后为空，整个目录被忽略');
          continue;
        }
        let cat = catMap[cid];
        if (!cat) {
          cat = catMap[cid] = {
            id: cid, name: cid, summary: '', seq: UNLISTED_CAT_ORDER, listed: false, items: [],
          };
          warn.push('类目文件夹 docs/' + p.id + '/' + d.name + '/ 未登记在 categories.json 里，' +
                    '显示名暂用「' + cid + '」（建议补上中文名）');
        }

        for (const f of listMd(path.join(pdir, d.name))) {
          scanned++;
          const full = path.join(pdir, d.name, f);
          const raw = fs.readFileSync(full, 'utf8');
          const { meta, body, hasFm } = parseFrontMatter(raw);
          if (!hasFm) warn.push(rel(full) + ' 没有 front matter（--- 头部），将按一级标题 / 文件名生成标题');

          const order = /^\d+$/.test(meta.order || '') ? parseInt(meta.order, 10) : DEFAULT_ORDER;
          if (meta.order && !/^\d+$/.test(meta.order)) {
            warn.push(rel(full) + ' 的 order「' + meta.order + '」不是整数，已按 ' + DEFAULT_ORDER + ' 处理');
          }
          const slug = meta.slug || slugOf(f);
          const id = [p.id, cid, slug].join('/');

          cat.items.push({
            id,
            platform: p.id,
            category: cid,
            slug,
            title: meta.title || firstHeading(body) || f.replace(/\.md$/i, ''),
            summary: meta.summary || '',
            tags: (meta.tags || '').split(/[,，、]/).map((s) => s.trim()).filter(Boolean),
            updated: meta.updated || '',
            file: rel(full),
            order,
            orderFrom: meta.order ? 'order' : 'default',
          });
          src[id] = body.replace(/^\s*\n/, '');
        }
      }
    }

    // 组装该类目的文档顺序
    const cats = Object.keys(catMap).map((k) => catMap[k])
      .sort((a, b) => (a.seq - b.seq) || a.id.localeCompare(b.id));

    cats.forEach((c) => {
      c.items.sort((a, b) =>
        (a.order - b.order) || a.file.localeCompare(b.file, 'zh', { numeric: true }));

      // 类目内 order 撞车 → 提示
      const seen = {};
      c.items.forEach((d) => {
        if (d.order === DEFAULT_ORDER) return;
        if (seen[d.order]) warn.push(
          'docs/' + p.id + '/' + c.id + ' 下 order=' + d.order + ' 重复：' +
          seen[d.order] + ' 与 ' + d.slug + '（按文件名排序）');
        seen[d.order] = d.slug;
      });
      // 类目内 slug 撞车 → 致命（会撞 #hash 路由）
      const slugs = {};
      c.items.forEach((d) => {
        if (slugs[d.slug]) fail.push(
          'docs/' + p.id + '/' + c.id + ' 下 slug 冲突：「' + d.slug + '」出现两次');
        slugs[d.slug] = 1;
      });
      docs.push(...c.items);
    });

    categories[p.id] = cats.map((c) => ({
      id: c.id, name: c.name, summary: c.summary,
      listed: c.listed, docs: c.items.map((d) => d.id),
    }));
    p.docs = docs.filter((d) => d.platform === p.id).map((d) => d.id);
    p.categories = categories[p.id].map((c) => c.id);
  }

  // 未登记的平台目录
  fs.readdirSync(DOCS_DIR, { withFileTypes: true })
    .filter((d) => d.isDirectory() && !ids.includes(d.name))
    .forEach((d) => warn.push(
      'docs/' + d.name + '/ 不是 docs/platforms.json 里的平台 id，整目录被忽略'));

  // 站内链接校验：正文里写的 (#<路由>) 必须指向存在的平台 / 类目 / 文档
  // （文档换类目文件夹时最容易漏改，这类死链在页面上是静默失效的）
  const known = {};
  platforms.forEach((p) => {
    known[p.id] = 1;
    (categories[p.id] || []).forEach((c) => { known[p.id + '/' + c.id] = 1; });
  });
  docs.forEach((d) => { known[d.id] = 1; });

  for (const id of Object.keys(src)) {
    const re = /\]\(#([^)\s]+)\)/g;
    let m;
    while ((m = re.exec(src[id]))) {
      const route = m[1];
      if (!platforms.some((p) => p.id === route.split('/')[0])) continue;  // #home 之类不管
      if (!known[route]) {
        const d = docs.find((x) => x.id === id);
        warn.push((d ? d.file : id) + ' 里的站内链接 #' + route +
                  ' 找不到对应页面（平台 / 类目 / 文档都不存在）');
      }
    }
  }

  return { platforms, categories, docs, src, scanned };
}

/* ------------------------------------------------------------------ 输出 */

function main() {
  if (!fs.existsSync(DOCS_DIR)) { console.error('找不到 docs/ 目录'); process.exit(2); }

  const { platforms, categories, docs, src, scanned } = scan();

  console.log('青竹 Blue 文档构建');
  console.log('─'.repeat(66));
  let liveCat = 0;
  for (const p of platforms) {
    const cats = categories[p.id] || [];
    const n = (p.docs || []).length;
    if (n) liveCat++;
    console.log('  ' + (n ? String(n).padStart(2) + ' 篇' : '  — ') + '  ' +
                p.id.padEnd(13) + (n ? cats.length + ' 个类目' : 'Coming soon'));
    for (const c of cats) {
      const cnt = c.docs.length;
      console.log('        ' + (cnt ? String(cnt).padStart(2) + ' 篇' : '  — ') + '  ' +
                  c.name + (c.listed ? '' : '  (未登记)') + '   #' + p.id + '/' + c.id);
      for (const id of c.docs) {
        const d = docs.find((x) => x.id === id);
        console.log('              ' + String(d.order).padStart(4) + '  ' +
                    (d.orderFrom === 'order' ? 'order ' : '默认  ') +
                    d.title.padEnd(18) + ' ← ' + d.file);
      }
    }
  }
  console.log('─'.repeat(66));
  console.log('  计 ' + scanned + ' 篇文档，' + liveCat + '/' + platforms.length + ' 个平台有内容');

  if (warn.length) {
    console.log('\n提示（' + warn.length + '）：');
    warn.forEach((w) => console.log('  ! ' + w));
  }
  if (fail.length) {
    console.log('\n错误（' + fail.length + '）：');
    fail.forEach((w) => console.log('  x ' + w));
    console.log('\n构建失败，未写盘。');
    process.exit(1);
  }

  const bundle = { v: 2, platforms, categories, docs, src };
  const out = '/* 由 tools/build-docs.js 自动生成，请勿手改。\n' +
              '   重新生成：node tools/build-docs.js （或 push docs/ 后由 GitHub Actions 自动跑）\n' +
              '   收录 ' + docs.length + ' 篇文档 / ' + platforms.length + ' 个平台。 */\n' +
              'window.QZB = ' + JSON.stringify(bundle) + ';\n';

  if (CHECK_ONLY) { console.log('\n--check：校验通过，未写盘。'); return; }

  fs.mkdirSync(path.dirname(OUT_FILE), { recursive: true });
  fs.writeFileSync(OUT_FILE, out, 'utf8');
  const kb = (Buffer.byteLength(out, 'utf8') / 1024).toFixed(1);
  console.log('\n已写出  assets/docs-bundle.js  (' + kb + ' KB)');
}

main();
