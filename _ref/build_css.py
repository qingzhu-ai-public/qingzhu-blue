# -*- coding: utf-8 -*-
"""把青竹 Buddy 官网的 CSS 迁移成青竹 BLE 文档站的绿色配色。

版式/组件/间距完全不动，只做字符替换：
1) 绿色语义变量改名为中性的 --accent 系列；
2) 原设计里用于点缀的蓝/紫/橙统一收敛为青竹绿、竹叶绿、薄荷绿；
3) 追加 _ref/extra.css，生成 assets/styles.css。

🔴 不要为了「好读」按 '}' 切行再拼回去：原 CSS 的 @media 有嵌套，
切行会丢掉内层闭合括号，导致后续规则被错误吞进 media 查询。
"""
import io, os, sys

SRC_HTML = r"F:\ai_project\workbuddy-account-manager\public-site\index.html"
REF = r"F:\ai_project\qingzhu-blue\_ref"
OUT = r"F:\ai_project\qingzhu-blue\assets\styles.css"

import re
html = io.open(SRC_HTML, encoding="utf-8").read()
m = re.search(r"<style>(.*?)</style>", html, re.S)
css = m.group(1)

# 1) 变量重命名：保留青竹绿的值，变量名统一成 --accent 系列
renames = [
    ("--green-dark:#0b7a54", "--accent-dark:#0b7a54"),
    ("--green:#0f9d6a", "--accent:#0f9d6a"),
    ("--lime:#a3e635", "--accent-2:#a3e635"),
    ("var(--green-dark)", "var(--accent-dark)"),
    ("var(--green)", "var(--accent)"),
    ("var(--lime)", "var(--accent-2)"),
]

# 2) 把原设计里非绿色的点缀色收敛到青竹绿系，避免蓝色残留
hexmap = [
    ("#22d3ee", "#0aa89a"),   # cyan  → 薄荷绿
    ("#4d83de", "#0d8a7a"),   # blue  → 深青竹绿
    ("#7c3aed", "#0d8a7a"),   # purple→ 深青竹绿
    ("#d97706", "#84cc16"),   # orange→ 竹叶绿
    ("#dbe9ff", "#d6f5e6"),
    ("#e8f1ff", "#e8f7e2"),
    ("#ecd9ff", "#e5f6d8"),
    ("#f4e9ff", "#e8f7e2"),
    ("#0284c7", "#0d8a7a"),
    ("#2f6fd0", "#0d8a7a"),
    ("#123a7a", "#0a5f45"),
    ("#0c4a6e", "#0d4f5c"),
]

rgbamap = [
    ("rgba(34,211,238,", "rgba(10,168,154,"),
    ("rgba(34, 211, 238,", "rgba(10, 168, 154,"),
]

for a, b in renames:
    css = css.replace(a, b)
for a, b in hexmap:
    css = css.replace(a, b)
for a, b in rgbamap:
    css = css.replace(a, b)

extra = io.open(os.path.join(REF, "extra.css"), encoding="utf-8").read()
final = css + "\n\n" + extra

# 3) 守卫：蓝色残留 / 大括号失衡 都必须报错，不许静默通过
blue_leftover = [t for t in [
    "#2563eb", "#1e40af", "#3b82f6", "#38bdf8", "#0ea5e9",
    "#22d3ee", "#4d83de", "#0284c7", "#123a7a", "#0b1f33",
    "#eef4fb", "#e6efff", "#dbeafe", "#e0f2fe",
    "rgba(37,99,235", "rgba(37, 99, 235",
    "rgba(59,130,246", "rgba(59, 130, 246",
    "rgba(56,189,248", "rgba(56, 189, 248",
] if t in final]
if blue_leftover:
    print("!! 残留未迁移的蓝色值:", blue_leftover)
    sys.exit(1)

if final.count("{") != final.count("}"):
    print("!! 大括号失衡：{=%d }=%d —— 追加的规则可能被吞进 media 查询"
          % (final.count("{"), final.count("}")))
    sys.exit(2)

header = (
    "/* ==========================================================================\n"
    "   青竹 Blue —— 站点样式表\n"
    "   版式 / 组件 / 圆角 / 阴影 / 间距：沿用「青竹 Buddy 官网」设计系统\n"
    "   差异：品牌色统一为青竹绿系（--accent / --accent-dark / --accent-2）\n"
    "   生成方式：public-site/index.html 的内联 CSS 经色值替换（不改结构）\n"
    "   重新生成：python _ref/build_css.py\n"
    "   ========================================================================== */\n\n"
)
io.open(OUT, "w", encoding="utf-8", newline="\n").write(header + final)
print("styles.css 已生成: %d 字节 | accent 引用 %d 处 | 括号平衡 %d/%d"
      % (len(header + final), final.count("var(--accent)"),
         final.count("{"), final.count("}")))
