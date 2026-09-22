/* ==========================================================================
   青竹 Blue —— 站点控制器
   全部内容由 window.QZB（assets/docs-bundle.js，构建期生成）驱动：
     · 导航 Tab    ← platforms.json 顺序（没文档的平台进 Coming soon）
     · 首页平台卡  ← 各平台文档篇数
     · 左栏目录树  ← 只列「有文档的平台」：一级是类目、二级是文档（文件夹即类目）
     · 右栏正文    ← 平台页（类目概览）/ 类目页（文档列表）/ 文档页（Markdown）
   路由：#home / #<平台> / #<平台>/<类目> / #<平台>/<类目>/<slug>
   ========================================================================== */
(function () {
  'use strict';

  var D = window.QZB || { platforms: [], categories: {}, docs: [], src: {} };
  var md = window.QZBmd;
  var esc = md.escape;

  var REPO = 'https://github.com/qingzhu-blue';
  var REPO_URL = REPO + '/qingzhu-blue';
  var SITE_NAME = '青竹 Blue｜BLE SDK';                      // 文档页标题后缀
  var BASE_TITLE = '青竹 Blue｜BLE SDK：把蓝牙开发的复杂封在里面，开发者只写几行';   // 首页标题

  var pagesEl = document.getElementById('pages');
  var navEl = document.getElementById('nav');
  var sideEl = document.getElementById('docsSide');
  var mainEl = document.getElementById('docsMain');
  var docsPageEl = document.getElementById('page-docs');
  var toggleEl = document.getElementById('docsToggle');
  var shellEl = document.querySelector('.docs-shell');

  var platforms = D.platforms || [];
  var catsOf = D.categories || {};        // { platformId: [ {id,name,summary,docs:[id]} ] }
  var docsById = {};
  var docsOfPlat = {};                    // { platformId: [doc] }
  var docsOfCat = {};                     // { 'platformId/catId': [doc] }

  platforms.forEach(function (p) { docsOfPlat[p.id] = []; });
  (D.docs || []).forEach(function (d) {
    docsById[d.id] = d;
    (docsOfPlat[d.platform] = docsOfPlat[d.platform] || []).push(d);
    var k = d.platform + '/' + d.category;
    (docsOfCat[k] = docsOfCat[k] || []).push(d);
  });

  function platById(id) {
    for (var i = 0; i < platforms.length; i++) if (platforms[i].id === id) return platforms[i];
    return null;
  }
  function cats(pid) { return catsOf[pid] || []; }
  function catById(pid, cid) {
    var list = cats(pid);
    for (var i = 0; i < list.length; i++) if (list[i].id === cid) return list[i];
    return null;
  }
  function itemsOfCat(pid, cid) { return docsOfCat[pid + '/' + cid] || []; }
  function countOf(p) { return p ? (docsOfPlat[p.id] || []).length : 0; }
  // 左栏只列有内容的平台 —— 当前只有 Android，其余平台走 Coming soon
  function livePlatforms() { return platforms.filter(function (p) { return countOf(p) > 0; }); }
  function firstLive() {
    var live = livePlatforms();
    return live.length ? live[0].id : '';
  }
  function pad2(n) { return (n < 10 ? '0' : '') + n; }

  /* ------------------------------------------------------------ 顶部导航 */

  function buildNav() {
    var h = '<a href="#home" data-page="home">首页</a>';
    platforms.forEach(function (p) {
      h += '<a href="#' + esc(p.id) + '" data-page="' + esc(p.id) + '">' + esc(p.name) + '</a>';
    });
    h += '<a class="nav-cta" href="' + REPO + '" target="_blank" rel="noopener">GitHub</a>';
    navEl.innerHTML = h;
  }

  function highlightNav(key) {
    var links = navEl.querySelectorAll('a[data-page]');
    for (var i = 0; i < links.length; i++) {
      links[i].classList.toggle('active', links[i].getAttribute('data-page') === key);
    }
  }

  /* ---------------------------------------------------------------- 首页 */

  function buildPlatformCards() {
    var host = document.querySelector('[data-home="platforms"]');
    if (!host) return;
    host.innerHTML = platforms.map(function (p) {
      var n = countOf(p);
      var live = n > 0;
      var desc = live
        ? cats(p.id).map(function (c) { return c.name; }).slice(0, 3).join(' · ')
        : (p.plan || []).slice(0, 3).join(' · ');
      return '<a class="platform' + (live ? '' : ' soon') + '" href="#' + esc(p.id) +
        '" data-page="' + esc(p.id) + '"><b>' + esc(p.name) +
        '<small>' + (live ? n + ' 篇文档' : '整理中') + '</small></b>' +
        '<span>' + esc(desc) + '</span></a>';
    }).join('');
  }

  function wireHeroCta() {
    var cta = document.getElementById('heroCta');
    if (!cta) return;
    var live = firstLive();
    if (live) {
      cta.setAttribute('href', '#' + live);
      cta.setAttribute('data-page', live);
      cta.innerHTML = '浏览文档 <span>→</span>';
    } else {
      cta.setAttribute('href', REPO);
      cta.setAttribute('target', '_blank');
      cta.setAttribute('rel', 'noopener');
      cta.removeAttribute('data-page');
      cta.innerHTML = '前往 GitHub <span>→</span>';
    }
  }

  /* --------------------------------------------- 左栏：类目树（文件夹即类目） */

  function buildSidebar() {
    var live = livePlatforms();
    var title = live.length === 1 ? live[0].name + ' 文档' : '技术文档';
    var h = '<div class="ds-title">' + esc(title) + '</div><nav class="ds-nav">';

    live.forEach(function (p) {
      cats(p.id).forEach(function (c) {
        var items = itemsOfCat(p.id, c.id);
        var key = p.id + '/' + c.id;
        var count = items.length
          ? '<span class="ds-count">' + items.length + '</span>'
          : '<span class="ds-tag">待补</span>';
        var caret = items.length
          ? '<button class="ds-caret" type="button" aria-expanded="true" aria-label="折叠或展开 ' +
            esc(c.name) + '">▾</button>'
          : '<span class="ds-caret ds-caret-ph" aria-hidden="true"></span>';
        h += '<div class="ds-group" data-cat="' + esc(key) + '">' +
          '<div class="ds-headrow">' + caret +
          '<a class="ds-head' + (items.length ? '' : ' ds-pending') +
          '" href="#' + esc(key) + '" data-cat="' + esc(key) + '">' +
          '<span class="ds-name">' + esc(c.name) + '</span>' + count + '</a></div>' +
          (items.length
            ? '<div class="ds-list">' + items.map(function (d) {
                return '<a class="ds-item" href="#' + esc(d.id) + '" data-doc="' + esc(d.id) + '">' +
                  esc(d.title) + '</a>';
              }).join('') + '</div>'
            : '') +
          '</div>';
      });
    });
    h += '</nav>';
    sideEl.innerHTML = h;
  }

  // 🔴 只找 <button>：空类目里放的是 <span class="ds-caret">，别把 ▾ 写进占位符
  function setCollapsed(group, collapsed) {
    group.classList.toggle('collapsed', !!collapsed);
    var btn = group.querySelector('button.ds-caret');
    if (btn) {
      btn.setAttribute('aria-expanded', collapsed ? 'false' : 'true');
      btn.textContent = collapsed ? '▸' : '▾';
    }
  }

  function markSidebar(catKey, docId) {
    var groups = sideEl.querySelectorAll('.ds-group');
    for (var i = 0; i < groups.length; i++) {
      var cur = catKey && groups[i].getAttribute('data-cat') === catKey;
      groups[i].classList.toggle('current', !!cur);
      if (cur) setCollapsed(groups[i], false);   // 进到该类目就展开，别让当前项藏在折起的组里
    }
    var heads = sideEl.querySelectorAll('.ds-head');
    for (var j = 0; j < heads.length; j++) {
      var hc = catKey && heads[j].getAttribute('data-cat') === catKey;
      heads[j].classList.toggle('active', !!hc && !docId);
    }
    var items = sideEl.querySelectorAll('.ds-item');
    for (var k = 0; k < items.length; k++) {
      items[k].classList.toggle('active', items[k].getAttribute('data-doc') === docId);
    }
    var act = sideEl.querySelector('.ds-item.active') || sideEl.querySelector('.ds-head.active');
    if (act && act.scrollIntoView) act.scrollIntoView({ block: 'nearest' });
  }

  /* ------------------------------------------------------ 右栏：内容 */

  function catItem(d, idx) {
    var tags = (d.tags || []).map(function (t, i) {
      return '<span class="cat-tag' + (i === 0 ? ' done' : '') + '">' + esc(t) + '</span>';
    }).join('');
    return '<a class="cat-item" href="#' + esc(d.id) + '" data-doc="' + esc(d.id) + '">' +
      '<div class="cat-ico">' + pad2(idx + 1) + '</div>' +
      '<strong>' + esc(d.title) +
      (d.summary ? '<small>' + esc(d.summary) + '</small>' : '') + '</strong>' +
      (tags ? '<span class="cat-tags">' + tags + '</span>' : '') + '</a>';
  }

  function soonBlock(p) {
    var live = firstLive();
    var chips = (p.plan || []).map(function (t) {
      return '<span class="chip">' + esc(t) + '</span>';
    }).join('');
    return '<div class="soon">' +
      '<div class="eyebrow">' + esc(p.name) + '</div>' +
      '<h2>Coming soon</h2>' +
      '<p>' + esc(p.summary || '') + '</p>' +
      (chips ? '<div class="soon-plan">' + chips + '</div>' : '') +
      '<div class="actions">' +
      (live ? '<a class="btn btn-primary" href="#' + esc(live) + '" data-page="' + esc(live) +
        '">浏览已有文档 <span>→</span></a>' : '') +
      '<a class="btn ' + (live ? 'btn-outline' : 'btn-primary') +
      '" href="#home" data-page="home">返回首页</a>' +
      '</div></div>';
  }

  // 平台页 = 类目概览（文件夹即类目）
  function platformMain(p) {
    if (!countOf(p)) return soonBlock(p);
    var cards = cats(p.id).map(function (c) {
      var items = itemsOfCat(p.id, c.id);
      var list = items.slice(0, 4).map(function (d) {
        return '<li>' + esc(d.title) + '</li>';
      }).join('');
      return '<a class="cat-card' + (items.length ? '' : ' empty') +
        '" href="#' + esc(p.id + '/' + c.id) + '">' +
        '<div class="cat-card-head"><b>' + esc(c.name) + '</b>' +
        '<span>' + (items.length ? items.length + ' 篇' : '待补') + '</span></div>' +
        (c.summary ? '<p>' + esc(c.summary) + '</p>' : '') +
        (list ? '<ul>' + list + '</ul>' : '') +
        '</a>';
    }).join('');
    return '<div class="docs-head"><div class="eyebrow">' + esc(p.name) + '</div>' +
      '<h1>' + esc(p.title || p.name) + '</h1>' +
      '<p>' + esc(p.summary || '') + '</p></div>' +
      '<div class="cat-grid">' + cards + '</div>';
  }

  // 类目页 = 该类目下的文档列表
  function catMain(p, c) {
    var items = itemsOfCat(p.id, c.id);
    var body = items.length
      ? '<div class="catalog">' + items.map(catItem).join('') + '</div>'
      : '<div class="empty-note">这个类目还空着。往 <code>docs/' + esc(p.id) + '/</code> 下建一个 ' +
        '<code>' + esc(c.id) + '/</code> 文件夹、丢 <code>.md</code> 进去，跑一次构建就会自动上线。</div>';
    return '<div class="doc-crumb">' +
      '<a href="#' + esc(p.id) + '">← ' + esc(p.name) + '</a>' +
      '<span class="doc-crumb-sep">/</span><b>' + esc(c.name) + '</b></div>' +
      '<div class="docs-head"><h1>' + esc(c.name) + '</h1>' +
      (c.summary ? '<p>' + esc(c.summary) + '</p>' : '') + '</div>' + body;
  }

  function docMain(d) {
    var p = platById(d.platform);
    var c = catById(d.platform, d.category);
    var foot = [];
    if (d.updated) foot.push('更新于 ' + d.updated);
    foot.push(d.file);
    return '<div class="doc-crumb">' +
      '<a href="#' + esc(d.platform) + '">' + esc(p ? p.name : d.platform) + '</a>' +
      '<span class="doc-crumb-sep">/</span>' +
      '<a href="#' + esc(d.platform + '/' + d.category) + '">' + esc(c ? c.name : d.category) + '</a>' +
      '<span class="doc-crumb-sep">/</span><b>' + esc(d.title) + '</b></div>' +
      '<article class="doc-body">' + md.render(D.src[d.id] || '') + '</article>' +
      '<div class="doc-foot"><span>' + esc(foot.join(' · ')) + '</span>' +
      '<a href="' + REPO_URL + '/blob/main/' + esc(d.file) + '" target="_blank" rel="noopener">' +
      '在 GitHub 上编辑 →</a></div>';
  }

  // 平台「固定介绍」：手写在 index.html 的 <template data-platform-intro="<id>"> 里
  function appendIntro(p) {
    if (!p) return;
    var tpl = document.querySelector('template[data-platform-intro="' + p.id + '"]');
    if (tpl && tpl.content) mainEl.appendChild(tpl.content.cloneNode(true));
  }

  /* ---------------------------------------------------------------- 路由 */

  function show(el) {
    var list = pagesEl.children;
    for (var i = 0; i < list.length; i++) {
      if (list[i].classList) list[i].classList.toggle('active', list[i] === el);
    }
  }

  function closeSideMobile() {
    if (window.innerWidth <= 900) {
      sideEl.classList.remove('open');
      if (toggleEl) toggleEl.setAttribute('aria-expanded', 'false');
    }
  }

  function activate(raw) {
    var route = String(raw == null ? (location.hash || '#home') : raw).replace(/^#/, '');
    var parts = route.split('/');
    var pid = parts[0] || '';
    var cid = parts[1] || '';
    var slug = parts[2] || '';

    var plat = platById(pid);
    var cat = (plat && cid) ? catById(pid, cid) : null;
    var doc = (plat && cat && slug) ? docsById[pid + '/' + cid + '/' + slug] : null;

    // 非法平台 → 首页
    if (!plat) {
      show(document.getElementById('page-home'));
      highlightNav('home');
      document.title = BASE_TITLE;
      closeSideMobile();
      window.scrollTo(0, 0);
      return;
    }

    var live = countOf(plat) > 0;
    // 没有文档的平台只有一张 Coming soon 面板，不占左栏（左栏只放有内容的平台）
    if (shellEl) shellEl.classList.toggle('no-side', !live);

    show(docsPageEl);
    if (doc) mainEl.innerHTML = docMain(doc);
    else if (cat) mainEl.innerHTML = catMain(plat, cat);
    else mainEl.innerHTML = platformMain(plat);

    if (!doc && !cat && live) appendIntro(plat);

    var catKey = doc ? (doc.platform + '/' + doc.category)
                     : (cat ? (plat.id + '/' + cat.id) : '');
    markSidebar(catKey, doc ? doc.id : '');

    highlightNav(plat.id);
    var label = doc ? doc.title : (cat ? cat.name : (plat.title || plat.name));
    document.title = label + '｜' + SITE_NAME;
    closeSideMobile();
    window.scrollTo(0, 0);
  }

  /* ------------------------------------------------------- 交互绑定 */

  document.addEventListener('click', function (e) {
    // 分组折叠按钮（独立于链接，不会触发导航）
    var btn = e.target && e.target.closest ? e.target.closest('button.ds-caret') : null;
    if (btn) {
      e.preventDefault();
      var g = btn.closest('.ds-group');
      if (g) setCollapsed(g, !g.classList.contains('collapsed'));
      return;
    }
    var a = e.target && e.target.closest ? e.target.closest('a[href^="#"]') : null;
    if (!a) return;
    var href = a.getAttribute('href');
    if (!href || href === '#') return;
    e.preventDefault();
    if (location.hash === href) activate(href);
    else location.hash = href;            // 交给 hashchange
  });

  if (toggleEl) {
    toggleEl.addEventListener('click', function () {
      var open = sideEl.classList.toggle('open');
      toggleEl.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
  }

  /* ---------------------------------------------------------------- 启动 */

  buildNav();
  buildPlatformCards();
  wireHeroCta();
  buildSidebar();

  window.addEventListener('hashchange', function () { activate(); });
  activate();

  // 给验收脚本用的只读句柄
  window.QZB_SITE = {
    platforms: platforms,
    categories: catsOf,
    docs: D.docs || [],
    activate: activate,
    counts: (function () {
      var m = {};
      platforms.forEach(function (p) { m[p.id] = countOf(p); });
      return m;
    })(),
    catCounts: (function () {
      var m = {};
      platforms.forEach(function (p) {
        cats(p.id).forEach(function (c) { m[p.id + '/' + c.id] = itemsOfCat(p.id, c.id).length; });
      });
      return m;
    })(),
  };
})();
