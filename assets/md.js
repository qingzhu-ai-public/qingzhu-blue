/* ==========================================================================
   迷你 Markdown 渲染器（零依赖）
   只覆盖技术文档真正会用到的语法：
     标题 #~#### / 段落 / 围栏代码块 / 无序列表 / 有序列表 / 表格 /
     引用 / 分隔线 / 行内 code、**粗体**、*斜体*、[链接](url)
   不支持（有意）：HTML 直出、脚注、嵌套列表、任务列表语法糖。
   用法：window.QZBmd.render(markdownSource) -> html string
   ========================================================================== */
(function (global) {
  'use strict';

  function esc(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  // 行内标记。先摘出 code span 用占位符保护，避免 `**` 之类被误解析。
  function inline(src) {
    var codes = [];
    var s = String(src).replace(/`([^`]+)`/g, function (_, c) {
      codes.push(c);
      return '\u0000C' + (codes.length - 1) + '\u0000';
    });
    s = esc(s);
    s = s.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, function (_, text, url) {
      var ext = /^https?:/i.test(url);
      return '<a href="' + url + '"' +
        (ext ? ' target="_blank" rel="noopener"' : '') + '>' + text + '</a>';
    });
    s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    s = s.replace(/(^|[\s(（])\*([^*\n]+)\*/g, '$1<em>$2</em>');
    s = s.replace(/\u0000C(\d+)\u0000/g, function (_, i) {
      return '<code>' + esc(codes[+i]) + '</code>';
    });
    return s;
  }

  var RE_FENCE = /^\s*```+\s*([\w+#.-]*)\s*$/;
  var RE_FENCE_END = /^\s*```+\s*$/;
  var RE_HEAD = /^(#{1,4})\s+(.+?)\s*#*\s*$/;
  var RE_HR = /^\s*(-{3,}|\*{3,}|_{3,})\s*$/;
  var RE_QUOTE = /^\s*>\s?(.*)$/;
  var RE_UL = /^\s*[-*+]\s+(.+)$/;
  var RE_OL = /^\s*\d+[.)]\s+(.+)$/;
  var RE_TABLE_SEP = /^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)+\|?\s*$/;

  function cells(line) {
    return line.replace(/^\s*\|/, '').replace(/\|\s*$/, '').split('|').map(function (c) {
      return c.trim();
    });
  }

  function render(src) {
    var lines = String(src || '').replace(/\r\n?/g, '\n').split('\n');
    var out = [];
    var i = 0, n = lines.length;

    while (i < n) {
      var line = lines[i];

      // --- 围栏代码块 ---
      var fence = line.match(RE_FENCE);
      if (fence) {
        var lang = fence[1] || '';
        var buf = [];
        i++;
        while (i < n && !RE_FENCE_END.test(lines[i])) { buf.push(lines[i]); i++; }
        i++; // 吃掉收尾围栏
        out.push('<div class="doc-code">' +
          (lang ? '<span class="doc-code-lang">' + esc(lang) + '</span>' : '') +
          '<pre><code>' + esc(buf.join('\n')) + '</code></pre></div>');
        continue;
      }

      if (!line.trim()) { i++; continue; }

      // --- 分隔线 ---
      if (RE_HR.test(line)) { out.push('<hr>'); i++; continue; }

      // --- 标题 ---
      var head = line.match(RE_HEAD);
      if (head) {
        var lv = head[1].length;
        out.push('<h' + lv + '>' + inline(head[2]) + '</h' + lv + '>');
        i++;
        continue;
      }

      // --- 表格：本行含 | 且下一行是分隔行 ---
      if (line.indexOf('|') >= 0 && i + 1 < n && RE_TABLE_SEP.test(lines[i + 1])) {
        var head2 = cells(line);
        i += 2;
        var rows = [];
        while (i < n && lines[i].indexOf('|') >= 0 && lines[i].trim()) { rows.push(cells(lines[i])); i++; }
        var html = '<div class="doc-table-wrap"><table class="doc-table"><thead><tr>' +
          head2.map(function (c) { return '<th>' + inline(c) + '</th>'; }).join('') +
          '</tr></thead><tbody>' +
          rows.map(function (r) {
            return '<tr>' + head2.map(function (_, k) {
              return '<td>' + inline(r[k] == null ? '' : r[k]) + '</td>';
            }).join('') + '</tr>';
          }).join('') +
          '</tbody></table></div>';
        out.push(html);
        continue;
      }

      // --- 引用 ---
      if (RE_QUOTE.test(line)) {
        var q = [];
        while (i < n && RE_QUOTE.test(lines[i])) { q.push(lines[i].match(RE_QUOTE)[1]); i++; }
        out.push('<blockquote>' + q.map(function (t) {
          return t.trim() ? '<p>' + inline(t) + '</p>' : '';
        }).join('') + '</blockquote>');
        continue;
      }

      // --- 列表（单层；缩进超过 2 空格的行并入上一条） ---
      var ul = line.match(RE_UL), ol = line.match(RE_OL);
      if (ul || ol) {
        var ordered = !!ol && !ul;
        var lis = [];
        while (i < n) {
          var m2 = lines[i].match(RE_UL) || lines[i].match(RE_OL);
          if (!m2) {
            // 续行：缩进且非空 → 接在上一条后面
            if (lis.length && /^\s{2,}\S/.test(lines[i])) {
              lis[lis.length - 1] += ' ' + lines[i].trim();
              i++;
              continue;
            }
            break;
          }
          lis.push(m2[1]);
          i++;
        }
        out.push('<' + (ordered ? 'ol' : 'ul') + '>' +
          lis.map(function (t) {
            // 任务清单：- [ ] / - [x]
            var task = t.match(/^\[([ xX])\]\s*(.*)$/);
            if (task) {
              return '<li class="doc-task' + (task[1].toLowerCase() === 'x' ? ' done' : '') +
                     '"><i class="doc-box"></i>' + inline(task[2]) + '</li>';
            }
            return '<li>' + inline(t) + '</li>';
          }).join('') +
          '</' + (ordered ? 'ol' : 'ul') + '>');
        continue;
      }

      // --- 段落 ---
      var para = [];
      while (i < n && lines[i].trim() &&
             !RE_FENCE.test(lines[i]) && !RE_HEAD.test(lines[i]) &&
             !RE_HR.test(lines[i]) && !RE_QUOTE.test(lines[i]) &&
             !RE_UL.test(lines[i]) && !RE_OL.test(lines[i]) &&
             !(lines[i].indexOf('|') >= 0 && i + 1 < n && RE_TABLE_SEP.test(lines[i + 1]))) {
        para.push(lines[i].trim());
        i++;
      }
      if (para.length) out.push('<p>' + inline(para.join(' ')) + '</p>');
    }

    return out.join('\n');
  }

  global.QZBmd = { render: render, escape: esc };
})(window);
