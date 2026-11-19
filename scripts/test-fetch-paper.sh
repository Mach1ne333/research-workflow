#!/bin/bash
# 离线自检：伪造下载，验证 PDF 命名、七段模板及已有文件不被覆盖。
set -euo pipefail

SKILL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP"/{bin,fixture,work}

cat > "$TMP/bin/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift ;;
    https://arxiv.org/*) url="$1" ;;
  esac
  shift
done
case "$url" in
  */pdf/*) printf '%%PDF-1.4\nmock PDF\n' > "$out" ;;
  */e-print/*)
    [ "${PDF_ONLY:-0}" = 0 ] || exit 22
    cp "$FAKE_SOURCE" "$out"
    ;;
  *) exit 1 ;;
esac
EOF
printf '#!/bin/sh\nexit 0\n' > "$TMP/bin/sleep"
chmod +x "$TMP/bin/curl" "$TMP/bin/sleep"
printf '%s\n' '\newcommand{\example}{test} % remove me' > "$TMP/fixture/main.tex"
tar -czf "$TMP/source.tar.gz" -C "$TMP/fixture" main.tex
export PATH="$TMP/bin:$PATH" FAKE_SOURCE="$TMP/source.tar.gz"
cd "$TMP/work"

TEMPLATE="$SKILL/assets/templates/research_note.md"
[ "$(grep -c '^# ' "$TEMPLATE")" -eq 1 ]
diff -u <(printf '%s\n' \
  '## 1. 要解决的问题' '## 2. 方法' '## 3. 实验' \
  '## 4. 局限' '## 5. 复现要点' '## 6. 关键引用链') \
  <(grep '^## ' "$TEMPLATE")
grep -Fq -- '- 一句话：' "$TEMPLATE"
grep -Fq '状态：待调研' "$TEMPLATE"

SLUG='方法 with spaces'
bash "$SKILL/scripts/fetch-paper.sh" 2406.09246 "$SLUG" > /dev/null
cmp "$TEMPLATE" "related_work/$SLUG/research_note.md"
[ -s "related_work/$SLUG/$SLUG.pdf" ]
[ ! -e "related_work/$SLUG/paper.pdf" ]
[ -s "related_work/$SLUG/source/main.tex" ]
[ -s "related_work/$SLUG/source/main.tex.orig" ]
printf '已有人工笔记，不能覆盖\n' > "$TMP/expected.md"
cp "$TMP/expected.md" "related_work/$SLUG/research_note.md"
bash "$SKILL/scripts/fetch-paper.sh" 2406.09246 "$SLUG" > /dev/null
cmp "$TMP/expected.md" "related_work/$SLUG/research_note.md"

PDF_ONLY=1 bash "$SKILL/scripts/fetch-paper.sh" 2410.24164 > "$TMP/pdf-only.log"
cmp "$TEMPLATE" related_work/2410.24164/research_note.md
[ -s related_work/2410.24164/2410.24164.pdf ]
[ ! -d related_work/2410.24164/source ]
grep -Fq '本次未获取到 LaTeX 源码' "$TMP/pdf-only.log"

PDF_ONLY=1 bash "$SKILL/scripts/fetch-paper.sh" 2410.24164 'descriptive directory' pi0 > "$TMP/named.log"
[ -s 'related_work/descriptive directory/pi0.pdf' ]
[ ! -e 'related_work/descriptive directory/descriptive directory.pdf' ]
grep -Fq 'related_work/descriptive directory/pi0.pdf' "$TMP/named.log"
printf '%%PDF-1.4\n已有原文，不能覆盖\n' > "$TMP/expected.pdf"
cp "$TMP/expected.pdf" 'related_work/descriptive directory/pi0.pdf'
PDF_ONLY=1 bash "$SKILL/scripts/fetch-paper.sh" 2410.24164 'descriptive directory' pi0 > /dev/null
cmp "$TMP/expected.pdf" 'related_work/descriptive directory/pi0.pdf'

for name in '../escape' 'nested/name' 'nested\name' '.' '..'; do
  if PDF_ONLY=1 bash "$SKILL/scripts/fetch-paper.sh" 2410.24164 invalid "$name" > /dev/null 2>&1; then
    echo "FAIL: 不应接受 PDF 路径 $name" >&2
    exit 1
  fi
done
[ ! -d related_work/invalid ]

mkdir -p related_work/linked
ln -s "$TMP/not-created.md" related_work/linked/research_note.md
PDF_ONLY=1 bash "$SKILL/scripts/fetch-paper.sh" 2406.09246 linked > /dev/null
[ -L related_work/linked/research_note.md ]
[ ! -e "$TMP/not-created.md" ]

bash "$SKILL/scripts/init-project.sh" "$TMP/new project" > /dev/null
cmp "$SKILL/assets/templates/AGENTS.md" "$TMP/new project/AGENTS.md"
grep -Fxq 'related_work/*/*.pdf' "$TMP/new project/.gitignore"
cp "$TMP/expected.md" "$TMP/new project/AGENTS.md"
bash "$SKILL/scripts/init-project.sh" "$TMP/new project" > /dev/null
cmp "$TMP/expected.md" "$TMP/new project/AGENTS.md"

echo 'PASS: 缩写/目录名/arXiv 回退命名、路径校验、PDF/笔记保护、七段模板、源码分支、中文空格路径、初始化幂等及 PDF 忽略规则。'
