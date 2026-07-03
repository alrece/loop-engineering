---
name: "LOOP: Run"
description: "Advance the Loop Engineering engineering loop — detects the current Phase and auto-routes to the next tool (gstack for looking, OpenSpec for writing, GSD for doing), with optional --auto chained self-invocation."
category: Workflow
tags: [loop, orchestration, workflow]
---

# /loop:run

Advance the engineering loop. Arguments: `$ARGUMENTS`

<!-- 中文译注：推进工程闭环。参数：`$ARGUMENTS`。 -->

Invokes the **loop-engineering** skill and routes by arguments.

<!-- 中文译注：调用 loop-engineering skill，按参数路由。 -->

> ⚠️ **Read AGENTS.md first**: Before performing any action, you must first read `AGENTS.md` (the MUST/MUST NOT ironclad rules + self-check checklist); it governs the entire process. The skill brings it in automatically via `@` include at load time; if that doesn't take effect, explicitly Read `~/.claude/skills/loop-engineering/AGENTS.md`.

<!-- 中文译注：⚠️ **先读行为规范**：执行任何操作前，必须先读 `AGENTS.md`（铁律 MUST/MUST NOT + 自检清单），全程受其约束。skill 加载时已通过 `@` include 自动带入，若未生效则显式 Read 该文件。 -->

- `/loop:run --next` — detect `.loop/STATE.yaml` and advance to the next step (invoking the corresponding tool, e.g. `/office-hours`, `/gsd-execute-phase`, `/review`, etc.)
  <!-- 中文译注：`/loop:run --next` — 检测 `.loop/STATE.yaml`，推进到下一步（调用对应工具）。 -->
- `/loop:run --next --auto` — chained auto-advance; after each step completes it automatically re-invokes until it hits a blocker (zero-friction run through the whole loop)
  <!-- 中文译注：`/loop:run --next --auto` — 链式自动推进，每步完成后自动 re-invoke 直到撞上 blocker（零摩擦跑完整个闭环）。 -->
- `/loop:run --phase 4` — jump to the specified Phase (passes the safety gate first)
  <!-- 中文译注：`/loop:run --phase 4` — 跳转到指定 Phase（先过安全门）。 -->
- `/loop:run --from 3` — resume running from Phase N (interrupt recovery)
  <!-- 中文译注：`/loop:run --from 3` — 从 Phase N 续跑（中断恢复）。 -->
- `/loop:run --force --next` — skip the safety gate and force advancement (use with caution)
  <!-- 中文译注：`/loop:run --force --next` — 跳过安全门强制推进（慎用）。 -->

**Read the skill's workflow before executing**: after loading the `loop-engineering` skill, route per its `<process>`. The core is the 11 routing rules in loop-orchestrate.md plus the safety gates in loop-state.md.

<!-- 中文译注：**先读 skill 的工作流再执行**：加载 loop-engineering skill 后，按其 `<process>` 路由。核心是 loop-orchestrate.md 的 11 条路由规则 + loop-state.md 的安全门。 -->

When no `.loop/` directory exists, prompt: `/loop:init [project name]`.

<!-- 中文译注：无 `.loop/` 目录时提示：`/loop:init [项目名]`。 -->
