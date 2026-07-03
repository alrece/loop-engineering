<purpose>
The adversarial quality gate of Loop Engineering. After each stage of the closed loop produces output, it runs an adversarial closed loop of "check → suggest → auto-optimize → re-check → only proceed on pass" against the artifact,
improving the output quality of the loop.

<!-- 中文译注：对抗性质量门——每个环节产出后对产物做"检查→提建议→自动优化→重检→通过才进下一步"的对抗闭环，提高 loop 产出质量。 -->

Two check layers:
1. **Deterministic quality gate**: invokes loop-adversarial.sh → CCG verify-* scripts (security/quality/change/module); the machine judges pass/fail; fast and reliable.
2. **Multi-model adversarial review**: invokes loop-adversarial.sh → codeagent-wrapper to call codex+gemini in parallel (bypassing config.toml defects, direct connection); heterogeneous viewpoints catch blind spots.

<!-- 中文译注：两层检查——1.确定性质量门（调 loop-adversarial.sh→CCG verify-* 脚本，机器判 pass/fail 快且可靠）；2.多模型对抗审查（调 codeagent-wrapper 并行调 codex+gemini，绕过 config.toml 缺陷直连，异构视角捕捉盲点）。 -->

This is the landing of CCG's "adversarial check" capability inside the closed loop — CCG provides the checking capability, and loop orchestrates when to check and how to optimize and re-check after problems are found.
<!-- 中文译注：这是 CCG"对抗性检查"能力在闭环里的落地——CCG 负责提供检查能力，loop 负责编排何时检查、发现问题后如何优化重检。 -->
</purpose>

<required_reading>
@$HOME/.claude/get-shit-done/workflows/loop-state.md
</required_reading>

<gate_config>
The check-item config for each stage (consistent with loop-adversarial.sh's full mode):

| Stage (step) | Deterministic gate | Multi-model adversarial | Check target |
|--------------|--------------------|--------------------------|--------------|
| spec (specification) | verify-change(--mode staged) + **frontend(spec)** | codex/gemini analyzer | openspec/changes/ + **whether a front-end UI spec exists** (pages/components/interaction/visual reference) |
| design (design) | — (no deterministic gate) | codex/gemini review design-reviews.md | review conclusions |
| **design-consult** (front-end reference) | — | codex/gemini review DESIGN.md | **whether DESIGN.md is generated + whether it has competitor-reference sources** |
| **design-ui** (front-end design) | **frontend(design-ui)** + **build** | codex/gemini review front-end code | **whether design-html produced front-end code + whether it's Vue3 + whether there are business pages (not empty shells)** |
| **replicate** (reference replication) | — | codex/gemini review replication artifacts | **whether the 7-step reverse-engineering docs are complete** |
| plan (planning) | verify-module .planning/ + **frontend(plan)** | codex/gemini review PLAN.md | PLAN.md + **whether it contains front-end business-page plans (not just skeletons)** |
| execute (execution) | verify-security + verify-quality + **frontend(plan)** | codex/gemini reviewer review git diff | **plan-level** + front-end plan additionally runs `/design-review` (visual QA) |
| review (review) | verify-security + **frontend(ship)** | compare gstack /review with multi-model conclusions | review consistency |
| ship (pre-ship) | verify-security + verify-module + **frontend(ship)** + **build** | codex/gemini final review | full + **whether the frontend service is in compose and not hidden by profiles + has make deploy** |

<!-- 中文译注：gate_config 各环节检查项配置——表格列：环节(step)/确定性门/多模型对抗/检查对象。spec 跑 verify-change+frontend 查前端 UI spec；design 仅多模型审；design-consult 审 DESIGN.md 是否生成+竞品来源；design-ui 跑 frontend+build 查 Vue3+业务页面；replicate 审 7 步文档齐全；plan 跑 verify-module+frontend 查前端业务 plan；execute 跑 verify-security+verify-quality+frontend plan 级+前端额外 design-review；review 跑 verify-security+frontend ship 对比 gstack /review；ship 跑 verify-security+verify-module+frontend ship+build 查 frontend 在 compose 且不被 profiles 隐藏+有 make deploy。 -->

**The execute stage is a plan-level check** (v2 plan-by-plan mode): loop-orchestrate's execute_plan_by_plan, after finishing each plan, runs the quality gate against that plan's git-diff range (`git diff <plan-start-commit>..HEAD`), not the whole phase. The script's target_path accepts a plan's file range or commit range.

<!-- 中文译注：execute 是 plan 级检查（v2 逐 plan 模式）——execute_plan_by_plan 每跑完一个 plan，对该 plan 的 git diff 范围跑质量门（而非整个 phase）；脚本 target_path 接受 plan 文件范围或 commit 范围。 -->

**v4.2 adds desktop full-chain support**:
- detect_app_type: detects electron/tauri/wails/flutter/web.
- verify_frontend: front-end checks for the spec/design-ui/ship stages.
- verify_build: executes the build command matching the app type (npm/run build/tauri build/wails build/flutter build).

<!-- 中文译注：v4.2 新增桌面端全链路支持——detect_app_type 检测 electron/tauri/wails/flutter/web；verify_frontend 在 spec/design-ui/ship 三环节跑前端检查；verify_build 根据应用类型执行对应构建命令。 -->

Stages NOT checked: ideate (ideation, no code), discuss (discussion, no artifact), qa (browser testing is handled by gstack /qa), verify (UAT is handled by GSD), retro (retrospective, not an output).
These stages' quality is guaranteed by their own main tools; they need no adversarial layer.
<!-- 中文译注：不检查的环节——ideate（构想无代码）、discuss（讨论无产物）、qa（浏览器测试由 gstack /qa 负责）、verify（UAT 由 GSD 负责）、retro（复盘非产出）；这些环节质量由各自主工具保障，不需要对抗层。 -->
</gate_config>

<decide_large>
**Multi-model discussion for large decisions** (v2 new; called by loop-orchestrate's decide_best).

<!-- 中文译注：decide_large——大决策多模型讨论（v2 新增，供 loop-orchestrate 的 decide_best 调用）。 -->

When the loop encounters a large decision (architecture direction / scope change / critical dependency / data model / security policy), invoke:
```bash
~/.claude/skills/loop-engineering/scripts/loop-adversarial.sh decide-large "<decision description>" "<context_path>"
```
The script calls codex+gemini analyzer roles in parallel, letting each model give a plan + reason, and outputs:
```json
{
  "consensus": true|false,
  "choice": "<consensus plan or synthesized plan>",
  "reason": "<selection reason>",
  "codex": {"proposal": "...", "reason": "..."},
  "gemini": {"proposal": "...", "reason": "..."}
}
```
- consensus=true: both models' plans agree; adopt directly.
- consensus=false: the two models' plans differ; take the synthesis (merge both merits) or the more conservative one; record the disagreement.
loop's decide_best executes accordingly and records to decisions.jsonl.
<!-- 中文译注：脚本并行调 codex+gemini analyzer 各给方案+理由；consensus=true 两模型一致直接采用；consensus=false 取综合（合并优点）或更保守的，记录分歧；loop 的 decide_best 据此执行并记 decisions.jsonl。 -->
</decide_large>

<process>

<step name="run_gate">
Run the adversarial check on the current stage's output. Invoke the script:

```bash
# Full quality gate (deterministic + multi-model); auto-selects check items per the stage config
~/.claude/skills/loop-engineering/scripts/loop-adversarial.sh full "$STEP" "$TARGET_PATH" "$GIT_REF"
```
- `$STEP`: the current stage (spec/design/plan/execute/review/ship).
- `$TARGET_PATH`: the path of the check target (defaults to project root or .planning/).
- `$GIT_REF`: the diff baseline for multi-model review (defaults to HEAD).

The script outputs JSON to stdout and writes `.loop/adversarial/last-verdict.json`:
```json
{
  "passed": true|false,
  "gates": [
    {"gate": "security", "passed": true, "raw": {...}},
    {"gate": "dual-review", "passed": true, "consensus": true, "codex": {...}, "gemini": {...}}
  ]
}
```
<!-- 中文译注：run_gate——对当前环节产出跑对抗检查，调脚本 full 模式（确定性+多模型，自动按环节配置选检查项）；$STEP 当前环节、$TARGET_PATH 检查对象路径、$GIT_REF 多模型审查 diff 基准；输出 JSON 到 stdout 并写 last-verdict.json（含 passed + gates 各门结果）。 -->
</step>

<step name="evaluate">
Read last-verdict.json and judge:

**Case A: passed=true**
Update state (loop-state's update_state --adversarial-passed true), allow it through to the next step.

**Case B: passed=false**
Enter the auto_optimize loop. First distinguish the failure cause:
- **Deterministic gate fail** (security/quality/module): has clear findings (vulnerabilities/complexity exceeded/missing docs) → enter auto_optimize.
- **Multi-model disagreement** (disagreements>0): consensus=false; generate an adversarial discussion record → enter debate.
- **Multi-model consensus fail** (consensus=true but RECOMMENDATION≠PASS): both models think there's a problem → enter auto_optimize.
<!-- 中文译注：evaluate——读 last-verdict.json 判定：A passed=true 更新状态放行进下一步；B passed=false 进 auto_optimize 循环，先区分失败原因（确定性门 fail 有明确 findings 进 auto_optimize；多模型分歧 consensus=false 生成讨论记录进 debate；多模型共识 fail 两模型都认为有问题进 auto_optimize）。 -->
</step>

<step name="auto_optimize">
**Auto-optimize + re-check loop** (corresponds to "auto-optimize + re-check" decision). At most MAX_RETRY=3 rounds.
<!-- 中文译注：auto_optimize——自动优化+重检循环，最多 MAX_RETRY=3 轮。 -->

Each round:
1. **Synthesize suggestions**: deterministic-gate findings (each with file_path + recommendation) + both models' Suggestions/Critical Issues → merged into an optimization list.
2. **Generate optimization plan**: give a specific fix for each issue (which line to change, what doc to add, what spec to fix).
3. **Auto-apply**: invoke the matching means by issue type:
   - Security vulnerability / code issue → fix the code directly (Edit).
   - Missing docs → generate README.md/DESIGN.md (required by verify-module).
   - Complexity exceeded → refactor and split functions.
   - Spec issue → fix the OpenSpec specs.
4. **Re-check**: run run_gate once more (same step).

**Re-check passes** (passed=true) → exit the loop, update_state --adversarial-passed true, proceed to the next step.
**Re-check still fails and MAX_RETRY reached** → enter escalate.
<!-- 中文译注：每轮——综合确定性门 findings+两模型建议合成优化清单→为每个问题给具体修复→按类型自动应用（安全/代码问题直接 Edit 改代码、缺文档生成、复杂度超标重构拆分、规格问题修正 specs）→重检（再跑一次 run_gate）；重检通过跳出循环放行，仍 fail 且达 MAX_RETRY 进 escalate。 -->
</step>

<step name="debate">
**Adversarial discussion** (triggered on multi-model disagreement).

Read the `.loop/adversarial/debates/{ts}.md` generated by the script (contains each model's viewpoints + the disagreement points).
Handling of key disagreements:
- If the disagreement is **complementary viewpoints** (e.g. codex focuses on backend security, gemini on frontend a11y, each finding different issues) → adopt both suggestions, synthesize a complete optimization list, back to auto_optimize.
- If the disagreement is **contradictory conclusions** (e.g. one says PASS and the other FAIL for the same code spot) → synthesize a judgment:
  - Take the more conservative conclusion (fix when in doubt).
  - Or arbitrate combined with the deterministic-gate result (the deterministic gate has the final say).
- The generated discussion record is for traceability, but does NOT auto-pass — it must be confirmed in escalate.
<!-- 中文译注：debate——对抗讨论（多模型分歧时触发）；读 debates/{ts}.md（两模型各自观点+分歧点）；视角互补（如 codex 关注后端安全 gemini 关注前端 a11y 各自发现不同问题）则两者建议都采纳合成清单回 auto_optimize；结论矛盾（同一处一个 PASS 一个 FAIL）则取更保守（有疑虑就改）或结合确定性门仲裁（确定性门说了算）；讨论记录供追溯但不自动通过，需 escalate 确认。 -->
</step>

<step name="escalate">
**Escalate to a human** (re-check limit exceeded or an undecidable disagreement).

Invoke loop-state's update_state --blocker "<adversarial check failed: {reason}>".
Display:
```
⛔ 对抗质量门未通过（已重试 {N} 轮）

失败原因：{确定性门 findings 或 多模型分歧}

两模型审查记录：{.loop/adversarial/debates/ 最新文件}

请人工介入：
  1. 查看失败详情：cat .loop/adversarial/last-verdict.json
  2. 查看对抗讨论：cat .loop/adversarial/debates/*.md
  3. 手动优化后：/loop:adversarial {step}（重跑对抗检查）
  4. 通过后：/loop:run --next（继续闭环）
  5. 强制跳过（不推荐）：/loop:run --force --next
```
Do NOT auto-advance; wait for the user to handle the blocker.
<!-- 中文译注：escalate——升级到人工（重检超限或无法自动决断的分歧）；调 update_state --blocker，显示失败原因+两模型记录+人工介入步骤（查详情/查讨论/手动优化后重跑对抗/通过后续跑闭环/强制跳过不推荐）；不自动推进等用户处理 blocker。 -->
</step>

</process>

<conflict_note>
This adversarial layer **coexists without conflict** with each stage's main tool, and does not violate the "unique adjudication per stage" principle:
- The main tool is responsible for **producing** (gstack writes review conclusions, GSD writes code, OpenSpec writes specs).
- The CCG adversarial layer is responsible for **reviewing the output** (multi-viewpoint nitpicking, deterministic-gate把关).
The two have different responsibilities: one "does", the other "checks". This does not duplicate gstack's /review (gstack reviewing its own output) —
the CCG adversarial layer provides an **independent multi-model viewpoint**, complementing the blind spots of gstack's single viewpoint.
<!-- 中文译注：冲突说明——对抗层与各阶段主工具并存不冲突，不违反"按阶段唯一裁决"：主工具负责"产出"，CCG 对抗层负责"审查产出"（多视角挑刺+确定性门把关）；职责不同一个"做"一个"查"；与 gstack /review（gstack 自己审自己的产出）不重复，CCG 对抗层提供独立的多模型视角补充 gstack 单一视角盲区。 -->
</conflict_note>

<success_criteria>
- [ ] run_gate correctly selects check items per gate_config (no omissions, no extras).
- [ ] On deterministic-gate fail, findings carry a clear file_path + recommendation.
- [ ] auto_optimize at most 3 rounds, each round re-checks (no fake optimization).
- [ ] Multi-model disagreement generates debates/{ts}.md; complementary viewpoints are synthesized, contradictory conclusions take the conservative one.
- [ ] Only allow through on re-check pass; on exceeding the limit, escalate and set a blocker.
- [ ] last-verdict.json is updated on every check, for loop-state Gate 4 to read.
- [ ] Do NOT modify any CCG files; only invoke run_skill.js + codeagent-wrapper.
<!-- 中文译注：成功标准——run_gate 按 gate_config 正确选检查项不漏不多；确定性门 fail 时 findings 带明确 file_path+recommendation；auto_optimize 最多 3 轮每轮重检（不假优化）；多模型分歧生成 debates/{ts}.md 视角互补合议结论矛盾取保守；重检通过才放行超限 escalate 设 blocker；last-verdict.json 每次检查更新供 Gate 4 读；不改 CCG 任何文件只调 run_skill.js+codeagent-wrapper。 -->
</success_criteria>
