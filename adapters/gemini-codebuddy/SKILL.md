---
name: loop-engineering
description: "Loop Engineering — a fully autonomous long-horizon engineering closed loop (degraded version for Gemini CLI / Codebuddy). Propose an idea → rough plan → run the project. Cross-tool orchestration of gstack / OpenSpec / GSD / Superpowers with adversarial quality gates. NOTE: interactive features (AskUserQuestion, SlashCommand loop, multi-model adversarial) are degraded on this runtime; use Claude Code / ZCode for full capabilities."
allowed-tools: Read,Write,Edit,Bash,Grep,Glob
---

<degradation_notice>
**⚠️ DEGRADED VERSION — Gemini CLI / Codebuddy runtime.**

This SKILL.md is an adapter-wrapped copy of the canonical Loop Engineering skill. Because Gemini CLI and Codebuddy lack several mechanisms the canonical version depends on, the following capabilities are **degraded** on this runtime:

| Capability | Native (Claude Code / ZCode) | This adapter (Gemini / Codebuddy) |
|------------|------------------------------|-----------------------------------|
| `AskUserQuestion` follow-ups | ✅ Structured multi-select | ⚠ Replaced by plain-text numbered questions |
| 3-prompt display + selection (refine) | ✅ Structured single-select | ⚠ Plain-text display + "reply 1/2/3" |
| `SlashCommand` self-loop (`--auto`) | ✅ Single invocation runs to completion | ⚠ Inline single-step execution; user must manually re-trigger each step |
| `@include` of AGENTS.md + workflows | ✅ Loaded on demand | ❌ Inlined as summaries below (no `@include`) |
| Multi-model adversarial (codex+gemini) | ✅ Two-model debate | ⚠ Degraded to single-model (this runtime only) |

**For the full, uninterrupted closed loop, use Claude Code or ZCode with the canonical root `SKILL.md`.**

<!-- 中文译注：降级版声明——Gemini CLI/Codebuddy 运行时不支持 AskUserQuestion/SlashCommand 循环/@include/多模型对抗，故这些能力在此端降级。完整闭环请用 Claude Code/ZCode 的根 SKILL.md。 -->
</degradation_notice>

<runtime_adapter>
## Tool Name Mapping

The canonical SKILL.md references tools by their Claude Code names. On this runtime, map them as follows:

| Canonical name | Gemini CLI | Codebuddy |
|----------------|------------|-----------|
| `Read` | `read_file` | `Read` (kept) |
| `Write` | `write_file` | `Write` (kept) |
| `Edit` | `replace` | `Edit` (kept) |
| `Bash` | `run_shell_command` | `Bash` (kept) |
| `Grep` | `search_file_content` | `Grep` (kept) |
| `Glob` | `list_directory` / `glob` | `Glob` (kept) |

> Codebuddy preserves Claude-style tool names. Gemini CLI uses a different naming scheme — when an instruction below says "Read X", a Gemini user performs the equivalent `read_file` action. Instructions in this file keep the canonical names for clarity; apply the mapping at execution time.

<!-- 中文译注：工具名映射——Codebuddy 保留 Claude 原名；Gemini 用 read_file/run_shell_command/search_file_content 等。本文件保留 canonical 名，执行时按表映射。 -->

## Interactive Q&A (replaces AskUserQuestion)

Anywhere the canonical version says "use AskUserQuestion", this adapter instead emits **plain-text numbered questions** in the conversation and waits for the user's reply. Pattern:

```
请回答以下问题（可直接回复编号+答案）：
1. <question one>
2. <question two>
3. <question three>
```

For the `/loop:refine` 3-prompt selection, the three prompts are fully displayed as code blocks first, followed by:

```
请回复 1 / 2 / 3 选择一套（1=标准 / 2=精简 / 3=高阶强约束）：
```

The agent **MUST NOT choose for the user**; it must wait for the reply.

<!-- 中文译注：交互问答替代——凡原版用 AskUserQuestion 处，改为纯文本编号提问等用户回复；refine 三套先全文展示再"请回复 1/2/3 选择"，agent 不得替选。 -->

## Loop Execution (replaces SlashCommand self-loop)

The canonical `--auto` mode runs the entire project in a single session via a `run_full_loop` while-loop with inline execution. This runtime has no equivalent self-loop primitive, so:

- **`--auto` degrades to single-step inline execution**: each invocation runs ONE stage (read state → safety gates → determine route → inline-execute the main tool → adversarial gate → advance), then **stops** and tells the user the next command to run.
- The user must **manually re-trigger** the next step (e.g. by sending the loop command again) until the project completes or a Hard Blocker is hit.
- `--interactive` mode is unchanged (it always stopped between steps).

After each step, display:

```
✅ 本 step 完成（Phase {N} / step {current_step}）。
▶ 下一步请手动触发：/loop:run --next {auto|interactive}
```

<!-- 中文译注：循环执行替代——本运行时无 SlashCommand 自循环原语，--auto 降级为单步 inline 执行（每次调用跑一个环节即停），用户需手动重新触发下一步；--interactive 行为不变。 -->
</runtime_adapter>

<objective>
Loop Engineering is an **orchestration layer**. It does not rebuild the existing capabilities of gstack/GSD/OpenSpec; instead, it chains them into an automatically repeatable engineering closed loop according to documented best practices.

<!-- 中文译注：Loop Engineering 是编排层，不重造 gstack/GSD/OpenSpec 能力，而是按文档最佳实践把它们串成可自动循环的工程闭环。 -->

**Design philosophy (v2 fully autonomous long-horizon)**: Propose an idea → rough plan → run the entire project automatically. At each decision point the best option is auto-selected and execution continues, only pausing for the user to verify once the whole project is complete. If the user finds problems, they are corrected in a new round of planning.

<!-- 中文译注：v2 全自动长程哲学——提出想法→大致规划→自动跑完，决策点用最佳方案自动选择后继续，整个项目跑完才叫用户验证；用户发现问题在新一轮规划中修正。 -->

Five capabilities:
1. **Fully autonomous long-horizon closed loop**: 13 routes (including the front-end lifecycle Route 3.5/3.6) + `--auto` default fully autonomous (only Hard Blockers stop it) + `--interactive` optional conservative mode. execute runs plan-by-plan with checks.
   <!-- 中文译注：能力一——全自动长程闭环：13 路由 + --auto 默认全自动（只有硬障碍才停）+ --interactive 保守；execute 逐 plan 执行+检查。 -->
   > ⚠ On this adapter `--auto` degrades to single-step inline execution (see `<runtime_adapter>`). The "single invocation runs to completion" property is lost; the user re-triggers each step.
2. **Full front-end lifecycle coverage + a complete design toolkit** (v4.2): **Replicate** (Route 3.4 — 7-step reverse engineering of the reference repo) → **Design decisions** (Route 3.5: teach-impeccable collects context + ui-ux-pro-max design knowledge library selects style/palette/font + design-taste-frontend guards against cookie-cutter AI output + /design-consultation competitor research) → **Implement & polish** (Route 3.6: /design-shotgun variants + /design-html Vue3 code + impeccable 21 sub-skills for quality polish — polish/arrange/typeset/colorize/animate/delight/critique) → **Test** (/qa real browser). Eliminates "no UI after deploy" or "rough UI".
   <!-- 中文译注：能力二——前端生命周期全覆盖 + 设计能力全家桶：复刻→设计决策→实现+打磨→测试，杜绝"部署后无界面/界面粗糙"。 -->
3. **Tiered decision-making**: Small decisions the loop auto-selects the best option; large decisions (architecture/scope/dependencies) invoke multi-model (codex+gemini) discussion then choose. All automatic decisions are recorded to decisions.jsonl for traceability.
   <!-- 中文译注：能力三——分层决策：小决策 loop 自主选，大决策调多模型讨论后选，所有自动决策记录到 decisions.jsonl 供追溯。 -->
   > ⚠ On this adapter the multi-model discussion degrades to single-model (this runtime only); large decisions are made by the single available model + recorded with a note.
4. **Adversarial quality gate** (CCG): every stage that produces output runs an adversarial check (deterministic gate + multi-model + front-end check); problems found are auto-optimized then re-checked.
   <!-- 中文译注：能力四——对抗性质量门：每个有产出的环节跑对抗检查（确定性门+多模型+前端检查），发现问题自动优化+重检。 -->
   > ⚠ On this adapter the multi-model part degrades to deterministic-gates-only + single-model; the deterministic gate and auto_optimize loop still run.
5. **Prompt specialization/refinement** (new in v4.3): `/loop:refine` takes a one-sentence requirement → 8-dimension deep analysis → dynamically asks 3-6 follow-up questions → always generates three sets (standard / compact / advanced strict) for the user to choose. A cross-cutting tool that does not depend on init and does not advance the closed loop.
   <!-- 中文译注：能力五——提示词专业化优化（v4.3）：/loop:refine 接收一句话需求→8 维度分析→动态追问 3-6 个问题→总是生成三套供用户选；横切工具，不依赖 init、不推进闭环。 -->
   > ⚠ On this adapter the follow-up questions and the 3-way selection use plain-text mode (see `<runtime_adapter>`).
</objective>

<inline_iron_rules>
Core behavioral constraints, summarized from AGENTS.md. Obey these before executing any `/loop:*` action.

**MUST:**
1. Treat `.loop/STATE.yaml` as the **single source of truth** — all state judgments (Phase, step, blocker) are READ from it; never guess.
2. In `--auto` mode, at decision points auto-select the best option and continue (small decisions auto-selected, large decisions invoke multi-model discussion — degraded to single-model here); only a **Hard Blocker** stops. In `--interactive`, stop on hitting a decision/safety gate and ask a human (plain-text).
3. Stages that produce output (spec/design/plan/execute/review/ship) **MUST run adversarial_gate after producing**. execute is plan-level.
4. **Orchestrate by invoking existing tools** (gstack/GSD/OpenSpec/CCG); do not rebuild their capabilities. The routing table lives in `<inline_routes>`; do not invent new routes.
5. Route 6 (execute) **MUST use plan-by-plan mode**: one plan at a time with a plan-level adversarial gate after each. Do not call `/gsd-execute-phase` to run everything at once.
6. All automatic decisions **MUST be recorded to `.loop/decisions.jsonl`**.
7. State changes **MUST be written back to STATE.yaml (atomic write: write `.tmp` then rename) + appended to `.loop/timeline.jsonl`**.
8. `/loop:refine` **MUST always generate three sets and MUST let the user choose** (via plain-text "reply 1/2/3"); first fully display all three, never choose for the user, never skip the follow-up questions.
9. Front-end lifecycle **MUST be complete + a full design toolkit** (Route 3.4 → 3.5 → 3.6; 3.4 skippable when no reference). Front-end output MUST go through impeccable polish (at least critique + polish). Deployment MUST include the frontend and MUST NOT hide it behind profiles.
10. Output in the **same language as the user's input prompt** (code/commands/paths/proper nouns excepted).

<!-- 中文译注：铁律摘要——STATE.yaml 为单一事实源；--auto 决策点自动选最佳只有硬障碍才停；有产出跑对抗门；调现有工具不重造；Route 6 逐 plan；决策记 jsonl；状态原子写+timeline；refine 总是三套让用户选；前端生命周期完整+全家桶；跟随用户语言输出。 -->

**MUST NOT:**
1. MUST NOT stop in `--auto` "because it needs a human decision" — that is `--interactive`. `--auto` stops only on a Hard Blocker (compile failure unresolved after 3 rounds / missing dependency / escalate limit exceeded / user pause).
2. MUST NOT let any artifact that failed the adversarial check flow downstream (unless, under `--auto`, auto_optimize + decide_best already resolved it).
3. MUST NOT modify CCG files (config.toml / prompts / commands); only invoke `run_skill.js` + `codeagent-wrapper`.
4. MUST NOT bypass the routing table to directly do a main tool's job (e.g. writing a code review yourself instead of calling `/review` or the adversarial gate).
5. MUST NOT retry indefinitely in auto_optimize — at most 3 rounds; on exceeding, escalate (`--auto` still tries decide_best; only a Hard Blocker stops).
6. MUST NOT skip Gate 5 (loop-vs-GSD state consistency check) — before advancing execute, read GSD's STATE.md to align.
7. MUST NOT add `--force` yourself — it must be explicitly passed by the user.

<!-- 中文译注：MUST NOT 摘要——--auto 不因"需人工"停；对抗未过不进下游；不改 CCG 文件；不绕路由表自己做主工具的活；auto_optimize 不无限重试（≤3轮）；不跳 Gate 5；不自加 --force。 -->
</inline_iron_rules>

<inline_command_reference>
Command quick-reference. **Note on triggering**: on Claude Code/ZCode these are slash commands (`/loop:*`). On Gemini CLI they are invoked by **natural language** (e.g. "run loop-engineering with --status"); on Codebuddy the trigger mechanism is still being explored. In all cases the agent parses the equivalent of `$ARGUMENTS` to determine mode.

| Command | Mode | What it does |
|---------|------|--------------|
| `/loop:init [name] [--reference <url\|repo>]` | init | Create `.loop/` + STATE.yaml (7-Phase template) + empty learnings/gaps/timeline + adversarial/. Set phase=1, step=ideate, iteration=1. With `--reference`, store reference_target for Route 3.4. Ask whether to run `/office-hours`. |
| `/loop:refine <text>` | refine | Cross-cutting prompt optimizer. One-sentence req → 8-dimension analysis → 3-6 plain-text follow-up questions → always generate three sets (standard/compact/advanced strict) → display all three → user replies 1/2/3 → write `.loop/refined-prompt.md`. Does NOT advance the loop. |
| `/loop:status` | status | Read-only dashboard: current Phase/step, iteration, artifact status, blockers, adversarial status, suggested next command. Does NOT modify state. |
| `/loop:run [--next] [--auto\|--interactive\|--force]` | next | Advance one stage. Default `--auto`. On this adapter `--auto` runs ONE stage then stops (re-trigger manually); `--interactive` stops on any decision/gate. |
| `/loop:adversarial [step] [--debate\|--deterministic-only]` | adversarial | Manually trigger an adversarial check (step defaults to current_step). `--deterministic-only` skips multi-model (already the default behavior on this adapter). |
| `/loop:retro` | retro | Iteration close loop: retro → lessons → audit → seed → next round (delegated logic inlined in `<process>`). |
| `/loop:run --phase N` | phase | Jump to Phase N (after safety_gates confirm prior artifacts). |
| `/loop:run --from N` | from | Resume from Phase N (skip completed stages). |

When there is no `.loop/`: prompt the user to run `/loop:init [project name]`.

<!-- 中文译注：命令速查——init/refine/status/run(adversarial,phase,from,retro)。Gemini 用自然语言触发，Codebuddy 待探索；agent 解析 $ARGUMENTS 决定模式。无 .loop/ 时提示 init。 -->
</inline_command_reference>

<inline_seven_phases>
The 7-Phase closed loop. Each phase has a primary tool family; the loop routes by current_phase + current_step.

| Phase | Name | Primary tool | What happens |
|-------|------|--------------|--------------|
| 1 | Ideation | gstack `/office-hours` | 6 questions dig into the product idea (CEO perspective). Output → `.loop/ideation.md`. First iteration: run `teach-impeccable` to capture design context. |
| 2 | Spec → Design → Front-end | OpenSpec + gstack triple review + impeccable design toolkit | `/opsx:propose` writes specs (check for front-end UI spec). Triple review (`/plan-ceo-review` → `/plan-eng-review` → `/plan-design-review`). Front-end lifecycle: replicate (3.4) → design system (3.5) → variants+code+polish (3.6). |
| 3 | Discuss → Plan → Execute | GSD | `/gsd-discuss-phase` captures gray areas → `/gsd-plan-phase` builds PLAN.md (check for front-end business-page plans) → execute **plan-by-plan** with adversarial gate after each plan. |
| 4 | Review → QA → Verify | gstack `/review` + `/cso` + `/qa` + GSD `/gsd-verify-work` | Production code review + OWASP/STRIDE security scan → real-browser QA → conversational UAT. |
| 5 | Ship | gstack `/ship` → `/canary` → `/land-and-deploy` | Ship pipeline. Verify frontend accessible after deploy. Output → `.loop/ship-log.md`. |
| 6 | Complete | `/gsd-complete-milestone` + retro | Archive + tag → retro → lessons → next round (iteration+1). |
| (7) | (macro-loop seam) | loop-iterate | On `--auto` (native): auto-enter next round until all milestones done. On this adapter: stops after each round; user re-triggers. |

<!-- 中文译注：7-Phase 闭环摘要——Phase1 构想(gstack)/Phase2 规格+设计+前端(OpenSpec+三重审核+impeccable)/Phase3 讨论+规划+执行(GSD 逐 plan)/Phase4 审查+QA+验收(gstack+GSD)/Phase5 发布(gstack)/Phase6 完成(归档+retro)。 -->
</inline_seven_phases>

<inline_safety_gates>
Four safety gates checked **in order** before advancing (without `--force`, stop on hitting any gate). Plus Gate 5 (loop-vs-GSD consistency) before execute.

| Gate | Check | On stop |
|------|-------|---------|
| Gate 1 | STATE.yaml `current-phase` blockers array is non-empty | List blockers; prompt to delete the entry after resolving |
| Gate 2 | Previous phase's artifacts actually exist on disk | List missing-artifact paths |
| Gate 3 | When Phase 4→5, `qa-report.md` contains no FAIL/severe | Prompt to fix first |
| Gate 4 | `.loop/adversarial/last-verdict.json` `passed=true` | Prompt to view last-verdict.json or run `/loop:adversarial` |
| Gate 5 | Before advancing execute: GSD STATE.md consistent with loop state | Read GSD STATE.md and align |

**`--force`**: prints `⚠ --force: skipping safety gates`, skips all gates, advances directly. The agent MUST NOT add `--force` itself.

**`--auto` behavior on this adapter**: attempts auto-resolution when a gate is hit (e.g. run the missing artifact's tool), then re-checks. `--interactive`: stops and asks a human.

<!-- 中文译注：4 道安全门 + Gate 5——推进前顺序检查，无 --force 遇门即停；Gate1 blockers 非空；Gate2 上一阶段产物存在；Gate3 Phase4→5 qa-report 无 FAIL/严重；Gate4 last-verdict passed=true；Gate5 execute 前与 GSD STATE 一致；--force 跳过所有门（agent 不得自加）。 -->
</inline_safety_gates>

<inline_adversarial_gate>
**Adversarial quality gate** — runs after any stage that produces output (spec/design/plan/execute/review/ship). execute is plan-level.

**How it works (canonical):** a deterministic gate (lint/test/structure checks) + multi-model debate (codex + gemini analyze the output) + front-end check. Verdict handling:
- **passed=true** → allow through.
- **Deterministic gate fail / multi-model consensus fail** → `auto_optimize` (synthesize findings → apply specific fixes → re-check; ≤3 rounds).
- **Multi-model disagreement** → `debate` (complementary → adopt both; contradictory → take conservative + arbitrate via deterministic gate). Record to `.loop/adversarial/debates/{ts}.md`.
- **auto_optimize exhausted** → `escalate` (set blocker, stop, wait for user).

The gate runs via script (do NOT re-implement the check logic yourself):
```bash
~/.claude/skills/loop-engineering/scripts/loop-adversarial.sh full "$STEP" "$TARGET_PATH" "$GIT_REF"
```

**⚠ Degradation on this adapter:** the multi-model debate part is unavailable (this runtime is a single model). The adversarial gate degrades to **deterministic-gates-only + single-model self-review**:
- Run the deterministic gate as normal.
- Replace the two-model debate with a single-model self-critique pass (the same model reviews its own output critically and lists issues).
- auto_optimize (≤3 rounds) and escalate behave as normal.
- `--deterministic-only` is effectively the default on this runtime.

Manually trigger anytime via `/loop:adversarial [step]`. Supports `--debate` (force-record viewpoints) and `--deterministic-only`.

<!-- 中文译注：对抗门——有产出环节跑（确定性门+多模型辩论+前端检查），通过放行，未通过 auto_optimize(≤3轮)→escalate。本端多模型辩论降级为单模型自审；确定性门+auto_optimize 正常；--deterministic-only 是本端默认。 -->
</inline_adversarial_gate>

<inline_routes>
**Routing table (11 routes, in documented flow order).** Match by current_phase + current_step. Each stage uses exactly one tool family ("unique adjudication per stage" — do not run two in parallel). The adversarial-check layer (CCG) coexists with the main tool and does not conflict (main tool "produces", CCG "reviews").

| Route | Phase/step | Next command | Note |
|-------|-----------|--------------|------|
| 1. Ideation | P1 / ideate | `/office-hours` | gstack 6 questions. → `.loop/ideation.md`, step→spec. First iter: run `teach-impeccable`. |
| 2. Spec | P2 / spec | `/opsx:propose "<feature>"` | OpenSpec writes spec (SDD). Check for front-end UI spec; add if missing. step→design. |
| 3. Triple review | P2 / design | `/plan-ceo-review` → `/plan-eng-review` → `/plan-design-review` | Collect 3 conclusions. `--auto`: auto-adjudicate disagreement & continue. → `.loop/design-reviews.md`, step→replicate (if reference) or design-consult. |
| 3.4 Replicate | P2 / replicate | inline execute replicate-workflow (7-step reverse engineering) | Only when `reference_target` non-empty. Skip if no reference. step→design-consult. |
| 3.5 Design system | P2 / design-consult | `teach-impeccable` → `ui-ux-pro-max` → `design-taste-frontend` → `/design-consultation` | Front-end design decisions → DESIGN.md. step→design-ui. |
| 3.6 Variants + code + polish | P2 / design-ui | `/design-shotgun` → `/design-html` → impeccable sub-skills (polish/arrange/typeset/colorize/animate/critique…) | Vue3 production code + quality polish. step→discuss, phase→3. |
| 4. Discuss | P3 / discuss | ensure `/gsd:new-project`, then `/gsd-discuss-phase <N>` | Capture gray areas. `--auto`: decide_best auto-picks. step→plan. |
| 5. Plan | P3 / plan | `/gsd-plan-phase <N>` | PLAN.md from ROADMAP. Check for front-end business-page plans. step→execute. |
| 5.5 Deploy orchestration | P3 / deploy | auto-fix deploy config (remove profiles hiding, add `make deploy`), then `/gsd-plan-phase` | Ensure full-stack deploy works. step→plan. |
| 6. Execute (plan-by-plan) | P3 / execute | loop drives gsd-executor one plan at a time + plan-level adversarial gate | NOT `/gsd-execute-phase` all-at-once. Front-end plans also plan-by-plan (+ `/design-review` + impeccable/polish). step→review, phase→4. |
| 7. Code review | P4 / review | `/review` + `/cso` | gstack review (stronger) + OWASP/STRIDE. → `.loop/reviews.md`, step→qa. |
| 8. Browser QA | P4 / qa | `/qa <staging-url>` (or `/qa-only`) | Real browser. Verify frontend deployed first; auto-fix if hidden. → `.loop/qa-report.md`, step→verify. |
| 9. UAT | P4 / verify | `/gsd-verify-work <N>` | GSD acceptance. `--auto`: auto-judge by acceptance_criteria. step→ship, phase→5. |
| 11. Ship | P5 / ship | `/ship` → `/canary` → `/land-and-deploy` | gstack. Verify frontend accessible (curl 200 + index.html). → `.loop/ship-log.md`, step→complete, phase→6. |
| 12. Close loop | P6 / complete | `/gsd-complete-milestone` then retro | Archive + tag → retro → lessons → next round. `--auto` (native): auto-enter next iteration. |

**Unique adjudication per stage**: Planning → gstack review + OpenSpec (NOT GSD planning); Execution → GSD (NOT gstack autoplan); Review → gstack `/review` (NOT GSD code-review); Ship → gstack ship/canary/deploy; QA → gstack `/qa` (NOT static analysis); Security → gstack `/cso`.

<!-- 中文译注：11 路由表——按 phase+step 匹配，每阶段唯一裁决（不并行两套），对抗层与主工具并存。Route1 构想/2 规格/3 三重审核/3.4 复刻/3.5 设计系统/3.6 变体+代码+打磨/4 讨论/5 规划/5.5 部署编排/6 逐 plan 执行/7 代码审查/8 浏览器 QA/9 UAT/11 发布/12 闭环。 -->
</inline_routes>

<process>
Arguments provided: "$ARGUMENTS"

Parse the first token to determine mode. **All modes use inline execution on this adapter** (no SlashCommand self-loop). After each step completes, STOP and tell the user the next command to re-trigger.

<!-- 中文译注：解析 $ARGUMENTS 决定模式；本端所有模式都是 inline 单步执行，每步完成后停下并告知用户下一步命令。 -->

**`--init <name> [--reference <url|repo>]`** → perform initialization:
1. If `.loop/STATE.yaml` exists, ask whether to overwrite (default no, to preserve history).
2. Create `.loop/` directory + STATE.yaml (7-Phase template: phase_status, artifacts, history, blockers) + empty `learnings.yaml`, `gaps.yaml`, `timeline.jsonl` + `adversarial/` dir.
3. Set `current_phase: 1, current_step: ideate, iteration: 1`.
4. If `--reference <url|repo>`: write reference_target into STATE.yaml (git URL / local path / live URL) → Route 3.4 will trigger later.
5. Ask (plain-text): "是否立即运行 /office-hours 进入构想？(y/n)".
<!-- 中文译注：--init 初始化——建 .loop/+STATE.yaml（7-Phase 模板）+空资产文件；带 --reference 写 reference_target；用纯文本问是否立即 /office-hours。 -->

**`--refine <text>`** → perform prompt specialization/refinement:
1. Receive one-sentence requirement (`<text>`), deeply analyze missing/ambiguous points across 8 dimensions (target users / core scenarios / tech stack / scale & performance / auth & security / priority MVP / existing-code constraints / acceptance criteria).
2. Emit **plain-text follow-up questions** (3-6, targeting uncovered dimensions), e.g. "请回答以下问题：1.… 2.… 3.…". Wait for the reply.
3. After synthesizing answers, **always generate three sets**: standard (daily use) / compact (iterative dialogue) / advanced strict (AI Agent hardened).
4. **First fully display all three prompts in the conversation** (each set's full text as a code block — the user must read every line), **then** print "请回复 1 / 2 / 3 选择一套：". The agent MUST NOT choose for the user; MUST NOT skip the full display.
5. Write to `.loop/refined-prompt.md` (original prompt / follow-up Q&A / three full prompts / selected version).
6. Suggest next step: `/office-hours` (carrying the refined prompt) or `/loop:run --next`. **Do NOT auto-invoke; do NOT advance the closed loop.**
<!-- 中文译注：--refine——一句话需求→8 维度分析→纯文本追问 3-6 个→总是三套→全文展示→"请回复 1/2/3"→写 refined-prompt.md；不自动调用、不推进闭环。 -->

**`--status`** (or no arguments) → read-only dashboard:
1. Read `.loop/STATE.yaml`.
2. Output: current Phase/step, iteration count, progress bar, each Phase's artifact status, blockers, adversarial status (read `last-verdict.json`), historical-loop summary, suggested next-step command.
3. Do NOT modify any state.
<!-- 中文译注：--status 只读看板——读 STATE.yaml 输出当前 Phase/步骤/迭代/进度/各阶段产物/blocker/对抗状态/历史摘要/下一步建议；不修改。 -->

**`--retro`** → iteration close loop:
1. retro: review the iteration (what went well / wrong / to improve).
2. lessons: extract learnings → `.loop/learnings.yaml`; gaps → `.loop/gaps.yaml`.
3. audit: check which milestones remain.
4. seed: prepare next round's seed (next_seed).
5. close loop: iteration+1, or stop if all milestones done. Append to timeline.jsonl.
<!-- 中文译注：--retro 迭代回环——retro→教训(learnings/gaps)→审计剩余里程碑→种子→闭环(iteration+1)。 -->

**`--next [--auto|--interactive|--force]`** → advance ONE stage (default `--auto`):
1. read_state: re-read `.loop/STATE.yaml` (no cache — previous step may have changed it).
2. safety_gates: run Gates 1-4 (+ Gate 5 before execute). `--auto`: attempt auto-resolution; `--force`: skip all; `--interactive`: stop on hit.
3. determine_next_action: match current_phase + current_step against the routing table (`<inline_routes>`).
4. show_and_execute: display the verdict, then **inline-execute** the main tool (the loop itself reads the target skill's instructions and performs the actions using Read/Write/Edit/Bash/Grep/Glob within this session). On this adapter this is ONE stage.
5. adversarial_gate: if the step is within gate coverage (spec/design/plan/execute/review/ship), run the adversarial check (deterministic gate + single-model self-critique on this adapter). Pass → continue; fail → auto_optimize (≤3 rounds) → escalate.
6. advance_loop: update step/phase in STATE.yaml (atomic) + append timeline.jsonl.
7. **STOP on this adapter** — print the next command for the user to re-trigger:
   ```
   ✅ 本 step 完成（Phase {N} / step {current_step}）。
   ▶ 下一步请手动触发：/loop:run --next {auto|interactive}
   ```
   Only the native Claude Code/ZCode version continues automatically; here the user drives each step.

**Decision points** (`--auto`): invoke decide_best — small decisions (naming/params/impl detail/non-critical lib) auto-selected from spec/context; large decisions (architecture/scope/key dependency/data model/security/tech stack) recorded with a note that multi-model debate is unavailable on this runtime and resolved by single-model judgment. All decisions → `.loop/decisions.jsonl`.

**Hard Blocker stop** (the only true stop in `--auto`): compile failure unresolved after 3 rounds / critical dependency missing / escalate limit exceeded / user pause. Display:
```
⛔ 遇到硬障碍：{reason}
1. 查看详情：cat .loop/adversarial/last-verdict.json
2. 查看自动决策：cat .loop/decisions.jsonl
3. 手动修复后：/loop:run --next --auto 继续
或切保守模式：/loop:run --next --interactive
```
<!-- 中文译注：--next 推进一个环节——读状态→安全门→路由匹配→inline 执行主工具→对抗门→前进→本端停下告知用户下一步。决策点走 decide_best（小自主/大单模型判定+记 jsonl）。硬障碍才真停。 -->

**`--adversarial [step]`** → manually trigger adversarial check:
1. step defaults to STATE.yaml's current_step if omitted.
2. Run gate (deterministic + single-model self-critique) → evaluate → auto_optimize/debate(degraded)/escalate.
3. Supports `--debate` and `--deterministic-only`.
<!-- 中文译注：--adversarial 手动触发——step 缺省取 current_step，跑门→评估→auto_optimize/escalate。 -->

**`--phase N`** → jump to Phase N (first pass safety_gates, confirm prior artifacts complete).

**`--from N`** → resume from Phase N (skip completed stages).

**When there is no `.loop/`**: prompt the user to run `/loop:init [project name]`.

Preserve all routing/gate logic from `<inline_routes>` and `<inline_safety_gates>`. Do not invent new routing rules.
<!-- 中文译注：无 .loop/ 时提示 init；保留路由/门逻辑，不发明新规则。 -->
</process>

<deployment_note>
**Deployment location:** this adapter deploys to `~/.agents/skills/loop-engineering/` (shared by Gemini CLI and Codebuddy). Both runtimes read skills from `~/.agents/skills/`. Codebuddy's `allowed-tools` (comma-separated string) is honored; Gemini ignores `allowed-tools` without error.

**This is a degraded version.** The canonical, full-capability Loop Engineering skill lives at the repository root `SKILL.md` and runs natively on Claude Code / ZCode. On this adapter:
- `--auto` is single-step (no self-loop); the user re-triggers each stage.
- Interactive questions are plain-text (no structured AskUserQuestion).
- Multi-model adversarial debate degrades to single-model self-critique.
- AGENTS.md + 6 workflows are inlined as summaries (no `@include`).

**For the full, uninterrupted closed loop (single command runs the whole project, multi-model adversarial, structured Q&A), use Claude Code or ZCode with the canonical root `SKILL.md`.**

<!-- 中文译注：部署位置——~/.agents/skills/loop-engineering/（Gemini+Codebuddy 共享）。这是降级版：--auto 单步、纯文本问答、多模型降级单模型、AGENTS.md+workflow 摘要内联。完整闭环请用 Claude Code/ZCode 的根 SKILL.md。 -->
</deployment_note>
