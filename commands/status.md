---
name: "LOOP: Status"
description: "查看 Loop Engineering 工程闭环看板——当前 Phase、迭代轮次、各阶段产物状态、blocker、下一步建议。只读不改。"
category: Workflow
tags: [loop, status, dashboard]
---

# /loop:status

输出跨工具的工程闭环看板。只读，不修改任何状态。

调用 **loop-engineering** skill 的 `--status` 模式，读取 `.loop/STATE.yaml` 后渲染：

> ⚠️ **先读行为规范**：执行任何操作前，必须先读 `AGENTS.md`（铁律 MUST/MUST NOT + 自检清单），全程受其约束。skill 加载时已通过 `@` include 自动带入，若未生效则显式 Read `~/.claude/skills/loop-engineering/AGENTS.md`。

```
╔══════════════════════════════════════════╗
║   Loop Engineering 看板（第 N 轮循环）    ║
╠══════════════════════════════════════════╣
║ 当前：Phase N — {phase名} | step: {步骤}  ║
║ 进度：██████░░░░ N/7                      ║
╠══════════════════════════════════════════╣
║ Phase 状态：                              ║
║  1 构想     ✓ done                        ║
║  2 设计     ✓ done                        ║
║  3 实施     ▶ active  (执行中)            ║
║  4 QA       ○ pending                     ║
║  ...                                      ║
╠══════════════════════════════════════════╣
║ ⛔ Blocker：{若有}                         ║
║ ▶ 下一步：`/{建议命令}`                   ║
║ 📜 历史循环：N 轮，最近复盘要点            ║
╚══════════════════════════════════════════╝
```

无 `.loop/` 目录时提示：`/loop:init [项目名]`。
