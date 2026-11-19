# research-workflow

> 本仓库 fork 自 [skJack/research-workflow](https://github.com/skJack/research-workflow)（Apache-2.0）。
> 改动：`related_work/` 每篇新增七段 **research note**（`assets/templates/research_note.md`），
> 下载论文时自动建骨架，并附离线自检脚本；原「调研笔记」相关命名统一为 `research_note.md`。

> A Claude Code skill that organizes a research project into a fixed file structure,
> so both you and every fresh agent window know where to read context and where to
> write results. **中文说明在下面。**

用 Agent 协作做科研的项目工作流，做成了 Claude Code skill。

核心想法很简单：**科研项目里人和 Agent 的协作，靠一套固定的文件结构来承载**——
每个文档职责单一，每个新开的 Agent 窗口都知道先读什么、往哪写。

## 安装

```bash
git clone https://github.com/Mach1ne333/research-workflow.git ~/.claude/skills/research-workflow
```

Cursor 用户放 `~/.cursor/skills/` 或 `.agents/skills/`。

装完对 Claude 说「开个新坑做 X」，它会问你三个问题（项目名、目标、领域术语），
然后把整套结构建好。

## 文件结构

```
你的项目/
├── AGENTS.md              项目总纲：在做什么、硬规矩 —— 每个新窗口第一个读
├── handoff.md             进度交接 —— 每个窗口结束前更新，下一个窗口靠它接上
├── brainstorm.md          问题和假设的讨论记录，倒序
├── related_work/          文献，每篇 <算法缩写或目录名>.pdf + source/ + research_note.md
├── 复现/                   baseline 复现 + 复现报告
├── experiment/
│   ├── results.md         每版实验一行，不覆盖不删
│   └── evaluation.md      标准化测评，防止临时挑指标
└── DataSet/ + dataset.md  数据和处理说明
```

## 两个脚本

**建骨架**（幂等，已有文件不覆盖）：

```bash
bash ~/.claude/skills/research-workflow/scripts/init-project.sh ~/Code/my-paper
```

**抓论文**（下载 PDF、尝试获取并清洗 LaTeX 源码——隔离旧稿、剥注释；同时创建 research note 骨架，不覆盖已有笔记）：

```bash
bash ~/.claude/skills/research-workflow/scripts/fetch-paper.sh 2410.24164 pi0
# → related_work/pi0/pi0.pdf
bash ~/.claude/skills/research-workflow/scripts/fetch-paper.sh 2301.11305 detectgpt-zero-shot-curvature detectgpt
# → related_work/detectgpt-zero-shot-curvature/detectgpt.pdf
```

用法：`fetch-paper.sh <arxiv-id> [目录名] [算法缩写]`。
先从论文确认作者的算法 / 模型缩写或名称；没有明确命名时采用工作目录名。
脚本不猜名称，第三参数传已确认的缩写（不带 `.pdf` 或路径），省略则采用目录名。
旧 PDF 本地重命名时同步笔记、索引与 manifest，不重新下载或覆盖不同文献。

## 每篇论文的 research note

每个方法目录必须有独立的 `research_note.md`，`README.md` 仅作导航或简短导读。
模板见 [assets/templates/research_note.md](assets/templates/research_note.md)，固定七段：

- 开头：论文标题、来源/阅读说明、版本与机构、代码/权重/数据开放情况及链接、整理状态和一句话总结。
- `1. 要解决的问题`
- `2. 方法`
- `3. 实验`
- `4. 局限`
- `5. 复现要点`
- `6. 关键引用链`

关键数字和结论要有原文位置；图表估读明确标注，且必须实际看过图。
区分作者陈述与笔记者分析、论文结果与本地实测，未知写“待核实”，未运行不写成已复现。
脚本仅生成待填写模板；读完原文再完善，不能以下载或模板占位符冒充完成调研。
详细规则见 [SKILL.md](SKILL.md)。

离线检查脚本与模板（不访问 arXiv）：

```bash
bash scripts/test-fetch-paper.sh
```

## 工作节奏

```
抓文献并写 research note → 复现关键 baseline → 提假设 → 跑实验 → （循环）
```

复现放在提假设之前：论文只报平均值和成功配置，
真正的问题往往在自己跑一遍才看得见的地方。

## 内置的几条警示

- 效果突然变好，先查数据泄漏（split 是不是按样本分了）
- verify 中间过程，不只是看代码——小问题都藏在输入输出的处理里
- 每一版实验都命名、都留着，失败的也留
- 测评照 `evaluation.md` 走，不临时挑指标
- 上下文快满就更新 `handoff.md`，别硬撑到被截断

## License

Apache License 2.0
