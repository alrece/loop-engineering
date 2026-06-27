---
name: "LOOP: Run"
description: "推进 Loop Engineering 工程闭环——检测当前 Phase，自动路由到下一个工具（gstack看/OpenSpec写/GSD做），可选 --auto 链式自调用循环。"
category: Workflow
tags: [loop, orchestration, workflow]
---

# /loop:run

推进工程闭环。参数：`$ARGUMENTS`

调用 **loop-engineering** skill，按参数路由：

- `/loop:run --next` — 检测 `.loop/STATE.yaml`，推进到下一步（调用对应工具，如 `/office-hours`、`/gsd-execute-phase`、`/review` 等）
- `/loop:run --next --auto` — 链式自动推进，每步完成后自动 re-invoke 直到撞上 blocker（零摩擦跑完整个闭环）
- `/loop:run --phase 4` — 跳转到指定 Phase（先过安全门）
- `/loop:run --from 3` — 从 Phase N 续跑（中断恢复）
- `/loop:run --force --next` — 跳过安全门强制推进（慎用）

**先读 skill 的工作流再执行**：加载 `loop-engineering` skill 后，按其 `<process>` 路由。核心是 loop-orchestrate.md 的 11 条路由规则 + loop-state.md 的安全门。

无 `.loop/` 目录时提示：`/loop:init [项目名]`。
