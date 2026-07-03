---
name: "LOOP: Adversarial"
description: "Run a CCG adversarial quality gate on the current stage's output — deterministic quality gates (security/quality/change/module) + multi-model adversarial review (codex+gemini); auto-optimizes and re-checks on findings, raising the quality of loop outputs."
category: Workflow
tags: [loop, adversarial, ccg, quality-gate]
---

# /loop:adversarial

Manually trigger the CCG adversarial quality gate (no need to wait for the loop to auto-trigger it). Arguments: `$ARGUMENTS`

<!-- 中文译注：手动触发 CCG 对抗性质量门（不必等闭环自动触发）。参数：`$ARGUMENTS`。 -->

- `/loop:adversarial` — run a full adversarial check (deterministic gates + multi-model review) on the **current stage's** output
  <!-- 中文译注：`/loop:adversarial` — 对**当前环节**产出跑完整对抗检查（确定性门 + 多模型审查）。 -->
- `/loop:adversarial execute` — specify a check on the **execution stage's** artifacts (code changes)
  <!-- 中文译注：`/loop:adversarial execute` — 指定对**执行环节**产物检查（代码变更）。 -->
- `/loop:adversarial spec` — check the **specification stage's** artifacts (OpenSpec specs)
  <!-- 中文译注：`/loop:adversarial spec` — 对**规格环节**产物检查（OpenSpec specs）。 -->
- `/loop:adversarial ship` — run a final review on **pre-release** artifacts
  <!-- 中文译注：`/loop:adversarial ship` — 对**发布前**产物做终审。 -->
- `/loop:adversarial --debate` — force-generate an adversarial debate record (records each model's view even when the two models agree)
  <!-- 中文译注：`/loop:adversarial --debate` — 强制生成对抗讨论记录（即使两模型一致也记录各自观点）。 -->
- `/loop:adversarial --deterministic-only` — run only the deterministic quality gates (no multi-model call; fast)
  <!-- 中文译注：`/loop:adversarial --deterministic-only` — 只跑确定性质量门（不调多模型，快）。 -->

Invokes the **loop-engineering** skill in `--adversarial` mode, executing the **loop-adversarial.md** workflow:

<!-- 中文译注：调用 loop-engineering skill 的 `--adversarial` 模式，执行 loop-adversarial.md workflow： -->

> ⚠️ **Read AGENTS.md first**: Before performing any action, you must first read `AGENTS.md` (the MUST/MUST NOT ironclad rules + self-check checklist); it governs the entire process. The skill brings it in automatically via `@` include at load time; if that doesn't take effect, explicitly Read `~/.claude/skills/loop-engineering/AGENTS.md`.

<!-- 中文译注：⚠️ **先读行为规范**：执行任何操作前，必须先读 `AGENTS.md`（铁律 MUST/MUST NOT + 自检清单），全程受其约束。skill 加载时已通过 `@` include 自动带入，若未生效则显式 Read 该文件。 -->

1. `run_gate`: run checks per the stage config (loop-adversarial.sh full \<step\> \<path\>)
   <!-- 中文译注：`run_gate`：按环节配置跑检查（loop-adversarial.sh full <step> <path>）。 -->
2. `evaluate`: read `.loop/adversarial/last-verdict.json` and render a verdict
   <!-- 中文译注：`evaluate`：读 `.loop/adversarial/last-verdict.json` 判定。 -->
3. On fail: `auto_optimize` (synthesize suggestions → auto-fix → re-check, up to 3 rounds)
   <!-- 中文译注：若 fail：`auto_optimize`（综合建议→自动修复→重检，最多 3 轮）。 -->
4. On multi-model disagreement: `debate` (generate an adversarial debate record)
   <!-- 中文译注：若多模型分歧：`debate`（生成对抗讨论记录）。 -->
5. Re-check passes: allow through; over the limit: `escalate` (set a blocker and stop to ask a person)
   <!-- 中文译注：重检通过：放行；超限：`escalate`（设 blocker 停问人）。 -->

**Output**:
<!-- 中文译注：**输出**： -->
- Terminal shows the check results (deterministic gate findings + both models' scores/suggestions + consensus/disagreement)
  <!-- 中文译注：终端显示检查结果（确定性门 findings + 两模型评分/建议 + 共识/分歧）。 -->
- Writes `.loop/adversarial/last-verdict.json` (read by Gate 4)
  <!-- 中文译注：写 `.loop/adversarial/last-verdict.json`（供 Gate 4 读取）。 -->
- On disagreement, writes `.loop/adversarial/debates/{ts}.md` (adversarial debate record)
  <!-- 中文译注：分歧时写 `.loop/adversarial/debates/{ts}.md`（对抗讨论记录）。 -->

When no `.loop/` directory exists, prompt: `/loop:init [project name]`.

<!-- 中文译注：无 `.loop/` 目录时提示：`/loop:init [项目名]`。 -->
