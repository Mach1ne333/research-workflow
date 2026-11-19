#!/bin/bash
# 抓一篇 arXiv 论文到 related_work/，清洗源码，并创建 research note 骨架（已有笔记不覆盖）。
#
#   ./fetch-paper.sh 2301.11305 detectgpt-zero-shot-curvature detectgpt
#   ./fetch-paper.sh 2410.24164 pi0               # 缩写与目录名相同时可省略第三参数
#   ./fetch-paper.sh 2301.11305                    # 不给 slug 就用 arXiv ID 当目录名
#
# 两个都下：泛读读 PDF，查表格/公式读 LaTeX。
# 源码里常混着作者的旧稿和注释掉的正文，不清掉会引用到过期数字。

set -euo pipefail

ID="${1:?用法: fetch-paper.sh <arxiv-id> [slug] [算法缩写]}"
SLUG="${2:-$ID}"
DEST="related_work/$SLUG"
NAME="${3:-$(basename -- "$DEST")}"
case "$NAME" in
  .|..|*/*|*\\*) echo "算法缩写必须是文件名，不能包含路径：$NAME" >&2; exit 1 ;;
esac
PDF="$DEST/$NAME.pdf"
TPL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../assets/templates" && pwd)"
UA="research-workflow/1.0 (academic use)"

mkdir -p "$DEST/source"

echo "▸ $ID → $DEST"
if [ ! -e "$DEST/research_note.md" ] && [ ! -L "$DEST/research_note.md" ]; then
  cp "$TPL/research_note.md" "$DEST/research_note.md"
  echo "  + research_note.md（待调研；读完论文后填写七段，下载不代表调研完成）"
fi

# --- PDF ---
if [ ! -s "$PDF" ]; then
  curl -sL -A "$UA" --max-time 180 "https://arxiv.org/pdf/$ID" -o "$PDF"
  sleep 3   # arXiv 要求礼貌抓取，别去掉
fi
[ -s "$PDF" ] || { echo "  ✗ PDF 下载失败"; exit 1; }

# --- LaTeX 源码 ---
BLOB=$(mktemp)
curl -sL -A "$UA" --max-time 180 "https://arxiv.org/e-print/$ID" -o "$BLOB" || true
sleep 3

HAS_TEX=false
if [ -s "$BLOB" ]; then
  if tar -xzf "$BLOB" -C "$DEST/source" 2>/dev/null; then
    HAS_TEX=true
  elif gunzip -c "$BLOB" > "$DEST/source/main.tex" 2>/dev/null; then
    HAS_TEX=true   # 单文件投稿，gzip 的裸 .tex
  fi
fi
rm -f "$BLOB"

if [ "$HAS_TEX" = false ] || [ -z "$(find "$DEST/source" -name '*.tex' -print -quit)" ]; then
  rmdir "$DEST/source" 2>/dev/null || true
  echo "  ⚠ 本次未获取到 LaTeX 源码，不能据此断定作者没有公开源码；请在 research note 中说明。"
  echo "    细查表格公式时读 PDF，注意行列可能错位，用 pdftotext -layout 而不是默认参数。"
  echo "  ✓ $PDF"
  exit 0
fi

# --- 清洗 ---
# 1) 旧稿目录：有些作者把 v1/v2/v3 一起打包上传（DetectGPT 就是），
#    agent 无差别读 *.tex 会同时读进好几个版本的论文，引到已经被推翻的数字。
STALE=$(find "$DEST/source" -type d \
        \( -iname history -o -iname old -o -iname backup -o -iname draft \
           -o -iname previous -o -iname archive -o -iname submitted \) 2>/dev/null || true)
if [ -n "$STALE" ]; then
  echo "  ⚠ 发现旧稿目录，已移到 source/.stale/（没删，想看还在）:"
  mkdir -p "$DEST/source/.stale"
  while IFS= read -r d; do
    echo "      ${d#$DEST/source/}"
    mv "$d" "$DEST/source/.stale/" 2>/dev/null || true
  done <<< "$STALE"
fi

# 2) 注释掉的正文：作者删了但没删干净的段落，读进去会当成论文观点。
#    只剥行内和整行的 % 注释，保留 \% 转义。原文件留一份 .orig。
CLEANED=0
while IFS= read -r f; do
  [ -f "$f.orig" ] || cp "$f" "$f.orig"
  perl -pe 's/(?<!\\)%.*$//' "$f.orig" > "$f"
  CLEANED=$((CLEANED+1))
done < <(find "$DEST/source" -name '*.tex' -not -path '*/.stale/*')

# 3) 宏定义文件要一起读，不然满篇自定义命令看不懂
MACROS=$(find "$DEST/source" -name '*.tex' -not -path '*/.stale/*' \
         -exec grep -l '\\newcommand\|\\def\\' {} \; 2>/dev/null | head -5 || true)
# 用 find -exec 逐文件计数再求和，别用 glob —— pipefail 下坏 glob 会让 cat 失败，
# 触发 || 分支把 "0" 拼到真实计数后面，得到 "11\n0" 这种非法整数
NMACRO=$(find "$DEST/source" -name '*.tex' -not -path '*/.stale/*' \
         -exec grep -ch '\\newcommand\|\\def\\' {} + 2>/dev/null \
         | awk '{s+=$1} END{print s+0}')

echo "  ✓ $NAME.pdf + source/（$CLEANED 个 .tex 已剥注释，原文件存为 .orig）"
[ "$NMACRO" -gt 80 ] && echo "  ⚠ 自定义宏 $NMACRO 个，读正文前先读这些文件：" && echo "$MACROS" | sed 's|^|      |'
echo "  提示：泛读读 $NAME.pdf；查表格/公式/引用读 source/*.tex"
