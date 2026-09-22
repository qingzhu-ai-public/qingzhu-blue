# -*- coding: utf-8 -*-
"""把青竹 Buddy 官网的 CSS 迁移成青竹 Blue 的配色（版式/组件/间距完全不动）。

🔴 血泪教训（2026-09-22）：不要为了「好读」把 CSS 按 '}' 切行再拼回去。
   原文件里 @media 是嵌套的（max-width:900 里又套 max-width:600），
   切行会丢掉内层闭合括号 -> 后面追加的所有规则都变成「嵌在 media 查询里」，
   表现是「我的样式在 1440 宽下全不生效」。只做字符替换，不动结构。
"""
import io, os, sys

SRC_HTML = r"F:\ai_project\workbuddy-account-manager\public-site\index.html"
REF = r"F:\ai_project\qingzhu-blue\_ref"
OUT = r"F:\ai_project\qingzhu-blue\assets\styles.css"

import re
html = io.open(SRC_HTML, encoding="utf-8").read()
m = re.search(r"<style>(.*?)</style>", html, re.S)
css = m.group(1)

# 1) 变量重命名：绿色系语义名 -> 中性 accent 名（避免蓝值挂绿名）
renames = [
    ("--green-dark:#0b7a54", "--accent-dark:#1e40af"),
    ("--green:#0f9d6a", "--accent:#2563eb"),
    ("--lime:#a3e635", "--accent-2:#38bdf8"),
    ("var(--green-dark)", "var(--accent-dark)"),
    ("var(--green)", "var(--accent)"),
    ("var(--lime)", "var(--accent-2)"),
]

# 2) 色值映射：绿/黄绿/橙紫 -> 蓝/天蓝/靛（保持原有明度层级关系）
hexmap = [
    ("#0f9d6a", "#2563eb"), ("#0b7a54", "#1e40af"), ("#0d8a7a", "#3b82f6"),
    ("#0aa89a", "#0ea5e9"), ("#a3e635", "#38bdf8"), ("#84cc16", "#0ea5e9"),
    ("#0f2921", "#0b1f33"), ("#5d7a70", "#5a7191"), ("#93a8a0", "#8ea3bd"),
    ("#eef6f2", "#eef4fb"), ("#0f1d17", "#0b1f33"),
    ("#0a5f45", "#123a7a"), ("#0d4f5c", "#0c4a6e"),
    ("#d6f5e6", "#dbeafe"), ("#e7f7df", "#e0f2fe"), ("#e5f6d8", "#e0f2fe"),
    ("#c7f0da", "#bfdbfe"), ("#dff3d1", "#e0f2fe"), ("#e8f7e2", "#e0ebff"),
    ("#fde3bd", "#cfe4ff"), ("#fff2df", "#e8f2ff"),
    ("#ecd9ff", "#e0e7ff"), ("#f4e9ff", "#eef2ff"),
    ("#7c3aed", "#6366f1"), ("#d97706", "#0284c7"), ("#d68722", "#2f6fd0"),
    ("#c5e4d3", "#c3d9f2"),
    ("#fbfefc", "#fbfdff"), ("#f3f9f7", "#f4f8fe"), ("#fbfdf7", "#fbfcff"),
]

rgbamap = [
    ("rgba(15,157,106,", "rgba(37,99,235,"),
    ("rgba(52,211,153,", "rgba(59,130,246,"),
    ("rgba(163,230,53,", "rgba(56,189,248,"),
    ("rgba(15,60,45,", "rgba(11,45,95,"),
    ("rgba(10,60,45,", "rgba(11,45,110,"),
    ("rgba(16,45,36,", "rgba(16,45,90,"),
    ("rgba(15,41,33,", "rgba(11,31,51,"),
    ("rgba(238,246,242,", "rgba(238,244,251,"),
]

for a, b in renames:
    css = css.replace(a, b)
for a, b in hexmap:
    css = css.replace(a, b)
for a, b in rgbamap:
    css = css.replace(a, b)

# 3) 守卫：残留绿值 / 大括号失衡 都必须报错，不许静默通过
leftover = [t for t in ["#0f9d6a", "#0b7a54", "#d6f5e6", "#e8f7e2", "#a3e635",
                        "var(--green", "rgba(15,157,106", "#eef6f2"]
            if t in css]
if leftover:
    print("!! 残留未迁移的绿色值:", leftover)
    sys.exit(1)

extra = io.open(os.path.join(REF, "extra.css"), encoding="utf-8").read()
final = css + "\n\n" + extra
if final.count("{") != final.count("}"):
    print("!! 大括号失衡：{=%d }=%d —— 追加的规则可能被吞进 media 查询"
          % (final.count("{"), final.count("}")))
    sys.exit(2)

header = (
    "/* ==========================================================================\n"
    "   青竹 Blue —— 站点样式表 (v0.1 MVP)\n"
    "   版式 / 组件 / 圆角 / 阴影 / 间距：沿用「青竹 Buddy 官网」设计系统\n"
    "   差异：仅品牌色由绿系迁移到蓝系（--accent / --accent-dark / --accent-2）\n"
    "   生成方式：public-site/index.html 的内联 CSS 经色值替换（不改结构）\n"
    "   重新生成：python _ref/build_css.py\n"
    "   ========================================================================== */\n\n"
)
io.open(OUT, "w", encoding="utf-8").write(header + final)
print("styles.css 已生成: %d 字节 | accent 引用 %d 处 | 括号平衡 %d/%d"
      % (len(header + final), final.count("var(--accent)"),
         final.count("{"), final.count("}")))
