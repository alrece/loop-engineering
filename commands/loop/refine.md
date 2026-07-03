---
name: "LOOP: Refine"
description: "Professional prompt refinement — takes a one-line user request, performs deep analysis, dynamic follow-up questions, then generates three prompts (standard / compact / advanced high-constraint) for selection. Works for first-time requirements and iterative new requirements."
category: Workflow
tags: [loop, refine, prompt, optimize]
---

# /loop:refine

Professional prompt refiner. Original prompt: `$ARGUMENTS`

<!-- 中文译注：提示词专业化优化器。原始提示词为 `$ARGUMENTS`。 -->

Invokes the **loop-engineering** skill in `--refine` mode:

<!-- 中文译注：调用 loop-engineering skill 的 `--refine` 模式。 -->

> ⚠️ **Read AGENTS.md first**: Before performing any action, you must first read `AGENTS.md` (the MUST/MUST NOT ironclad rules + self-check checklist); it governs the entire process. The skill brings it in automatically via `@` include at load time; if that doesn't take effect, explicitly Read `~/.claude/skills/loop-engineering/AGENTS.md`.

<!-- 中文译注：⚠️ **先读行为规范**：执行任何操作前，必须先读 `AGENTS.md`（铁律 MUST/MUST NOT + 自检清单），全程受其约束。skill 加载时已通过 `@` include 自动带入，若未生效则显式 Read 该文件。 -->

See `loop-refine.md` workflow for the full execution logic. Core flow:

<!-- 中文译注：完整执行逻辑见 `loop-refine.md` workflow。核心流程： -->

1. **Receive** the user's original one-line request (`$ARGUMENTS`)
   <!-- 中文译注：**接收** 用户的原始一句话需求（`$ARGUMENTS`）。 -->
2. **Analyze** identify missing/ambiguous points across 8 dimensions
   <!-- 中文译注：**分析** 按 8 个维度识别缺失/模糊点。 -->
3. **Ask** use AskUserQuestion to ask 3-6 key questions in one shot (dynamically generated, targeting uncovered dimensions)
   <!-- 中文译注：**追问** 用 AskUserQuestion 一次问 3-6 个关键问题（动态生成，针对未覆盖维度）。 -->
4. **Generate** after synthesizing the answers, **always produce three** prompts:
   <!-- 中文译注：**生成** 综合答复后**总是产出三套**提示词： -->
   - **Standard**: for daily use, with clear hierarchical logic and explicit execution order
     <!-- 中文译注：**标准版**：日常使用，层级逻辑清晰、执行顺序明确。 -->
   - **Compact**: for iterative conversations, a tight structure suited to quickly dispatching instructions
     <!-- 中文译注：**精简版**：迭代对话，紧凑结构，适合快速下发指令。 -->
   - **Advanced high-constraint**: tailored for AI Agents, reinforcing file reads + auth guards + original-logic protection + mandatory quality gates
     <!-- 中文译注：**高阶强约束版**：适配 AI Agent，强化文件读取 + 鉴权保护 + 原有逻辑保护 + 质量门强制。 -->
5. **Select** use AskUserQuestion to let the user pick one (the agent never picks for them)
   <!-- 中文译注：**选定** 用 AskUserQuestion 让用户选一套（agent 不替选）。 -->
6. **Save** write to `.loop/refined-prompt.md` (contains original / Q&A log / all three full texts / the selected version)
   <!-- 中文译注：**保存** 写入 `.loop/refined-prompt.md`（含原始/追问记录/三套全文/选定版本）。 -->

On completion, prompt:
<!-- 中文译注：完成后提示： -->
```
✓ Prompt refined and saved to .loop/refined-prompt.md ({selected} version)

Next steps:
  → /office-hours (enter ideation deep-dive with the refined prompt)
  → or /loop:run --next --auto (auto-advance the loop)
```

## When to use

<!-- 中文译注：## 何时用 -->

| Scenario | Description |
|----------|-------------|
| First new project | After `/loop:init`, before `/office-hours` — turn a one-line idea into a professional requirement |
| Iterative new requirements | Each time a new requirement comes in, refine it first, then enter the loop |
| Anytime | Use whenever you want to turn a vague idea into a clear one; does not require `.loop/` to be initialized |

<!-- 中文译注：| 场景 | 说明 |——首次新项目（init 后、office-hours 前）；迭代新需求（先 refine 再进循环）；任意时刻（模糊变清晰，不依赖 .loop/ 已初始化）。 -->

## Relationship to other commands

<!-- 中文译注：## 与其他命令的关系 -->

- **Does not depend on init**: usable even when `.loop/` doesn't exist (generates `refined-prompt.md` in the cwd)
  <!-- 中文译注：**不依赖 init**：`.loop/` 不存在也能用（在 cwd 生成 refined-prompt.md）。 -->
- **Does not advance the loop**: refine is a cross-cutting tool; it does not modify STATE.yaml's current_phase/step
  <!-- 中文译注：**不推进闭环**：refine 是横切工具，不改 STATE.yaml 的 current_phase/step。 -->
- **Does not auto-invoke office-hours**: on completion it only prompts; the user decides the next step
  <!-- 中文译注：**不自动调 office-hours**：完成后仅提示，由用户决定下一步。 -->
