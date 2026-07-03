---
name: "LOOP: Refine"
description: "提示词专业化优化——接收用户一句话需求，深度分析→动态追问→生成三套（标准/精简/高阶强约束）提示词供选择。适用于首次需求和迭代新需求。"
category: Workflow
tags: [loop, refine, prompt, optimize]
---

# /loop:refine

提示词专业化优化器。原始提示词：`$ARGUMENTS`

调用 **loop-engineering** skill 的 `--refine` 模式：

> ⚠️ **先读行为规范**：执行任何操作前，必须先读 `AGENTS.md`（铁律 MUST/MUST NOT + 自检清单），全程受其约束。skill 加载时已通过 `@` include 自动带入，若未生效则显式 Read `~/.claude/skills/loop-engineering/AGENTS.md`。

完整执行逻辑见 `loop-refine.md` workflow。核心流程：

1. **接收** 用户的原始一句话需求（`$ARGUMENTS`）
2. **分析** 按 8 个维度识别缺失/模糊点
3. **追问** 用 AskUserQuestion 一次问 3-6 个关键问题（动态生成，针对未覆盖维度）
4. **生成** 综合答复后**总是产出三套**提示词：
   - **标准版**：日常使用，层级逻辑清晰、执行顺序明确
   - **精简版**：迭代对话，紧凑结构，适合快速下发指令
   - **高阶强约束版**：适配 AI Agent，强化文件读取 + 鉴权保护 + 原有逻辑保护 + 质量门强制
5. **选定** 用 AskUserQuestion 让用户选一套（agent 不替选）
6. **保存** 写入 `.loop/refined-prompt.md`（含原始/追问记录/三套全文/选定版本）

完成后提示：
```
✓ 提示词已优化并保存到 .loop/refined-prompt.md（{选定版本}版）

下一步建议：
  → /office-hours（带优化后提示词进入构想深挖）
  → 或 /loop:run --next --auto（自动推进闭环）
```

## 何时用

| 场景 | 说明 |
|------|------|
| 首次新项目 | `/loop:init` 后、`/office-hours` 前，把一句话想法转成专业需求 |
| 迭代新需求 | 每轮新需求进来时，先 refine 再进入循环 |
| 任意时刻 | 想把模糊想法变清晰时都能用，不依赖 `.loop/` 已初始化 |

## 与其他命令的关系

- **不依赖 init**：`.loop/` 不存在也能用（在 cwd 生成 `refined-prompt.md`）
- **不推进闭环**：refine 是横切工具，不改 STATE.yaml 的 current_phase/step
- **不自动调 office-hours**：完成后仅提示，由用户决定下一步
