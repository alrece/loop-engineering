# AGENTS.md — Loop Engineering AI Agent Behavior Spec

> This document guides the AI agent on how to use the Loop Engineering skill **according to spec**.
> The agent MUST read this file and obey its behavioral constraints before executing any `/loop:*` command.
<!-- 中文译注：本文档指导 AI agent 如何按规范使用 Loop Engineering skill；执行任何 /loop:* 命令前必须先读本文件并遵守约束。 -->

---

## 0. Iron Rules (MUST / MUST NOT)

### MUST
1. **Read SKILL.md and the 4 workflows it @ includes** (loop-state/orchestrate/iterate/adversarial) before performing any action. NEVER fabricate routing rules from memory.
   <!-- 中文译注：铁律 1——先读 SKILL.md + 4 个 workflow 再执行，绝不凭记忆编造路由规则。 -->
2. **Treat `.loop/STATE.yaml` as the single source of truth**. All state judgments (current Phase, step, blocker) MUST be read from here; do not guess.
   <!-- 中文译注：铁律 2——以 .loop/STATE.yaml 为单一事实源，所有状态判定都从这里读，不臆测。 -->
3. **In --auto mode (default), at decision points auto-select the best option and continue** (small decisions auto-selected, large decisions invoke decide-large multi-model discussion); only a Hard Blocker stops it. **In --interactive mode**, on hitting a decision/safety gate it stops and asks a human.
   <!-- 中文译注：铁律 3——--auto 模式遇决策点自动选最佳方案后继续（小自主/大多模型），只有硬障碍才停；--interactive 撞决策/安全门即停问人。 -->
4. **Stages that produce output (spec/design/plan/execute/review/ship) MUST run adversarial_gate after producing**. execute is plan-level (checked plan-by-plan).
   <!-- 中文译注：铁律 4——有产出的环节产出后必跑 adversarial_gate，execute 是 plan 级（逐 plan 检查）。 -->
5. **Orchestrate by invoking existing tools**; do not rebuild gstack/GSD/OpenSpec/CCG capabilities. The routing table lives in loop-orchestrate.md; do not invent new routes.
   <!-- 中文译注：铁律 5——编排调现有工具，不重造 gstack/GSD/OpenSpec/CCG 能力；路由表在 loop-orchestrate.md，不发明新路由。 -->
6. **Route 6 (execute) MUST use plan-by-plan mode**: drive the gsd-executor subagent to run one plan at a time, running a plan-level adversarial gate after each completes; no longer call /gsd-execute-phase to run everything at once.
   <!-- 中文译注：铁律 6——Route 6(execute) 走逐 plan 模式，逐 plan 驱动 gsd-executor，每个完成后跑 plan 级对抗门，不一次性跑完。 -->
7. **All automatic decisions MUST be recorded to `.loop/decisions.jsonl`** for the user to review during final verification.
   <!-- 中文译注：铁律 7——所有自动决策记录到 .loop/decisions.jsonl，供用户最后验证时审查。 -->
8. **Output in the same language as the user's input prompt** (follow the user's language; code/commands/paths/proper nouns excepted).
   <!-- 中文译注：铁律 8——跟随用户输入语言输出（原中文版曾是"用中文输出"，现改为跟随用户语言，遵循全局 AGENTS.md/CLAUDE.md 语言规则），代码/命令/路径/专有名词除外。 -->
9. **State changes MUST be written back to STATE.yaml (atomic write) + appended to timeline.jsonl**, ensuring auditability and recoverability.
   <!-- 中文译注：铁律 9——状态变更写回 STATE.yaml（原子写）+ 追加 timeline.jsonl，保证可审计可恢复。 -->
10. **The front-end lifecycle MUST be complete + a full design toolkit** (v4.2): Route 3.4 (reference project replication — when a reference_target exists, run the 7-step reverse engineering) → Route 3.5 (teach-impeccable collects context + ui-ux-pro-max design decisions + design-taste-frontend guards against cookie-cutter AI + /design-consultation competitor reference) → Route 3.6 (/design-shotgun variants + /design-html Vue3 code + **impeccable 21 sub-skills for quality polish**) MUST NOT be skipped (Route 3.4 may be skipped when there is no reference). Front-end output MUST go through impeccable quality polish (at least critique + polish); delivering merely "it works" is not acceptable. The spec MUST contain a front-end UI spec, the plan MUST contain front-end business-page plans, and the deployment MUST include the frontend and MUST NOT be hidden by profiles.
    <!-- 中文译注：铁律 10——前端生命周期必须完整+设计能力全家桶：Route 3.4 复刻→Route 3.5 设计决策→Route 3.6 变体+Vue3+impeccable 21 子 skill 品质打磨，不可跳过（Route 3.4 无参考时可跳过）；前端产出必须经 impeccable 打磨（至少 critique+polish），不能只"能用"；spec 含前端 UI spec，plan 含前端业务页面，部署含 frontend 且不被 profiles 隐藏。 -->
11. **`/loop:refine` MUST always generate three sets of prompts and MUST let the user choose; it MUST NOT choose for the user** (v4.3): receive a one-sentence requirement → 8-dimension deep analysis of missing points → use AskUserQuestion to dynamically ask 3-6 follow-up questions once → **always** produce three sets (standard/compact/advanced strict) → **first fully display all three prompts in the conversation (each set's full text rendered so the user can read every line), then** use AskUserQuestion to let the user choose one → write to `.loop/refined-prompt.md`. The agent MUST NOT decide the version on its own, MUST NOT guess missing dimensions (if missing, ask), MUST NOT skip the follow-up step, and MUST NOT skip the full display to jump directly to the selection (the user MUST be able to read the complete content of all three before choosing).
    <!-- 中文译注：铁律 11——/loop:refine 总是生成三套提示词，必须让用户选，不得替选（v4.3）：一句话需求→8 维度分析→AskUserQuestion 一次追问 3-6 个→总是产出三套→【先在对话里完整展示三套（每套全文渲染出来用户能逐行读完）再用 AskUserQuestion 让用户选】→写 refined-prompt.md；不擅自定版、不臆测缺失维度、不跳过追问、不跳过完整展示直接弹选择框（用户必须能在选择前读到三套完整内容）。 -->

### MUST NOT
1. **MUST NOT stop in --auto mode because it "needs a human decision"** — that is --interactive behavior. --auto stops only on a Hard Blocker (compile failure unresolved after 3 rounds / missing dependency / escalate limit exceeded / user pause).
   <!-- 中文译注：MUST NOT 1——不得在 --auto 模式下因"需要人工决策"而停（那是 --interactive 的行为），--auto 只因硬障碍停。 -->
2. **MUST NOT let any artifact that failed the adversarial check flow into downstream stages** (unless, under --auto, auto_optimize + decide_best has already resolved it).
   <!-- 中文译注：MUST NOT 2——不得让对抗检查未通过的产物进入下游环节（除非 --auto 下 auto_optimize+decide_best 已自动解决）。 -->
3. **MUST NOT modify any CCG files** (config.toml / prompts / commands); only invoke run_skill.js + codeagent-wrapper.
   <!-- 中文译注：MUST NOT 3——不得修改 CCG 任何文件（config.toml/prompts/命令），只调用 run_skill.js + codeagent-wrapper。 -->
4. **MUST NOT bypass the routing table to directly do a main tool's job** (e.g. writing a code review yourself instead of calling `/review` or the adversarial gate).
   <!-- 中文译注：MUST NOT 4——不得绕过路由表直接做主工具的活（如自己写代码审查，而应调 /review 或对抗门）。 -->
5. **MUST NOT retry indefinitely inside auto_optimize**. At most 3 rounds; on exceeding the limit, go to decide_best (--auto) or escalate (--interactive).
   <!-- 中文译注：MUST NOT 5——不得在 auto_optimize 里无限重试，最多 3 轮，超限走 decide_best（--auto）或 escalate（--interactive）。 -->
6. **MUST NOT use SlashCommand self-invocation to implement the --auto loop** (v3.1 core change) — SlashCommand breaks across sessions, causing every stage to interrupt. --auto MUST use the **run_full_loop while-loop + inline execution** (the loop itself Reads the target skill's SKILL.md + workflow and executes per the instructions within the main session; the session does not break). Do NOT use Skill() (ZCode has no such tool); do NOT use Agent subagents (Explore is read-only). Only --interactive uses SlashCommand.
   <!-- 中文译注：MUST NOT 6——不得用 SlashCommand 自调用实现 --auto 循环（v3.1 核心）——SlashCommand 跨会话断链导致每环节中断；--auto 必须用 run_full_loop 的 while 循环+inline 执行（loop 自己 Read skill 指令+主会话执行，会话不断）；不用 Skill()（ZCode 无此工具）、不用 Agent 子代理（Explore 只读）；--interactive 才用 SlashCommand。 -->
7. **MUST NOT skip Gate 5 (the loop-vs-GSD state consistency check)** — before advancing execute, you MUST read GSD's STATE.md to align.
   <!-- 中文译注：MUST NOT 7——不得跳过 Gate 5（loop 与 GSD 状态一致性校验），execute 推进前必读 GSD STATE.md 对齐。 -->

---

## 1. Command Execution Spec

### `/loop:init [project name]`
1. Check whether `.loop/STATE.yaml` already exists — if it does, ask whether to overwrite (default no overwrite, to prevent losing history).
2. Create the `.loop/` directory + STATE.yaml (7-Phase template) + learnings.yaml/gaps.yaml/timeline.jsonl (empty) + adversarial/ (empty).
3. Initialize STATE.yaml: `current_phase: 1, current_step: ideate, iteration: 1`.
4. Ask whether to immediately call `/office-hours` to enter Ideation.
<!-- 中文译注：/loop:init——存在则问是否覆盖（默认不覆盖防丢历史），建 .loop/ + STATE.yaml（7-Phase 模板）+空资产文件；初始化 phase=1/step=ideate/iteration=1；问是否立即 /office-hours 进入构想。 -->

### `/loop:refine <prompt>` (new in v4.3)
Prompt specialization/refinement optimizer; a cross-cutting tool (does not depend on init, does not advance the closed loop). Fully delegated to the loop-refine.md workflow:
1. Receive the user's one-sentence requirement (`$ARGUMENTS`), and deeply analyze it across 8 dimensions (target users / core scenarios / tech stack / scale & performance / auth & security / priority MVP / existing-code constraints / acceptance criteria).
2. Based on the analysis, **dynamically generate 3-6 follow-up questions** (targeting missing/ambiguous dimensions), and ask them in parallel once via AskUserQuestion.
3. After synthesizing the answers, **always produce three sets**: standard (daily use, clear hierarchy) / compact (iterative dialogue, tight) / advanced strict (AI Agent hardened: mandatory file reads + auth protection + existing-logic protection + enforced quality gates).
4. **First fully display all three prompts in the conversation** (each set's full text rendered as a code block, the user must be able to read every line before choosing), **then** use AskUserQuestion to let the user choose one set — **the agent does not choose for the user; the user must not choose blind**.
5. Write to `.loop/refined-prompt.md` (contains the original prompt / follow-up Q&A / the three full prompts / the selected version).
6. Suggest the next step: `/office-hours` (carrying the refined prompt) or `/loop:run --next`. **Do NOT auto-invoke.**
<!-- 中文译注：/loop:refine——提示词专业化优化器（横切工具，不依赖 init、不推进闭环）：一句话需求→8 维度分析→动态追问 3-6 个→总是产出三套（标准/精简/高阶强约束）→让用户选→写 refined-prompt.md；不替选、不自动调用。 -->

### `/loop:status`
1. Read STATE.yaml.
2. Render the dashboard: current Phase/step, progress bar, each Phase's status, blockers, adversarial-check status (read last-verdict.json), historical-loop summary, and suggested next-step command.
3. **Read-only; do NOT modify any state.**
<!-- 中文译注：/loop:status——读 STATE.yaml 渲染看板（Phase/step/进度/各阶段状态/blocker/对抗状态/历史摘要/下一步建议），只读不修改。 -->

### `/loop:run [--next] [--auto]`
Execution order (strictly follow this):
1. **read_state**: read STATE.yaml; if absent, prompt `/loop:init`.
2. **safety_gates**: run Gates 1-4 (stop and exit on hitting a gate, unless `--force`).
3. **determine_next_action**: match the next-step command per the 11 routes in loop-orchestrate.md.
4. **show_and_execute**: display the verdict → invoke the main-tool command via SlashCommand.
5. **adversarial_gate**: after the main tool produces output, if the current step is within the gate_config coverage, run the adversarial check (see Section 3).
6. **auto_chain**: if `--auto` is set and the adversarial gate passed, SlashCommand self-invokes `/loop:run --next --auto`.
<!-- 中文译注：/loop:run 执行顺序——read_state→safety_gates(Gate 1-4)→determine_next_action(11 路由匹配)→show_and_execute(SlashCommand 调主工具)→adversarial_gate→auto_chain（--auto 通过则自调用）。 -->

**`--phase N` / `--from N`**: first pass safety_gates, confirm artifacts are complete, then switch phase.
<!-- 中文译注：--phase N / --from N——先过 safety_gates，确认产物完整，再切换 phase。 -->

### `/loop:adversarial [step]`
1. step defaults to STATE.yaml's current_step if omitted.
2. Fully delegated to loop-adversarial.md's run_gate → evaluate → auto_optimize/debate/escalate.
3. Supports `--debate` (force-record both models' viewpoints) and `--deterministic-only` (deterministic gates only).
<!-- 中文译注：/loop:adversarial——step 缺省取 current_step，交给 loop-adversarial.md；支持 --debate、--deterministic-only。 -->

### `/loop:retro`
Fully delegated to loop-iterate.md (retro → lessons → audit → seed → close loop).
<!-- 中文译注：/loop:retro——交给 loop-iterate.md（retro→教训→审计→种子→闭环）。 -->

---

## 2. Routing Execution Spec (11 routes)

**Unique adjudication per stage** — each stage uses exactly one tool family; do not run two in parallel:

| Stage | Who to use | Who NOT to use |
|------|------------|----------------|
| Planning | gstack business review + OpenSpec tech spec | NOT GSD planning |
| Execution | GSD execution engine | NOT gstack autoplan |
| Review | gstack /review (stronger) | NOT GSD code-review |
| Ship | gstack ship/canary/deploy | NOT others |

<!-- 中文译注：按阶段唯一裁决——规划用 gstack 商业审核+OpenSpec 技术规格（不用 GSD 规划）；执行用 GSD 执行引擎（不用 gstack autoplan）；审查用 gstack /review（更强）；发布用 gstack ship/canary/deploy。 -->

**The adversarial-check layer coexists with the main tool and does not conflict**: the main tool "produces", the CCG adversarial layer "reviews the output". Different responsibilities, complementary.
<!-- 中文译注：对抗检查层与主工具并存不冲突——主工具"产出"，CCG 对抗层"审查产出"，职责不同互补。 -->

When invoking a main tool, **use the SlashCommand tool** (do not execute its logic from memory). Display the verdict in the terminal before invoking.
<!-- 中文译注：调主工具用 SlashCommand 工具（不是凭记忆执行其逻辑），调用前在终端显示判定结果。 -->

---

## 3. Adversarial Quality Gate Execution Spec (Core)

### When to trigger
The current step is one of `spec/design/plan/execute/review/ship`, and the main tool has just produced output.
<!-- 中文译注：何时触发——当前 step 在 spec/design/plan/execute/review/ship 之一，且主工具刚产出内容。 -->

### How to execute
Invoke the script (do NOT re-implement the check logic yourself):
```bash
~/.claude/skills/loop-engineering/scripts/loop-adversarial.sh full "$STEP" "$TARGET_PATH" "$GIT_REF"
```
<!-- 中文译注：调用脚本而非自己重新实现检查逻辑。 -->

### Verdict handling (strictly per loop-adversarial.md)
- **passed=true** → update_state `--adversarial-passed true`, allow it through.
- **Deterministic gate fail / multi-model consensus fail** → enter auto_optimize.
- **Multi-model disagreement** (consensus=false) → enter debate.
<!-- 中文译注：判定处理——passed=true 放行；确定性门 fail/多模型共识 fail 进 auto_optimize；多模型分歧进 debate。 -->

### auto_optimize spec
1. Synthesize the deterministic-gate findings + both models' suggestions → an optimization list.
2. Give a specific fix for each issue (which line to change, what doc to add).
3. Auto-apply by issue type (Edit for code, generate docs, fix specs).
4. Re-check (run run_gate once more).
5. **At most 3 rounds**. On pass, allow through; on still-fail, escalate.
6. escalate: update_state `--blocker "adversarial check failed: {reason}"`, display failure details + discussion-record path, **stop advancing and wait for the user to handle it**.
<!-- 中文译注：auto_optimize——综合 findings+建议→优化清单→具体修复→按类型应用→重检；最多 3 轮，通过放行，仍 fail 则 escalate（设 blocker，停推进等用户处理）。 -->

### debate spec
- **Complementary viewpoints** (codex finds backend issues, gemini finds frontend issues) → adopt both suggestions, synthesize a list, back to auto_optimize.
- **Contradictory conclusions** (one says PASS, the other FAIL for the same spot) → take the conservative one (fix when in doubt) + arbitrate via the deterministic gate.
- Generate `.loop/adversarial/debates/{ts}.md` for traceability.
<!-- 中文译注：debate——视角互补则两者建议都采纳合成清单回 auto_optimize；结论矛盾则取保守+确定性门仲裁；生成 debates/{ts}.md 供追溯。 -->

### Reliability corrections (must read)
- The exit code of verify-quality is **not trustworthy** (exceeding complexity only produces a warning and does not block) — the script already re-parses the JSON; the agent MUST NOT switch to using the exit code itself.
- verify-change **MUST use staged/committed mode** (working mode always reports 0 lines) — the script already handles this.
- Trust the script's JSON output; do not re-judge.
<!-- 中文译注：可靠性修正——verify-quality 的 exit code 不可信（脚本已二次解析 JSON，agent 不要自己改用 exit code）；verify-change 必须用 staged/committed 模式（脚本已处理）；信任脚本输出的 JSON，不要重新判定。 -->

---

## 4. Safety Gate Execution Spec (Gate 1-4)

Check **in order** before advancing; without `--force`, stop and exit on hitting any gate:

| Gate | Check | Prompt on stop |
|------|-------|----------------|
| Gate 1 | STATE.yaml's current-phase blockers array is non-empty | List blockers; prompt to delete the entry after resolving |
| Gate 2 | The previous phase's artifacts actually exist on disk | List missing-artifact paths |
| Gate 3 | When going Phase 4→5, qa-report.md contains no FAIL/severe | Prompt to fix first |
| Gate 4 | `.loop/adversarial/last-verdict.json` passed=true | Prompt to view last-verdict.json or `/loop:adversarial` |

<!-- 中文译注：安全门 Gate 1-4——推进前顺序检查，无 --force 遇门即停：Gate 1 blockers 非空；Gate 2 上一阶段产物磁盘存在；Gate 3 Phase4→5 的 qa-report 不含 FAIL/严重；Gate 4 last-verdict.json passed=true。 -->

**`--force` behavior**: prints `⚠ --force: skipping safety gates`, skipping all gates and advancing directly. **The agent MUST NOT add --force itself; it MUST be explicitly passed by the user.**
<!-- 中文译注：--force 打印跳过安全门警告，跳过所有门直接推进；agent 不得自行加 --force，必须用户显式传。 -->

---

## 5. State Read/Write Spec

### Read
- Each `/loop:run` execution **re-reads** STATE.yaml (do not use a cache, because the previous step may have changed it).
- The adversarial gate reads last-verdict.json.
<!-- 中文译注：读——每次 /loop:run 重新读 STATE.yaml（不用缓存，上一步可能改了它）；对抗门读 last-verdict.json。 -->

### Write (update_state)
- **Atomic write**: first write `.loop/STATE.yaml.tmp` then rename, to avoid a half-written state.
- **Preserve structure**: do not break existing fields (phase_status, artifacts, history).
- **Append to timeline.jsonl**: `{"ts","phase","step","event":"advance|block|complete|iterate","adversarial":"pass|fail|skip|none"}`.
<!-- 中文译注：写（update_state）——原子写（.tmp+rename），保留结构不破坏既有字段，追加 timeline.jsonl。 -->

### Supported update_state parameters
`--step` / `--phase` / `--blocker` / `--resolve-blocker` / `--artifact` / `--next-iteration` / `--adversarial-passed` / `--adversarial-report`
<!-- 中文译注：update_state 参数——step/phase/blocker/resolve-blocker/artifact/next-iteration/adversarial-passed/adversarial-report。 -->

---

## 6. Loop Primitive Spec

### `--auto` self-invocation
- Use the **SlashCommand tool** to execute `/loop:run --next --auto`, **NOT a recursive function call**.
- This way each loop independently reads STATE.yaml and can capture the previous step's modifications.
- Stop conditions: macro-loop complete / hit a blocker / error/paused state.
<!-- 中文译注：--auto 自调用——用 SlashCommand 工具执行 /loop:run --next --auto（非递归函数调用），每次循环独立读 STATE.yaml；停止条件：宏观循环完成/撞 blocker/error/paused。 -->

### Display on stop
```
⛔ Auto-chain stopped: {reason}

After resolving: /loop:run --next --auto to continue.
```
<!-- 中文译注：停止时显示原因 + 续跑命令。 -->

---

## 7. Error Handling Spec

- **Underlying tool not initialized** (e.g. OpenSpec not init'd in the project) → the routing rule prompts to initialize first; do not force advancement.
- **codeagent-wrapper unavailable** (backend not started) → the multi-model part of the adversarial gate degrades to deterministic-gates-only, and notify the user.
- **Script execution failure** (run_skill.js errors) → record to timeline.jsonl; do not block the main flow (the adversarial gate is a quality enhancement; a script error should not deadlock the closed loop).
- **STATE.yaml corrupted** → prompt `/loop:init`; do NOT attempt auto-repair (to prevent data loss).
<!-- 中文译注：错误处理——底层工具未初始化→路由提示先初始化不强行推进；codeagent-wrapper 不可用→多模型降级只跑确定性门并提示；脚本失败→记 timeline 不阻断主流程；STATE.yaml 损坏→提示 /loop:init 不自动修复防数据丢失。 -->

---

## 8. Output Spec

Follow the global AGENTS.md language rule:
- All user-facing output uses **the same language as the user's input prompt** (the original Chinese version required Simplified Chinese output).
- gstack's D<N>/ELI10/Recommendation/Completeness/Net format markers are mapped to the user's language per the global mapping table.
- Exceptions (keep as-is): code, commands, paths, function names, config keys, proper nouns (Redis/Kubernetes, etc.).
<!-- 中文译注：输出规范——跟随用户输入语言（原中文版要求简体中文输出）；gstack 的 D<N>/ELI10 等格式标记按全局映射表转语言；代码/命令/路径/函数名/配置 key/专有名词保持原文。 -->

Dashboard/progress display uses clear ASCII boxes + tables; avoid boilerplate English markdown filler.
<!-- 中文译注：看板/进度用清晰 ASCII 框+表格，不用英文 markdown 套话。 -->

---

## 9. Coexistence-with-Other-Tools Spec

- The user may continue to use `/gsd-*` `/review` and any other commands standalone; loop does not interfere.
- loop only intervenes when an explicit `/loop:*` is run.
- Do NOT modify GSD's `.planning/` (only read its artifacts to judge GSD progress).
- Do NOT modify gstack's `.gstack/` (only read review/qa artifacts).
<!-- 中文译注：与其他工具共存——用户可单独用 /gsd-* /review 等，loop 不干涉；loop 只在显式跑 /loop:* 时介入；不修改 GSD .planning/ 和 gstack .gstack/（只读产物）。 -->

---

## 10. Self-Check List (the agent reviews after each execution)

- [ ] Did you read SKILL.md + the 4 workflows first?
- [ ] Did you treat STATE.yaml as the source of truth (re-read, not guessed)?
- [ ] **--auto mode**: at decision points did you go through decide_best (small auto / large multi-model), and not stop because it "needs a human"?
- [ ] **--auto mode**: did you stop only on a Hard Blocker (compile 3 rounds ineffective / missing dependency / escalate limit / user pause)?
- [ ] **execute stage**: did you use plan-by-plan mode (gsd-executor single plan + plan-level adversarial gate), rather than a one-shot /gsd-execute-phase?
- [ ] Were automatic decisions recorded to .loop/decisions.jsonl?
- [ ] Before advancing execute, did you run Gate 5 (consistency check with GSD STATE.md)?
- [ ] Did stages that produce output run adversarial_gate?
- [ ] On adversarial failure did you go through auto_optimize (≤3 rounds) → decide_best (--auto) / escalate (--interactive)?
- [ ] Were state changes written back atomically to STATE.yaml + appended to timeline.jsonl?
- [ ] **Did --auto use the run_full_loop while-loop + inline execution** (the loop itself Reads skill instructions + executes in the main session, NOT SlashCommand/Skill/Agent, single continuous session)?
- [ ] Did you obey "unique adjudication per stage" (not running two tool sets in parallel)?
- [ ] Did you output in the user's language (code/paths excepted)?
- [ ] Did you not modify any CCG/GSD/gstack files, and not add --force yourself?
- [ ] **/loop:refine**: did you always generate three sets (standard/compact/advanced strict), **first fully display all three in the conversation (user can read every line)**, then use AskUserQuestion to let the user choose (not choose for them, not skip the full display)?
- [ ] **/loop:refine**: did you dynamically ask 3-6 questions about missing dimensions (not guess, not skip the follow-up)?
<!-- 中文译注：自检清单——先读 SKILL.md+4 workflow；STATE.yaml 为事实源（重读未臆测）；--auto 决策走 decide_best（小自主/大多模型）不因"需人工"停；--auto 只硬障碍才停；execute 逐 plan；决策记 jsonl；execute 前跑 Gate 5；有产出跑对抗门；未通过 auto_optimize(≤3轮)→decide_best/escalate；状态原子写+timeline；--auto 用 run_full_loop while+inline（非 SlashCommand/Skill/Agent）；按阶段唯一裁决；跟随用户语言输出；不改 CCG/GSD/gstack 文件不自加 --force；/loop:refine 总是三套让用户选、动态追问 3-6 个。 -->
