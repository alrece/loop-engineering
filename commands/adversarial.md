---
name: "LOOP: Adversarial"
description: "对当前环节产出跑 CCG 对抗性质量门——确定性质量门(安全/质量/变更/模块) + 多模型对抗审查(codex+gemini)，发现问题自动优化+重检，提高 loop 循环产出质量。"
category: Workflow
tags: [loop, adversarial, ccg, quality-gate]
---

# /loop:adversarial

手动触发 CCG 对抗性质量门（不必等闭环自动触发）。参数：`$ARGUMENTS`

- `/loop:adversarial` — 对**当前环节**产出跑完整对抗检查（确定性门 + 多模型审查）
- `/loop:adversarial execute` — 指定对**执行环节**产物检查（代码变更）
- `/loop:adversarial spec` — 对**规格环节**产物检查（OpenSpec specs）
- `/loop:adversarial ship` — 对**发布前**产物做终审
- `/loop:adversarial --debate` — 强制生成对抗讨论记录（即使两模型一致也记录各自观点）
- `/loop:adversarial --deterministic-only` — 只跑确定性质量门（不调多模型，快）

调用 **loop-engineering** skill 的 `--adversarial` 模式，执行 **loop-adversarial.md** workflow：

> ⚠️ **先读行为规范**：执行任何操作前，必须先读 `AGENTS.md`（铁律 MUST/MUST NOT + 自检清单），全程受其约束。skill 加载时已通过 `@` include 自动带入，若未生效则显式 Read `~/.claude/skills/loop-engineering/AGENTS.md`。

1. `run_gate`：按环节配置跑检查（loop-adversarial.sh full <step> <path>）
2. `evaluate`：读 `.loop/adversarial/last-verdict.json` 判定
3. 若 fail：`auto_optimize`（综合建议→自动修复→重检，最多 3 轮）
4. 若多模型分歧：`debate`（生成对抗讨论记录）
5. 重检通过：放行；超限：`escalate`（设 blocker 停问人）

**输出**：
- 终端显示检查结果（确定性门 findings + 两模型评分/建议 + 共识/分歧）
- 写 `.loop/adversarial/last-verdict.json`（供 Gate 4 读取）
- 分歧时写 `.loop/adversarial/debates/{ts}.md`（对抗讨论记录）

无 `.loop/` 目录时提示：`/loop:init [项目名]`。
