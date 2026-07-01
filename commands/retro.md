---
name: "LOOP: Retro"
description: "触发 Loop Engineering 迭代回环——里程碑归档→复盘→教训提取→意图审计→差距分析→生成下一轮种子，强化宏观闭环。"
category: Workflow
tags: [loop, retro, iteration]
---

# /loop:retro

触发宏观迭代回环（文档 Phase 6 的强化版）。`$ARGUMENTS`（可选备注）

调用 **loop-engineering** skill 的 `--retro` 模式，执行 **loop-iterate.md** workflow：

> ⚠️ **先读行为规范**：执行任何操作前，必须先读 `AGENTS.md`（铁律 MUST/MUST NOT + 自检清单），全程受其约束。skill 加载时已通过 `@` include 自动带入，若未生效则显式 Read `~/.claude/skills/loop-engineering/AGENTS.md`。

1. `/gsd-complete-milestone`（归档 + 打 tag）
2. `/retro`（gstack 工程回顾，识别改进点）
3. `/gsd-extract-learnings`（提取决策/教训/模式 → `.loop/learnings.yaml`）
4. `/gsd-audit-milestone`（对比原始意图审计完成度 → `.loop/gaps.yaml`）
5. 基于 gaps + 未完成 try 项，生成下一轮 `/office-hours` 的种子（写入 history.next_seed）
6. iteration +=1，phase 重置为 1

完成后询问：
```
闭环完成。是否进入第 N+1 轮迭代？
  是 → /loop:run --next --auto（自动从 /office-hours 开始新一轮）
  否 → /loop:status（查看历史循环记录）
```

**默认不自动启动下一轮**——宏观循环的起点应由用户确认。
