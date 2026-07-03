---
name: "LOOP: Retro"
description: "Trigger a Loop Engineering iteration loop — milestone archive → retro → lessons extraction → intent audit → gap analysis → generate next-round seed; reinforces the macro loop."
category: Workflow
tags: [loop, retro, iteration]
---

# /loop:retro

Trigger a macro iteration loop (the strengthened version of Document Phase 6). `$ARGUMENTS` (optional notes)

<!-- 中文译注：触发宏观迭代回环（文档 Phase 6 的强化版）。`$ARGUMENTS`（可选备注）。 -->

Invokes the **loop-engineering** skill in `--retro` mode, executing the **loop-iterate.md** workflow:

<!-- 中文译注：调用 loop-engineering skill 的 `--retro` 模式，执行 loop-iterate.md workflow： -->

> ⚠️ **Read AGENTS.md first**: Before performing any action, you must first read `AGENTS.md` (the MUST/MUST NOT ironclad rules + self-check checklist); it governs the entire process. The skill brings it in automatically via `@` include at load time; if that doesn't take effect, explicitly Read `~/.claude/skills/loop-engineering/AGENTS.md`.

<!-- 中文译注：⚠️ **先读行为规范**：执行任何操作前，必须先读 `AGENTS.md`（铁律 MUST/MUST NOT + 自检清单），全程受其约束。skill 加载时已通过 `@` include 自动带入，若未生效则显式 Read 该文件。 -->

1. `/gsd-complete-milestone` (archive + tag)
   <!-- 中文译注：`/gsd-complete-milestone`（归档 + 打 tag）。 -->
2. `/retro` (gstack engineering retrospective, identify improvement points)
   <!-- 中文译注：`/retro`（gstack 工程回顾，识别改进点）。 -->
3. `/gsd-extract-learnings` (extract decisions/lessons/patterns → `.loop/learnings.yaml`)
   <!-- 中文译注：`/gsd-extract-learnings`（提取决策/教训/模式 → `.loop/learnings.yaml`）。 -->
4. `/gsd-audit-milestone` (audit completion against original intent → `.loop/gaps.yaml`)
   <!-- 中文译注：`/gsd-audit-milestone`（对比原始意图审计完成度 → `.loop/gaps.yaml`）。 -->
5. Based on gaps + unfinished try items, generate the seed for the next round's `/office-hours` (written to history.next_seed)
   <!-- 中文译注：基于 gaps + 未完成 try 项，生成下一轮 `/office-hours` 的种子（写入 history.next_seed）。 -->
6. iteration += 1, reset phase to 1
   <!-- 中文译注：iteration +=1，phase 重置为 1。 -->

On completion, ask:
<!-- 中文译注：完成后询问： -->
```
Loop complete. Enter iteration N+1?
  Yes → /loop:run --next --auto (auto-start the new round from /office-hours)
  No  → /loop:status (view historical loop records)
```

**Does not auto-start the next round by default** — the starting point of the macro loop should be confirmed by the user.

<!-- 中文译注：**默认不自动启动下一轮**——宏观循环的起点应由用户确认。 -->
