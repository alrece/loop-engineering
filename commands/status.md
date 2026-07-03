---
name: "LOOP: Status"
description: "View the Loop Engineering engineering loop dashboard — current Phase, iteration round, artifact status of each stage, blockers, and next-step suggestions. Read-only, no modifications."
category: Workflow
tags: [loop, status, dashboard]
---

# /loop:status

Render the cross-tool engineering-loop dashboard. Read-only; modifies no state.

<!-- 中文译注：输出跨工具的工程闭环看板。只读，不修改任何状态。 -->

Invokes the **loop-engineering** skill in `--status` mode, reads `.loop/STATE.yaml`, then renders:

<!-- 中文译注：调用 loop-engineering skill 的 `--status` 模式，读取 `.loop/STATE.yaml` 后渲染： -->

> ⚠️ **Read AGENTS.md first**: Before performing any action, you must first read `AGENTS.md` (the MUST/MUST NOT ironclad rules + self-check checklist); it governs the entire process. The skill brings it in automatically via `@` include at load time; if that doesn't take effect, explicitly Read `~/.claude/skills/loop-engineering/AGENTS.md`.

<!-- 中文译注：⚠️ **先读行为规范**：执行任何操作前，必须先读 `AGENTS.md`（铁律 MUST/MUST NOT + 自检清单），全程受其约束。skill 加载时已通过 `@` include 自动带入，若未生效则显式 Read 该文件。 -->

```
╔══════════════════════════════════════════╗
║   Loop Engineering Dashboard (Iteration N)║
╠══════════════════════════════════════════╣
║ Current: Phase N — {phase} | step: {step} ║
║ Progress: ██████░░░░ N/7                  ║
╠══════════════════════════════════════════╣
║ Phase status:                             ║
║  1 Ideation        ✓ done                 ║
║  2 Design          ✓ done                 ║
║  3 Implementation  ▶ active  (running)     ║
║  4 QA              ○ pending              ║
║  ...                                      ║
╠══════════════════════════════════════════╣
║ ⛔ Blocker: {if any}                       ║
║ ▶ Next: `/{suggested command}`            ║
║ 📜 History: N iterations, latest retro    ║
╚══════════════════════════════════════════╝
```

<!-- 中文译注：看板原文为中文（看板/当前/进度/构想/设计/实施/历史循环），此处重绘为英文（Dashboard/Current/Progress/Ideation/Design/Implementation/History），注意英文字符宽度与中文不同已重新对齐。 -->

When no `.loop/` directory exists, prompt: `/loop:init [project name]`.

<!-- 中文译注：无 `.loop/` 目录时提示：`/loop:init [项目名]`。 -->
