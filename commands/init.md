---
name: "LOOP: Init"
description: "Initialize the Loop Engineering engineering loop — creates the .loop/ state directory, STATE.yaml (7-Phase template), an artifact tracking table, and optionally enters the ideation phase immediately."
category: Workflow
tags: [loop, init, setup]
---

# /loop:init

Initialize the engineering loop. Project name: `$ARGUMENTS`

<!-- 中文译注：初始化工程闭环。项目名：`$ARGUMENTS`。 -->

Invokes the **loop-engineering** skill in `--init` mode:

<!-- 中文译注：调用 loop-engineering skill 的 `--init` 模式： -->

> ⚠️ **Read AGENTS.md first**: Before performing any action, you must first read `AGENTS.md` (the MUST/MUST NOT ironclad rules + self-check checklist); it governs the entire process. The skill brings it in automatically via `@` include at load time; if that doesn't take effect, explicitly Read `~/.claude/skills/loop-engineering/AGENTS.md`.

<!-- 中文译注：⚠️ **先读行为规范**：执行任何操作前，必须先读 `AGENTS.md`（铁律 MUST/MUST NOT + 自检清单），全程受其约束。skill 加载时已通过 `@` include 自动带入，若未生效则显式 Read 该文件。 -->

1. Create a `.loop/` directory at the project root
   <!-- 中文译注：在项目根创建 `.loop/` 目录。 -->
2. Write `.loop/STATE.yaml` (7-Phase template: current_phase=1, current_step=ideate, iteration=1)
   <!-- 中文译注：写 `.loop/STATE.yaml`（7-Phase 模板：current_phase=1, current_step=ideate, iteration=1）。 -->
3. Create empty asset files: `learnings.yaml`, `gaps.yaml`, `timeline.jsonl`
   <!-- 中文译注：创建空资产文件：`learnings.yaml`、`gaps.yaml`、`timeline.jsonl`。 -->
4. Initialize the artifact tracking table per the state_schema in loop-state.md (one path each for ideate/spec/design/planning/execute/review/qa/ship/retro)
   <!-- 中文译注：产物追踪表按 loop-state.md 的 state_schema 初始化（ideate/spec/design/planning/execute/review/qa/ship/retro 各路径）。 -->

On completion, ask:
<!-- 中文译注：完成后询问： -->
```
Loop Engineering initialized.
Start the ideation phase now?
  → /office-hours (gstack 6 questions to dig into the product vision, CEO perspective)
  → or /loop:run --next --auto (auto-run starting from ideation)
```

<!-- 中文译注：原提示「Loop Engineering 已初始化。是否立即开始构想阶段？」以及两个建议命令。 -->

If `.loop/STATE.yaml` already exists, prompt whether to overwrite it (default: do not overwrite, to avoid losing historical loop records).

<!-- 中文译注：如果 `.loop/STATE.yaml` 已存在，提示是否覆盖（默认不覆盖，避免丢历史循环记录）。 -->
