---
name: "loop-engineering"
description: "Loop Engineering — a fully autonomous long-horizon engineering closed loop. Propose an idea → rough plan → run the entire project automatically (auto-selecting the best option at each decision point), only calling the user for verification at the end. Cross-tool orchestration of gstack (review) / OpenSpec (write) / GSD (build) / Superpowers (guard), with a CCG adversarial quality gate embedded at each stage, and execute running plan-by-plan with checks."
metadata:
  short-description: "Fully autonomous long-horizon engineering closed loop with adversarial quality gates"
---

<codex_skill_adapter>
## A. Skill Invocation
- This skill is invoked by mentioning `$loop-engineering`.
- Treat all user text after `$loop-engineering` as `{{GSD_ARGS}}`.
- If no arguments are present, treat `{{GSD_ARGS}}` as empty.

## B. AskUserQuestion → request_user_input Mapping
Loop Engineering workflows use `AskUserQuestion` (Claude Code syntax) for: /loop:refine dynamic follow-up questions (3-6 questions), 3-prompt selection, blocker confirmation. Translate to Codex `request_user_input`:

Parameter mapping:
- `header` → `header`
- `question` → `question`
- Options formatted as `"Label" — description` → `{label: "Label", description: "description"}`
- Generate `id` from header: lowercase, replace spaces with underscores

Batched calls:
- `AskUserQuestion([q1, q2])` → single `request_user_input` with multiple entries in `questions[]`

Multi-select workaround:
- Codex has no `multiSelect`. Use sequential single-selects, or present a numbered freeform list asking the user to enter comma-separated numbers.

Execute mode fallback:
- When `request_user_input` is rejected or unavailable, activate TEXT_MODE: append `--text` to `{{GSD_ARGS}}` so the workflow's built-in text-mode branching takes over. Present every `AskUserQuestion` call as a plain-text numbered list, then stop and wait for the user's reply. Do NOT pick a default and continue (#3018 / #3808).
- You may only proceed without a user answer when one of these is true:
  (a) the invocation included an explicit non-interactive flag (`--auto` or `--all`),
  (b) the user has explicitly approved a specific default for this question, or
  (c) the workflow's documented contract says defaults are safe (e.g. autonomous lifecycle paths).
- For /loop:refine 3-prompt selection specifically: MUST first fully display all three prompts (each set's full text in a code block), then use `request_user_input` for the selection. Do NOT skip the full display.

## C. Task() → spawn_agent Mapping
Loop Engineering workflows use `Task(...)` (Claude Code syntax) for spawning subagents (e.g., gsd-executor for plan-by-plan execution, multi-model adversarial reviewers). Translate to Codex collaboration tools:

Direct mapping:
- `Task(subagent_type="X", prompt="Y")` → `spawn_agent(agent_type="X", message="Y")`
- `Agent(subagent_type="X", prompt="Y")` → `spawn_agent(agent_type="X", message="Y")`
- `Task(model="...")` → omit. `spawn_agent` has no inline `model` parameter.
- Resolved `reasoning_effort="low|medium|high|xhigh"` → pass `reasoning_effort` to `spawn_agent` when supported; omit otherwise.
- `fork_context: false` by default.
- `Task(isolation="worktree")` → no direct Codex mapping. Workflows requiring isolation must fail closed or use manual worktree protocol (#3360).

Spawn restriction:
- Codex restricts `spawn_agent` to cases where the user has explicitly requested sub-agents. When automatic spawning is not permitted, do the work inline.

Parallel fan-out:
- Spawn multiple agents → collect agent IDs → `wait(ids)` for all to complete

Result parsing:
- Look for structured markers in agent output: `CHECKPOINT`, `PLAN COMPLETE`, `SUMMARY`, etc.
- `close_agent(id)` after collecting results from each agent
</codex_skill_adapter>

<objective>
Loop Engineering is an **orchestration layer**. It does not rebuild the existing capabilities of gstack/GSD/OpenSpec; instead, it chains them into an automatically repeatable engineering closed loop according to documented best practices.

<!-- 中文译注：Loop Engineering 是编排层，不重造 gstack/GSD/OpenSpec 能力，而是按文档最佳实践把它们串成可自动循环的工程闭环。 -->

**Design philosophy (v2 fully autonomous long-horizon)**: Propose an idea → rough plan → run the entire project automatically. At each decision point the best option is auto-selected and execution continues, only pausing for the user to verify once the whole project is complete. If the user finds problems, they are corrected in a new round of planning.

<!-- 中文译注：v2 全自动长程哲学——提出想法→大致规划→自动跑完，决策点用最佳方案自动选择后继续，整个项目跑完才叫用户验证；用户发现问题在新一轮规划中修正。 -->

Five capabilities:
1. **Fully autonomous long-horizon closed loop**: 13 routes (including the front-end lifecycle Route 3.5/3.6) + `--auto` default fully autonomous (only Hard Blockers stop it) + `--interactive` optional conservative mode. execute runs plan-by-plan with checks.
   <!-- 中文译注：能力一——全自动长程闭环：13 路由 + --auto 默认全自动（只有硬障碍才停）+ --interactive 保守；execute 逐 plan 执行+检查。 -->
2. **Full front-end lifecycle coverage + a complete design toolkit** (v4.2): **Replicate** (Route 3.4 — 7-step reverse engineering of the reference repo) → **Design decisions** (Route 3.5: teach-impeccable collects context + ui-ux-pro-max design knowledge library selects style/palette/font + design-taste-frontend guards against cookie-cutter AI output + /design-consultation competitor research) → **Implement & polish** (Route 3.6: /design-shotgun variants + /design-html Vue3 code + impeccable 21 sub-skills for quality polish — polish/arrange/typeset/colorize/animate/delight/critique) → **Test** (/qa real browser). Eliminates "no UI after deploy" or "rough UI".
   <!-- 中文译注：能力二——前端生命周期全覆盖 + 设计能力全家桶：复刻→设计决策→实现+打磨→测试，杜绝"部署后无界面/界面粗糙"。 -->
3. **Tiered decision-making**: Small decisions the loop auto-selects the best option; large decisions (architecture/scope/dependencies) invoke multi-model (codex+gemini) discussion then choose. All automatic decisions are recorded to decisions.jsonl for traceability.
   <!-- 中文译注：能力三——分层决策：小决策 loop 自主选，大决策调多模型讨论后选，所有自动决策记录到 decisions.jsonl 供追溯。 -->
4. **Adversarial quality gate** (CCG): every stage that produces output runs an adversarial check (deterministic gate + multi-model + front-end check); problems found are auto-optimized then re-checked.
   <!-- 中文译注：能力四——对抗性质量门：每个有产出的环节跑对抗检查（确定性门+多模型+前端检查），发现问题自动优化+重检。 -->
5. **Prompt specialization/refinement** (new in v4.3): `/loop:refine` takes a one-sentence requirement → 8-dimension deep analysis → dynamically asks 3-6 follow-up questions → always generates three sets (standard / compact / advanced strict) for the user to choose. A cross-cutting tool that does not depend on init and does not advance the closed loop.
   <!-- 中文译注：能力五——提示词专业化优化（v4.3）：/loop:refine 接收一句话需求→8 维度分析→动态追问 3-6 个问题→总是生成三套供用户选；横切工具，不依赖 init、不推进闭环。 -->

Design follows the GSD style: SKILL.md is kept minimal, logic is externalized into workflow files, and looping is implemented via @ includes + inline execution / spawn_agent (Codex has no SlashCommand self-invocation; see adapter A/C).
<!-- 中文译注：设计遵循 GSD 风格——SKILL.md 极小，逻辑外置到 workflow 文件，用 @ include + inline 执行 / spawn_agent 实现循环（Codex 无 SlashCommand 自调用，见 adapter A/C）。 -->
</objective>

<execution_context>
@$HOME/.codex/skills/loop-engineering/AGENTS.md
@$HOME/.codex/get-shit-done/workflows/loop-state.md
@$HOME/.codex/get-shit-done/workflows/loop-orchestrate.md
@$HOME/.codex/get-shit-done/workflows/loop-iterate.md
@$HOME/.codex/get-shit-done/workflows/loop-adversarial.md
@$HOME/.codex/get-shit-done/workflows/replicate-workflow.md
@$HOME/.codex/get-shit-done/workflows/loop-refine.md
</execution_context>

<roles>
Tool-family responsibilities (one-line summary per the docs; strictly respect boundaries during orchestration):
- **gstack owns "review"**: audits, QA, security audit, deployment, product thinking (CEO perspective).
- **GSD owns "build"**: planning, execution, verification, milestone management.
- **OpenSpec owns "write"**: specification definition (SDD approach).
- **Superpowers owns "guard"**: enforced TDD, debugging, quality gates (passively triggered, no need to call).
- **CCG does multi-model routing**: switches Claude/Codex/Gemini on demand.

<!-- 中文译注：工具家族职责——gstack 看（审核/QA/安全/部署/产品思维）、GSD 做（规划/执行/验证/里程碑）、OpenSpec 写（规格 SDD）、Superpowers 守（TDD/调试/质量门，被动触发）、CCG 多模型路由。编排时严格遵守边界。 -->
</roles>

<process>
Arguments provided: "{{GSD_ARGS}}"

Parse the first token to determine mode:
<!-- 中文译注：解析第一个 token 决定模式。 -->

**`--init <name> [--reference <url|repo>]`** → perform initialization:
1. Create the project root `.loop/` directory + `STATE.yaml` (7-Phase template, see state_schema in loop-state.md).
2. Create empty `learnings.yaml`, `gaps.yaml`, `timeline.jsonl` files.
3. current_phase=1, current_step=ideate, iteration=1.
4. **If `--reference <url|repo>` is provided**: write the reference_target into STATE.yaml (git URL / local path / live URL); Route 3.4 will later trigger the replication flow.
5. Ask whether to immediately invoke `$office-hours` to enter Ideation (the documented Phase 1 entry point).
<!-- 中文译注：--init 初始化——建 .loop/ 目录+STATE.yaml（7-Phase 模板）+空资产文件；带 --reference 则写 reference_target，后续 Route 3.4 触发复刻。 -->

**`--refine <text>`** → perform prompt specialization/refinement (new in v4.3): fully delegated to the loop-refine.md workflow.
1. Receive the user's one-sentence requirement (`<text>`), and deeply analyze missing/ambiguous points across 8 dimensions.
2. Use `request_user_input` to **dynamically generate 3-6 follow-up questions** (targeting uncovered dimensions, asked once in parallel).
3. After synthesizing the answers, **always generate three sets** of prompts: standard (daily use) / compact (iterative dialogue) / advanced strict (AI Agent hardened protection).
4. **First fully display all three prompts in the conversation** (each set's full text rendered as a code block, the user must be able to read every line), **then** use `request_user_input` to let the user choose one set (**the agent MUST NOT choose for the user; MUST NOT skip the full display and jump to the selection**).
5. Write to `.loop/refined-prompt.md` (contains the original prompt / follow-up Q&A / the three full prompts / the selected version).
6. Suggest next step: `$office-hours` (carrying the refined prompt) or `$loop-engineering --next`. **Do NOT auto-invoke; do NOT advance the closed loop** (refine is a cross-cutting tool).
<!-- 中文译注：--refine 提示词专业化优化——接收一句话需求→8 维度分析→用 request_user_input 动态追问 3-6 个→总是生成三套→用户选→写 refined-prompt.md；不自动调用、不推进闭环（横切工具）。 -->

**`--status`** (or no arguments) → render a read-only dashboard:
1. Read `.loop/STATE.yaml`.
2. Output the closed-loop dashboard: current Phase/step, iteration count, artifact status of each stage, blockers, suggested next-step command, and a summary of historical loops.
3. Do NOT modify any state.
<!-- 中文译注：--status 只读看板——读 STATE.yaml，输出当前 Phase/步骤、迭代轮次、各阶段产物状态、blocker、下一步建议命令、历史循环摘要；不修改任何状态。 -->

**`--retro`** → perform the iteration loop: fully delegated to the loop-iterate.md workflow (retro → lessons → audit → seed → close loop).
<!-- 中文译注：--retro 迭代回环——交给 loop-iterate.md（retro→教训→审计→种子→闭环）。 -->

**`--next [--auto|--interactive|--force]`** → perform advancement (defaults to --auto fully autonomous):
1. Invoke loop-state.md's read_state + safety_gates (behavior varies by mode).
2. **--auto / --force (default v3.1)**: enter the **run_full_loop single-session inline continuous loop** of loop-orchestrate.md — the loop itself, in the main session, Reads each stage's main-tool SKILL.md + workflow and executes them inline (using Read/Write/Edit/Bash/request_user_input), NOT via SlashCommand (Codex has no SlashCommand; inline execution preferred), NOT via Skill() (Codex has no such tool), NOT via spawn_agent for the main loop (spawn_agent only for explicitly-permitted sub-agents, see adapter C). After each stage it runs the adversarial gate + advance_loop to advance; at decision points decide_best auto-selects; only a Hard Blocker breaks. **A single invocation runs the whole way, without interruption.** `--force` additionally skips all safety gates.
3. **--interactive**: each stage is invoked via inline execution or spawn_agent (step-by-step); on hitting a decision/safety gate it stops and asks a human (conservative behavior).
4. On hitting a decision point: invoke decide_best (--auto: small decisions auto-selected / large decisions multi-model discussion; --interactive: stops and asks a human).
5. show_and_execute: --auto/--force uses inline execution; --interactive uses spawn_agent or inline step-by-step.
<!-- 中文译注：--next 推进——默认 --auto 全自动：进入 run_full_loop 单会话 inline 连续循环（loop 自己 Read skill 指令+主会话执行，非 SlashCommand/Skill/spawn_agent 主循环），每环节后跑对抗门+advance_loop 前进，遇决策点 decide_best 自动选，只有硬障碍才 break，一次调用跑完全程；--interactive 用 inline/spawn_agent 逐步调用，撞决策/安全门即停问人。 -->

**`--adversarial [step]`** → manually trigger an adversarial check (no need to wait for the loop to auto-trigger):
1. step is optional (spec/design/plan/execute/review/ship); if omitted, takes STATE.yaml's current_step.
2. Fully delegated to the loop-adversarial.md workflow (run_gate → evaluate → auto_optimize/debate/escalate).
3. Supports `--debate` (force-record both models' viewpoints) and `--deterministic-only` (run only deterministic gates, no multi-model).
<!-- 中文译注：--adversarial 手动触发对抗检查——step 可选（缺省取 current_step），交给 loop-adversarial.md（run_gate→evaluate→auto_optimize/debate/escalate）；支持 --debate、--deterministic-only。 -->

**`--phase N`** → jump to the specified Phase (first pass safety_gates, confirming the previous stage's artifacts are complete).
<!-- 中文译注：--phase N 跳转到指定 Phase（先过 safety_gates，确认上一阶段产物完整）。 -->

**`--from N`** → resume running from Phase N (used for recovery after interruption, skipping completed stages).
<!-- 中文译注：--from N 从 Phase N 续跑（中断恢复，跳过已完成阶段）。 -->

**When there is no `.loop/`**: prompt `$loop-engineering --init [project name]`.

Preserve all routing/gate logic from the included workflows. Do not invent new routing rules outside loop-orchestrate.md.
<!-- 中文译注：无 .loop/ 时提示 $loop-engineering --init [项目名]。保留所含 workflow 的路由/门逻辑，不在 loop-orchestrate.md 之外发明新路由规则。 -->
</process>

<success_criteria>
- [ ] {{GSD_ARGS}} is correctly routed to each mode (init/refine/status/retro/next/adversarial/phase/from).
- [ ] Orchestration invokes existing tools ($office-hours $opsx:* $plan-*-review $gsd-* $review $cso $qa $ship $canary $land-and-deploy $retro), without rebuilding capabilities.
- [ ] --next defaults to --auto fully autonomous; --interactive stops on hitting a decision.
- [ ] --auto only stops on a Hard Blocker (compile failure unresolved after 3 rounds / missing dependency / escalate limit exceeded / user pause).
- [ ] **--auto enters the run_full_loop single-session inline continuous loop** (the loop itself Reads the skill instructions + executes in the main session, NOT SlashCommand/Skill/spawn_agent-main-loop); a single invocation runs the whole way without interruption.
- [ ] decide_best correctly tiers: small decisions auto-selected, large decisions invoke decide-large multi-model discussion.
- [ ] All automatic decisions are recorded to .loop/decisions.jsonl.
- [ ] Route 6 (execute) uses plan-by-plan mode (gsd-executor single plan + plan-level adversarial gate), no longer calling /gsd-execute-phase to run everything at once.
- [ ] safety_gates has 5 gates (Gate 5 verifies consistency with GSD state), with behavior split by mode.
- [ ] Stages that produce output run adversarial_gate after producing.
- [ ] On adversarial failure, auto_optimize (≤3 rounds); on exceeding the limit, escalate (--auto still tries decide_best to work around; only a Hard Blocker stops).
- [ ] status mode is read-only.
- [ ] init generates a complete STATE.yaml + empty asset files.
<!-- 中文译注：自检清单——路由正确、调现有工具不重造、--auto 默认全自动、只有硬障碍才停、run_full_loop 单会话 inline 连续循环、decide_best 分层、决策记录 jsonl、execute 逐 plan、safety_gates 5 道、有产出跑对抗门、未通过 auto_optimize(≤3轮)→escalate、status 只读、init 生成完整 STATE.yaml+空资产。 -->
</success_criteria>

<runtime_note>
**Codex specifics:**
- `AskUserQuestion` → `request_user_input` (see adapter B). Observe #3018 fallback rules strictly.
- `Task()` / `Agent()` → `spawn_agent` (see adapter C). `spawn_agent` only when user explicitly requests sub-agents.
- Multi-model adversarial: Codex itself is one of the adversarial models; the gate script invokes codex+gemini via codeagent-wrapper over Shell — this works natively on Codex runtime.
- `--auto` mode: inline execution preferred; `spawn_agent` only when explicitly permitted by Codex session policy.
- For plan-by-plan execution with worktree isolation: not supported natively (#3360); use inline or manual worktree protocol.
</runtime_note>
