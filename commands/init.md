---
name: "LOOP: Init"
description: "初始化 Loop Engineering 工程闭环——创建 .loop/ 状态目录、STATE.yaml（7-Phase 模板）、产物追踪表，可选立即进入构想阶段。"
category: Workflow
tags: [loop, init, setup]
---

# /loop:init

初始化工程闭环。项目名：`$ARGUMENTS`

调用 **loop-engineering** skill 的 `--init` 模式：

> ⚠️ **先读行为规范**：执行任何操作前，必须先读 `AGENTS.md`（铁律 MUST/MUST NOT + 自检清单），全程受其约束。skill 加载时已通过 `@` include 自动带入，若未生效则显式 Read `~/.claude/skills/loop-engineering/AGENTS.md`。

1. 在项目根创建 `.loop/` 目录
2. 写 `.loop/STATE.yaml`（7-Phase 模板：current_phase=1, current_step=ideate, iteration=1）
3. 创建空资产文件：`learnings.yaml`、`gaps.yaml`、`timeline.jsonl`
4. 产物追踪表按 loop-state.md 的 state_schema 初始化（ideate/spec/design/planning/execute/review/qa/ship/retro 各路径）

完成后询问：
```
Loop Engineering 已初始化。
是否立即开始构想阶段？
  → /office-hours（gstack 6 问深挖产品构想，CEO 视角）
  → 或 /loop:run --next --auto（自动从构想跑起）
```

如果 `.loop/STATE.yaml` 已存在，提示是否覆盖（默认不覆盖，避免丢历史循环记录）。
