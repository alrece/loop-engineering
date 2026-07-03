<purpose>
The orchestration core of Loop Engineering. It realizes the 7-Phase closed loop as 11 routing rules, each handing control to the strongest existing tool (gstack for review / OpenSpec for writing / GSD for building).

<!-- 中文译注：编排核心——把 7-Phase 闭环落成 11 条路由规则，每条把控制权交给已有最强工具（gstack 看/OpenSpec 写/GSD 做）。 -->

**Design philosophy (v2 fully autonomous long-horizon)**: Propose an idea → rough plan → run the entire project automatically, auto-selecting the best option at decision points and continuing, only pausing for the user to verify once the whole project is complete.
- Default --auto: fully autonomous, runs to completion; only a "Hard Blocker" stops it.
- --interactive: optional conservative mode; stops on hitting a decision.
- execute runs plan-by-plan + runs an adversarial check after each plan.

<!-- 中文译注：设计哲学（v2 全自动长程）——提出想法→大致规划→自动跑完，决策点用最佳方案自动选择后继续，整个项目跑完才叫用户验证；默认 --auto 全自动只有硬障碍才停；--interactive 撞决策就停；execute 逐 plan 执行+每个 plan 后跑对抗检查。 -->
</purpose>

<required_reading>
@$HOME/.claude/get-shit-done/workflows/loop-state.md
@$HOME/.claude/get-shit-done/workflows/loop-adversarial.md
</required_reading>

<conflict_policy>
Follow the documented "unique adjudication per stage" principle (on overlap, pick one tool per stage; do not run two in parallel):
- Planning stage → gstack business review (/office-hours) + OpenSpec tech spec; NOT GSD planning.
- Execution stage → loop drives gsd-executor subagent plan-by-plan (see Route 6); NOT gstack autoplan.
- Review stage → gstack /review (stronger); NOT GSD code-review.
- Ship stage → gstack ship/canary/deploy; NOT others.
- QA → gstack /qa (real browser); NOT static analysis.
- Security → gstack /cso (OWASP+STRIDE); NOT others.

<!-- 中文译注：冲突策略——按阶段唯一裁决（重叠时选唯一工具不并行两套）：规划→gstack 商业审核+OpenSpec 技术规格；执行→loop 逐 plan 驱动 gsd-executor；审查→gstack /review；发布→gstack ship/canary/deploy；QA→gstack /qa；安全→gstack /cso。 -->

**The adversarial-check layer (CCG) coexists with the above main tools and does not violate unique adjudication**: the main tool is responsible for "producing"; the CCG adversarial layer is responsible for "reviewing that output". Different responsibilities, complementary and non-conflicting.
<!-- 中文译注：对抗检查层（CCG）与主工具并存，不违反唯一裁决——主工具负责"产出"，CCG 对抗层负责"审查产出"，职责不同互补不冲突。 -->
</conflict_policy>

<modes>
Two run modes (determined by the /loop:run flag):
- **--auto (default)**: fully autonomous long-horizon. At decision points the best option is auto-selected (see decide_best) and execution continues; only a Hard Blocker stops it. The user is only called for verification once the project is complete.
- **--interactive**: conservative mode. Stops on hitting a decision/safety gate and waits for a human. Equivalent to v1 behavior.

<!-- 中文译注：两种模式——--auto（默认）全自动长程，决策点自动选最佳后继续，只有硬障碍才停，项目跑完才叫用户验证；--interactive 保守模式，撞决策/安全门就停问人，等价 v1。 -->

Hard Blocker definition (the only true stop point in --auto mode):
- Compile/build failure where auto_optimize's 3 rounds of auto-fix are ineffective.
- Critical dependency missing and cannot be automatically bypassed.
- Adversarial gate escalate limit exceeded (auto_optimize 3 rounds + multi-model discussion still cannot resolve).
- User explicitly pauses (Ctrl-C / /loop:pause).
<!-- 中文译注：硬障碍定义（--auto 唯一真停点）——编译失败且 auto_optimize 3 轮无效；关键依赖缺失无法绕过；对抗门 escalate 超限；用户显式暂停。 -->
</modes>

<process>

<step name="determine_next_action">
Read `.loop/STATE.yaml`, match current_phase + current_step against the routing table, and determine the next-step command.
**Routing table (11 routes, in documented flow order):**
<!-- 中文译注：determine_next_action——读 STATE.yaml，按 current_phase+current_step 匹配 11 条路由表得出下一步命令。 -->

**Route 1: Ideation (Phase 1, step=ideate)**
Condition: the project was just init'd or entered a new iteration round, with no ideation artifact yet.
→ Next step: `/office-hours`.
Note: gstack's 6 questions dig into the product idea (CEO perspective). On completion the output is saved to `.loop/ideation.md`, step → spec.
**First-iteration suggestion**: after ideate run `teach-impeccable` (one-time collection of project design context; establishes a persistent design spec that all subsequent design skills read).
<!-- 中文译注：Route 1 构想——项目刚 init 或新迭代无 ideation 产物→/office-hours（gstack 6 问深挖产品构想，CEO 视角），完成产出存 .loop/ideation.md，step→spec；首次迭代建议后跑 teach-impeccable 建立持久设计规范。 -->

**Route 2: Spec (Phase 2, step=spec)**
Condition: ideation.md exists, but no OpenSpec change/spec yet.
→ Next step: `/opsx:propose "<feature>"` (generates proposal+specs+design+tasks in one step).
Alternative: if OpenSpec was not init'd in this project, first run `openspec init`.
Note: OpenSpec owns "writing" the spec (SDD approach). **On completion check whether the specs contain a front-end UI spec (page list / component tree / interaction flow / visual-reference source); if it's all backend domain specs, add the front-end spec.** On completion step → design.
<!-- 中文译注：Route 2 规格——ideation.md 存在但无 OpenSpec→/opsx:propose 一步生成；OpenSpec 负责"写"规格；完成后检查是否含前端 UI spec（页面/组件/交互/视觉参考），全是后端则补前端 spec；step→design。 -->

**Route 3: Design / triple review (Phase 2, step=design)**
Condition: the OpenSpec change is generated, but the triple review has not been done.
→ Next step (run these three in order):
  1. `/plan-ceo-review` (strategy: is it worth doing?)
  2. `/plan-eng-review` (engineering: is the architecture sound?)
  3. `/plan-design-review` (UX/UI: is the user flow smooth?)
Note: collect the three review conclusions. **In --auto mode, on disagreement go through decide_best to auto-adjudicate and continue (fix the spec then advance); do not stop for a human. In --interactive mode, stop and ask a human on objection.** On completion save to `.loop/design-reviews.md`, step → replicate (if a reference project exists) or design-consult (skip Route 3.4 when there is no reference project).
<!-- 中文译注：Route 3 设计/三重审核——顺序跑 plan-ceo-review（战略值不值得做）→plan-eng-review（工程架构是否合理）→plan-design-review（UX/UI 流程是否顺畅）；收集三份结论；--auto 有分歧走 decide_best 自动裁决继续（修正 spec 再推进），--interactive 反对就停；存 .loop/design-reviews.md，step→replicate（有参考）或 design-consult（无参考跳过 Route 3.4）。 -->

**Route 3.4: Front-end UI replication (Phase 2, step=replicate) — v4.1 reference-project replication**
Condition: the triple review is done, and STATE.yaml's `reference_target` is non-empty (the user specified a reference project via `--reference <url|repo>`).
→ Next step: inline-execute replicate-workflow.md (7-step reverse engineering).
Note: **This is the "reference → replication" step of the front-end lifecycle.** When there is a referenceable repo, extract design basis per the 7-step flow:
  1. Identify the tech stack (Read package.json/vite.config/tsconfig/tailwind.config).
  2. Extract design tokens ($D extract + supplement radius/shadows/breakpoints) → DESIGN.md.
  3. Map out the routing table + page structure + component tree (Glob src/router, src/views, src/components).
  4. Record each component (structure/props/state/interaction/style) → docs/components/.
  5. Organize API interfaces and data structures (Glob src/api, src/store, *.proto/swagger).
  6. Collect static assets ($B scrape or cp images/icons/fonts/logo).
  7. Annotate interactions/animations/form-validation (Grep + $B snapshot/forms/ux-audit).
Detailed execution logic in @replicate-workflow.md.
**Skip this route when there is no reference project** (reference_target empty); go directly to Route 3.5 greenfield design.
**--auto mode**: auto-detect reference_target (extract reference clues from ideation.md); do not stop. On completion step → design-consult.
<!-- 中文译注：Route 3.4 前端 UI 复刻（v4.1）——三重审核完成且 reference_target 非空时 inline 执行 replicate-workflow.md（7 步逆向工程：技术栈→设计 token→路由+页面+组件树→逐组件记录→API+数据结构→静态资源→交互/动画/校验）；无参考时跳本路由直接进 Route 3.5；--auto 自动判断 reference_target 不停，完成后 step→design-consult。 -->

**Route 3.5: Front-end reference and design system (Phase 2, step=design-consult) — v4.2 full design toolkit**
Condition: the triple review is done, but the front-end reference/design system has not been done.
→ Next step (in order, fusing three design capabilities):
  1. **Collect design context**: `teach-impeccable` (one-time; scans the project to build a persistent design spec, writes the AI config).
  2. **Determine the design direction**: `ui-ux-pro-max` (design knowledge library: selects style/color/font/layout/spacing system from 50+ styles/161 palettes/57 fonts/99 UX rules based on product type).
  3. **Guard against cookie-cutter AI**: `design-taste-frontend` (taste-skill: infers the correct design direction from the brief; sets three tuning levels [density/tension/ornamentation]; maps to real design systems rather than template defaults).
  4. **Competitor reference + design-system proposal**: `/design-consultation` (gstack: competitor screenshot research + aesthetics/typography/color/layout/spacing/motion → DESIGN.md).
Note: **This is the "reference → design decision" step of the front-end lifecycle.** ui-ux-pro-max provides the "what to choose" knowledge base, taste-skill guards against "choosing wrong / cookie-cutter", and design-consultation produces DESIGN.md.
**--auto mode**: auto-determine competitors + design direction (based on ideation.md product positioning); do not stop. On completion step → design-ui.
<!-- 中文译注：Route 3.5 前端参考与设计系统（v4.2）——融合三套设计能力：teach-impeccable 采集上下文→ui-ux-pro-max 选风格/色板/字体/布局/间距→design-taste-frontend 防 AI 套路化→/design-consultation 竞品研究产 DESIGN.md；--auto 自动确定竞品+设计方向不停，完成后 step→design-ui。 -->

**Route 3.6: Front-end design variants and code generation (Phase 2, step=design-ui) — v4.2 incl. impeccable quality polish**
Condition: DESIGN.md is generated, but no front-end design variants/code yet.
→ Next step (in order):
  1. `/design-shotgun`: generate multiple UI variants from DESIGN.md → comparison board → pick the best.
  2. `/design-html`: convert the selected variant to Vue3 production-grade code (or HTML).
  3. Optional `ecc/ui-to-vue`: if competitor screenshots exist, batch-convert to Vue3 components (replication).
  4. **impeccable quality polish** (CCG 21 sub-skills, call as needed):
     - `impeccable/arrange`: improve layout/spacing/visual rhythm.
     - `impeccable/typeset`: fix font/hierarchy/size/weight/line-height.
     - `impeccable/colorize`: add color layers (avoid being too monotone).
     - `impeccable/animate`: add purposeful motion/micro-interactions.
     - `impeccable/polish`: a final pass on alignment/spacing/consistency.
     - `impeccable/critique`: evaluate from a UX perspective (visual hierarchy/IA/usability).
     - `impeccable/normalize`: align to design-system standards (spacing/token).
     - Others as needed: bolder (bold), delight (surprise), clarify (copy), harden (robustness), onboard (guidance), optimize (performance).
  5. Optional `/design-review`: if an accessible preview exists, do a visual QA.
Note: **This is the "replication → design → implement → polish" step of the front-end lifecycle.** impeccable elevates output from "works" to "refined". Produce front-end business-page code (not just a skeleton).
**--auto mode**: design-shotgun auto-picks the best variant, design-html auto-generates Vue3, impeccable sub-skills are auto-selected based on the critique result; do not stop. On completion save artifact paths, step → discuss, phase → 3.
<!-- 中文译注：Route 3.6 前端设计变体与代码生成（v4.2 含 impeccable 品质打磨）——design-shotgun 生成多变体选最佳→design-html 转 Vue3→ecc/ui-to-vue 批量转→impeccable 21 子 skill 品质打磨（arrange/typeset/colorize/animate/polish/critique/normalize 等）→可选 design-review；impeccable 让产出从"能用"到"精致"，产前端业务页面代码；--auto 自动选变体/生成 Vue3/按 critique 选子 skill 不停，step→discuss，phase→3。 -->

**Route 4: Discuss (Phase 3, step=discuss)**
Condition: the design review passed, but the GSD project is not initialized or the phase is not discussed.
→ Next step: first ensure `/gsd:new-project` has run, then `/gsd-discuss-phase <N>`.
Note: captures gray-area decisions before implementation. **In --auto mode, GSD gray areas go through decide_best to auto-pick default/best; do not ask a human.** On completion step → plan.
<!-- 中文译注：Route 4 讨论——设计审核通过但 GSD 项目未初始化或 phase 未讨论→先确保 /gsd:new-project 已跑再 /gsd-discuss-phase；捕获实施前灰色地带决策；--auto 灰色地带走 decide_best 自动选默认/最佳不问人；step→plan。 -->

**Route 5: Plan (Phase 3, step=plan)**
Condition: the phase is discussed, but no PLAN.md yet.
→ Next step: `/gsd-plan-phase <N>`.
Note: GSD generates a detailed PLAN.md from the ROADMAP (research→plan→verify loop). **On completion check whether the plan contains front-end business-page implementation plans (not just a skeleton); if no front-end business plan, add one.** On completion step → execute.
<!-- 中文译注：Route 5 规划——phase 已讨论但无 PLAN.md→/gsd-plan-phase（从 ROADMAP 生成详细 PLAN.md）；完成后检查是否含前端业务页面实现 plan（不只骨架），若无则补；step→execute。 -->

**Route 5.5: Desktop full-stack deployment orchestration (Phase 3, step=deploy) — v4.2 new**
Condition: PLAN.md exists, but the deployment config is incomplete (the frontend service is hidden by profiles, or there is no make deploy).
→ Next step: auto-fix the deployment config (remove the profiles hiding, generate make deploy), then `/gsd-plan-phase <N>`.
Note: ensures full-stack deployment is usable. **In --auto mode auto-fix and do not stop; in --interactive mode, stop and ask a human if the fix fails.** On completion step → plan.
<!-- 中文译注：Route 5.5 桌面端全栈部署编排（v4.2）——PLAN.md 存在但部署配置不完整（前端被 profiles 隐藏或无 make deploy）→自动修复（移除 profiles 隐藏、生成 make deploy）再 /gsd-plan-phase；--auto 自动修复不停，--interactive 修复失败则停问人；step→plan。 -->

**Route 6: Execute (Phase 3, step=execute) — plan-by-plan mode**
Condition: PLAN.md exists, but not all SUMMARYs are produced.
→ **No longer call `/gsd-execute-phase <N>` to run everything at once**; instead the loop itself drives plan-by-plan (see the execute_plan_by_plan step).
Note: the loop acts as orchestrator, directly driving the gsd-executor subagent to run one plan at a time, running the adversarial gate after each before the next. **Front-end plans likewise go through plan-by-plan execution; after execution the adversarial gate additionally runs `/design-review` (visual QA) + `impeccable/polish` (a final quality pass) to supplement the code review.** This avoids "the main tool being a heavy async operation causing auto_chain to deadlock" (material #4). Superpowers auto-triggers TDD/debugging here. On completion step → review, phase → 4.
<!-- 中文译注：Route 6 执行（逐 plan 模式）——PLAN.md 存在但未全部产 SUMMARY→不再调 /gsd-execute-phase 一次性跑完，改为 loop 逐 plan 驱动 gsd-executor 子代理，每个完成后跑对抗门再下一个；前端 plan 同样逐 plan 执行，执行后对抗门额外跑 /design-review（视觉 QA）+impeccable/polish；避免"主工具异步重操作导致 auto_chain 卡死"；Superpowers 自动触发 TDD/调试；step→review，phase→4。 -->

**Route 7: Code review (Phase 4, step=review)**
Condition: execution is done, no review yet.
→ Next step: `/review` (production-grade code review) + `/cso` (OWASP+STRIDE security scan).
Note: review uses gstack (stronger). On completion save findings to `.loop/reviews.md`, step → qa.
<!-- 中文译注：Route 7 代码审查——执行完成未做 review→/review（生产级代码审查）+/cso（OWASP+STRIDE 安全扫描）；审查用 gstack 更强；存 .loop/reviews.md，step→qa。 -->

**Route 8: Browser QA (Phase 4, step=qa)**
Condition: review is done, no QA yet.
→ Next step: `/qa <staging-url>` (real browser automation, Playwright).
Alternative: `/qa-only` tests only without fixing.
Note: gstack /qa is unique (real browser). **Before QA first verify the frontend is correctly deployed (compose up includes frontend, URL accessible); if the frontend is not accessible → auto-fix the deployment config (remove profiles hiding, add make deploy) and retry.** /qa tests the real Vue3 SPA UI (routing/interaction/forms). On completion save the report to `.loop/qa-report.md`, step → verify.
<!-- 中文译注：Route 8 浏览器 QA——审查完成未做 QA→/qa <staging-url>（真实浏览器自动化 Playwright），备选 /qa-only 只测不修；gstack /qa 独一档（真实浏览器）；QA 前先验证前端已正确部署（compose up 含 frontend，URL 可访问），不可访问则自动修复部署配置后重试；测真实 Vue3 SPA 界面；报告存 .loop/qa-report.md，step→verify。 -->

**Route 9: UAT acceptance (Phase 4, step=verify)**
Condition: QA passed, no UAT yet.
→ Next step: `/gsd-verify-work <N>` (conversational user acceptance testing).
Note: acceptance uses GSD. **In --auto mode, UAT acceptance criteria are auto-judged (per acceptance_criteria + adversarial-gate results); do not force a human.** On completion step → ship, phase → 5.
<!-- 中文译注：Route 9 UAT 验收——QA 通过未做 UAT→/gsd-verify-work（对话式用户验收测试）；验收用 GSD；--auto 验收标准自动判定（按 acceptance_criteria+对抗门结果）不强制人工；step→ship，phase→5。 -->

**Route 11: Ship pipeline (Phase 5, step=ship)**
Condition: acceptance passed, not yet shipped.
→ Next step (in order): `/ship` → `/canary` → `/land-and-deploy`.
Note: shipping goes to gstack. **Before shipping ensure the full-stack deployment orchestration is correct: docker-compose's frontend service is not hidden by profiles, and there is a `make deploy` one-click full-stack command. After deploy verify the frontend is accessible (curl HTTP 200 + has index.html).** On completion record to `.loop/ship-log.md`, step → complete, phase → 6.
<!-- 中文译注：Route 11 发布流水线——验收通过未发布→/ship→/canary→/land-and-deploy；发布交 gstack；发布前确保全栈部署编排正确（frontend 不被 profiles 隐藏、有 make deploy），部署后验证前端可访问（curl HTTP 200+有 index.html）；记录 .loop/ship-log.md，step→complete，phase→6。 -->

**Route 12: Iteration/milestone close loop (Phase 6, step=complete/retro)**
Condition: shipping is done, no retrospective yet.
→ Next step: first `/gsd-complete-milestone` (archive + tag), then hand off to the loop-iterate workflow for retro → lessons → next round.
Note: the macro-loop seam. **In --auto mode, after retro completes automatically enter the next round (iteration+1), without asking a human — until all milestones are done.** See loop-iterate.md.
<!-- 中文译注：Route 12 迭代/里程碑闭环——发布完成未复盘→先 /gsd-complete-milestone（归档+打 tag）再交 loop-iterate workflow 处理 retro→教训→下一轮；--auto retro 完成后自动进下一轮（iteration+1）不问人，直到所有里程碑跑完。 -->
</step>

<step name="execute_plan_by_plan">
**The plan-by-plan execution logic of Route 6 (core, path B).**
<!-- 中文译注：execute_plan_by_plan——Route 6 的逐 plan 执行逻辑（核心，路径 B）。 -->

```
1. 查询待执行 plan：
   gsd_run query phase-plan-index "<current_phase>"
   → 取 plans[]，找第一个 has_summary=false 的（若依赖未完成则先跑依赖）
   → 无未完成 plan → phase 收尾（触发 SKELETON 集成验收），step → review

2. 执行单个 plan（loop 当 orchestrator，驱动 gsd-executor 子代理）：
   Agent(
     subagent_type="gsd-executor",
     prompt="
       Execute plan {plan_id} of phase {phase}.
       Follow @$HOME/.claude/get-shit-done/workflows/execute-plan.md
       Read: {phase_dir}/{plan_file}
       Commit each task atomically. Create {plan_id}-SUMMARY.md.
       Do NOT update STATE.md/ROADMAP.md（loop 对抗门通过后统一更新）。
     "
   )
   顺序模式（非 worktree），避免并发 STATE 覆盖。

3. 确认 plan 完成：
   检测 {plan_id}-SUMMARY.md 出现 + git log 有 {phase}-{plan} commit。

4. 对抗门（plan 级）：
   ~/.claude/skills/loop-engineering/scripts/loop-adversarial.sh full execute "<plan 的 git diff 范围>"
   → evaluate last-verdict.json
   → 通过 → 更新 GSD STATE.md/ROADMAP（gsd_run query roadmap.update-plan-progress + state.advance-plan）
   → 未通过 → auto_optimize（≤3轮）→ escalate

5. 继续循环（不自调用）：在 run_full_loop 的 while 循环内 continue 回到步骤 1
   → phase-plan-index 自动跳过刚完成的 plan，取下一个
   → 会话不断，继续执行下一个 plan（v3：不再用 SlashCommand 自调用）
```

**Dependency handling**: read OVERVIEW.md's dependency graph. The foundation plan (e.g. Plan 1) MUST complete first; plan-by-plan serial execution naturally satisfies dependencies. Plans that can run in parallel (same wave, no mutual dependency) can each finish their adversarial gate then be merged.
<!-- 中文译注：依赖处理——读 OVERVIEW.md 依赖图；基座 plan 必须先完成，逐 plan 串行执行天然满足依赖；可并行的 plan（同 wave 无相互依赖）可顺序跑完各自对抗门后合并。 -->
</step>

<step name="decide_best">
**Decision-point auto-selection (--auto mode core; corresponds to "auto-selecting the best option when a choice pops up").**
<!-- 中文译注：decide_best——决策点自动选择（--auto 模式核心，对应"弹出选择时以最佳方案自动选择"）。 -->

Triggered in: triple-review disagreement, GSD gray areas, AskUserQuestion, UAT judgment, scope/architecture choice.

```
判定决策大小：
  小决策（命名/参数/实现细节/非关键库/工具选择/单个函数设计）
    → loop 基于 spec/上下文/对抗结果自主选最佳方案，继续
    → 记录到 .loop/decisions.jsonl

  大决策（架构方向/范围增减/关键依赖/数据模型/安全策略/技术栈选型）
    → 调 loop-adversarial.sh decide-large "<决策描述>" <context_path>
      （并行调 codex+gemini analyzer 讨论，取共识/综合方案）
    → 按共识方案执行，继续
    → 记录到 .loop/decisions.jsonl（含两模型观点 + 最终选择 + 理由）

--interactive 模式下：decide_best 不自动选，停问人（保留 v1 行为）。
```

decisions.jsonl format:
```json
{"ts":"<ISO>","phase":<N>,"step":"<step>","size":"small|large","decision":"<内容>","choice":"<选择>","reason":"<理由>","models":{"codex":"...","gemini":"..."}}
```
All automatic decisions are recorded; during final verification the user can review "what decisions the loop made on my behalf".
<!-- 中文译注：所有自动决策记录到 decisions.jsonl（含 ts/phase/step/size/decision/choice/reason/models）；用户最后验证时可审查"loop 替我做了哪些决定"。 -->
</step>

<step name="show_and_execute">
Display the verdict, then invoke the determined command.
<!-- 中文译注：show_and_execute——显示判定结果，再调用确定的命令。 -->

```
## Loop Next（第 {iteration} 轮循环 | {auto|interactive} 模式）

**当前：** Phase {N} — {phase_name} | step: {current_step}
**状态：** {status 描述}

▶ **下一步：** `/{command} {args}`
  {为什么这是下一步的一行说明}
```

Before invoking, first call loop-state's safety_gates (behavior split by mode).
**--auto / --force mode**: on safety_gates hit, attempt auto-resolution (--force skips directly). The main tool uses **inline execution** — the loop itself Reads the target skill's SKILL.md + workflow and executes per the instructions within the main session (using Read/Write/Edit/Bash/AskUserQuestion). The session does not break.
**--interactive mode**: safety_gates hit → stop. The main tool is invoked via SlashCommand; on hitting a decision, stop and ask a human.
<!-- 中文译注：调用前先调 safety_gates（按模式分行为）；--auto/--force 命中时尝试自动解决（--force 直接跳过），主工具用 inline 执行（loop 自己 Read 目标 skill 的 SKILL.md+workflow，按指令在主会话内执行，会话不断）；--interactive 命中即停，主工具用 SlashCommand 调用，撞决策停问人。 -->
</step>

<step name="adversarial_gate">
**Adversarial quality gate** (after the main tool produces output, run a CCG adversarial check on that output).
<!-- 中文译注：adversarial_gate——对抗性质量门（主工具产出后对该产物跑 CCG 对抗检查）。 -->

Triggered only for stages whose output has substantive content to check: spec / design / plan / execute / review / ship.
(The execute stage is plan-level; see execute_plan_by_plan step 4.)

- Pass → continue auto_chain.
- Fail → auto_optimize (at most 3 rounds); on still-fail, escalate (set blocker).
- **--auto mode**: after escalate, if it's an "auto-bypassable" issue (e.g. add docs, fix naming), decide_best handles it and continues; only a Hard Blocker stops.
- **--interactive mode**: escalate → stop and ask a human.
<!-- 中文译注：仅在产出有实质内容可检查的环节触发（spec/design/plan/execute/review/ship）；execute 是 plan 级；通过继续，未通过 auto_optimize（最多 3 轮）仍失败则 escalate 设 blocker；--auto escalate 后若属可自动绕过的问题（如补文档、修命名）decide_best 自动处理后继续，属硬障碍才停；--interactive escalate 即停问人。 -->
</step>

<step name="auto_chain">
**Loop primitive (core; v3.1 inline-execution mechanism).**
<!-- 中文译注：auto_chain——循环原语（核心，v3.1 inline 执行机制）。 -->

**⚠️ v3.1 key change: from SlashCommand self-invocation to inline execution.**
- v2: SlashCommand self-invocation of `/loop:run --next --auto` → breaks across sessions, every stage interrupted.
- v3: Skill() invocation → but ZCode's loop allowed-tools has no Skill tool, cannot run.
- **v3.1 (final solution): inline execution** — the loop itself, in the main session, Reads the target skill's SKILL.md + workflow and executes directly per the instructions. This is the true mechanism of gsd-autonomous INTERACTIVE=false ("Run inline as before"). The session does not end; the loop does not break.
<!-- 中文译注：v3.1 关键变更——从 SlashCommand 自调用改为 inline 执行；v2 SlashCommand 自调用跨会话断链每环节中断；v3 Skill() 调用但 ZCode 无 Skill 工具跑不起来；v3.1 最终方案 inline 执行——loop 自己在主会话里 Read 目标 skill 的 SKILL.md+workflow 按指令直接执行，会话不结束循环不断。 -->

**--auto mode: enter the run_full_loop single-session inline continuous loop**

```
run_full_loop（--auto 模式，单会话内 while 循环，inline 执行）:
  while True:
    1. read_state       读 .loop/STATE.yaml（每次循环重读，捕捉上一步修改）
    2. safety_gates     --auto 尝试自动解决；--force 跳过所有门
    3. determine_next_action  11 路由匹配下一步主工具
    4. inline 执行主工具（loop 自己读 skill 指令 + 主会话执行，会话不断）:
       - gstack 工具: Read ~/.claude/skills/gstack/office-hours/SKILL.md
                      → 按其指令在主会话内执行（用 Read/Write/Edit/Bash/AskUserQuestion）
       - GSD 工具:    Read ~/.claude/skills/gsd-execute-phase/SKILL.md + @ workflows
                      → 按其指令执行（GSD 的 gsd_run query 用 Bash 调）
       - OpenSpec:    Bash 调 openspec CLI（opsx:propose 的逻辑内联执行）
       - execute 逐 plan: 循环内 Read execute-plan.md + 驱动执行 + 对抗门
       ★ 关键：不是发起新命令/新会话，是 loop 自己读指令后在本会话执行
    5. adversarial_gate  对产出跑对抗检查（--auto 自动优化+重检）
    6. advance_loop      前进 step + 写 timeline（不触发自调用，只更新状态）
    7. 遇决策点 → decide_best（小自主/大多模型），不为人停
    8. 遇硬障碍 → break（真停，见下）
    9. 环节完成 → continue（回到步骤 1，会话不断）
    10. 所有 Phase + 所有里程碑完成 → break（项目完成）
```

**Key distinction**: do NOT use SlashCommand (breaks across sessions), do NOT use Skill() (ZCode has no such tool), do NOT use Agent subagents (Explore is read-only). Instead **the loop itself inline-executes** — Read the target skill's instruction file, then operate per the instructions within the main session. The session does not end; the loop does not break. A single `/loop:run --next --auto` runs the whole way.
<!-- 中文译注：关键区别——不用 SlashCommand（跨会话断）、不用 Skill()（ZCode 无此工具）、不用 Agent 子代理（Explore 只读），而是 loop 自己 inline 执行（Read 目标 skill 指令文件+主会话内按指令操作），会话不结束循环不断，一次 /loop:run --next --auto 跑完全程。 -->

**--force mode**: skip all safety gates (Gate 1-5), keep the while-loop from stopping. Combined with inline execution, this realizes "one command runs to completion without interruption". Decision points still go through decide_best (auto-select the best; do not stop).
<!-- 中文译注：--force 模式——跳过所有安全门（Gate 1-5），让 while 循环不停，配合 inline 执行实现"一条命令跑完不中断"；决策点仍走 decide_best（自动选最佳不停）。 -->

**--auto / --force stop conditions (only the following break):**
- The entire project is done (all Phases + all milestone retros complete, next_seed empty).
- Hard Blocker (compile failure 3 rounds ineffective / missing dependency / escalate limit / user pause).
<!-- 中文译注：--auto/--force 停止条件——整个项目跑完（所有 Phase+所有里程碑 retro 完成，next_seed 为空）或硬障碍（编译失败3轮无效/依赖缺失/escalate超限/用户暂停）。 -->

**--interactive mode: retains SlashCommand behavior**
--interactive does not enter run_full_loop. Each stage is invoked via SlashCommand; on hitting a decision/safety gate it stops and waits for a human. Equivalent to v1 behavior.
<!-- 中文译注：--interactive 保留 SlashCommand 行为——不进 run_full_loop，每环节用 SlashCommand 调用，撞决策/安全门即停等人，等价 v1。 -->

On breaking due to a Hard Blocker, display:
```
⛔ 全自动循环遇到硬障碍：{原因}

loop 已自动尝试修复（3 轮）但未能解决。请人工介入：
  1. 查看详情：cat .loop/adversarial/last-verdict.json
  2. 查看自动决策：cat .loop/decisions.jsonl（loop 替你做过的决定）
  3. 手动修复后：/loop:run --next --auto 继续（从当前环节续跑）

或切保守模式：/loop:run --next --interactive
```
<!-- 中文译注：因硬障碍 break 时显示原因+查看详情+自动决策+续跑命令+切保守模式。 -->

**Key: run_full_loop is a while-loop (non-recursive, non-SlashCommand self-invocation). The main tool uses inline execution (the loop itself Reads the skill instructions + operates in the main session). The session does not break; one command runs to completion.**
<!-- 中文译注：关键——run_full_loop 是 while 循环（非递归、非 SlashCommand 自调用）；主工具用 inline 执行（loop 自己读 skill 指令+主会话操作）；会话不断，一条命令跑完。 -->
</step>

</process>

<success_criteria>
- [ ] The 11 routes are correctly matched by current_phase + current_step.
- [ ] Route 6 uses execute_plan_by_plan (plan-by-plan + adversarial gate), no longer calling /gsd-execute-phase to run everything at once.
- [ ] decide_best correctly tiers decision size: small auto-selected / large multi-model discussion.
- [ ] All automatic decisions are recorded to decisions.jsonl.
- [ ] --auto enters the run_full_loop single-session continuous loop (synchronous inline execution, NOT SlashCommand self-invocation).
- [ ] --auto breaks only on a Hard Blocker; --interactive stops on hitting a decision.
- [ ] Triple review: --auto auto-adjudicates and continues; --interactive stops on objection.
- [ ] safety_gates behavior split by mode (--auto attempts auto-resolution, --interactive stops on hit).
- [ ] Route 11 --auto auto-enters the next round, without asking a human.
<!-- 中文译注：成功标准——11 路由按 phase+step 正确匹配；Route 6 走 execute_plan_by_plan（逐 plan+对抗门）；decide_best 正确分层；决策记 jsonl；--auto 进 run_full_loop 单会话连续循环（inline 执行非 SlashCommand 自调用）；--auto 只硬障碍 break，--interactive 撞决策停；三重审核 --auto 自动裁决继续；safety_gates 按模式分行为；Route 11 --auto 自动进下一轮不问人。 -->
</success_criteria>
