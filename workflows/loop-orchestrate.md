<purpose>
Loop Engineering 的编排核心。把 7-Phase 闭环落成 11 条路由规则，每条规则把控制权交给已有的最强工具（gstack 看 / OpenSpec 写 / GSD 做）。

**设计哲学（v2 全自动长程）**：提出想法 → 大致规划 → 自动跑完整个项目，决策点用最佳方案自动选择后继续，直到整个项目跑完才叫用户验证。
- 默认 --auto：全自动跑到完成，只有"硬障碍"才停
- --interactive：可选的保守模式，撞决策就停
- execute 逐 plan 执行 + 每个 plan 完成后跑对抗检查
</purpose>

<required_reading>
@$HOME/.claude/get-shit-done/workflows/loop-state.md
@$HOME/.claude/get-shit-done/workflows/loop-adversarial.md
</required_reading>

<conflict_policy>
遵循文档"按阶段唯一裁决"原则（重叠时按阶段选唯一工具，不并行两套）：
- 规划阶段 → gstack 商业审核(/office-hours) + OpenSpec 技术规格，不用 GSD 的规划
- 执行阶段 → loop 逐 plan 驱动 gsd-executor 子代理（见 Route 6），不用 gstack autoplan
- 审查阶段 → gstack /review（更强），不用 GSD code-review
- 发布阶段 → gstack ship/canary/deploy，不用其他
- QA → gstack /qa（真实浏览器），不用静态分析
- 安全 → gstack /cso（OWASP+STRIDE），不用其他

**对抗检查层（CCG）与上述主工具并存，不违反唯一裁决**：主工具负责"产出"，CCG 对抗层负责"审查该产出"。职责不同，互补不冲突。
</conflict_policy>

<modes>
两种运行模式（由 /loop:run 的 flag 决定）：
- **--auto（默认）**：全自动长程。决策点用最佳方案自动选择（见 decide_best）后继续；只有硬障碍才停。项目跑完才叫用户验证。
- **--interactive**：保守模式。撞决策/安全门就停，等人。等价于 v1 行为。

硬障碍定义（--auto 模式唯一真停点）：
- 编译/构建失败且 auto_optimize 3 轮自动修复无效
- 关键依赖缺失且无法自动绕过
- 对抗门 escalate 超限（auto_optimize 3 轮 + 多模型讨论仍无法解决）
- 用户显式暂停（Ctrl-C / /loop:pause）
</modes>

<process>

<step name="determine_next_action">
读 `.loop/STATE.yaml`，按 current_phase + current_step 匹配路由表，得出下一步命令。
**路由表（11 条，按文档流程顺序）：**

**Route 1：构想（Phase 1, step=ideate）**
条件：项目刚 init 或进入新一轮 iteration，还没有 ideation 产物。
→ 下一步：`/office-hours`
说明：gstack 6 问深挖产品构想（CEO 视角）。完成后产出存 `.loop/ideation.md`，step → spec。
**首次迭代建议**：ideate 后跑 `teach-impeccable`（一次性采集项目设计上下文，建立持久设计规范，后续所有设计 skill 都读它）。

**Route 2：规格（Phase 2, step=spec）**
条件：ideation.md 存在，但还没有 OpenSpec change/spec。
→ 下一步：`/opsx:propose "<feature>"`（一步生成 proposal+specs+design+tasks）
备选：若 OpenSpec 未在该项目 init，先 `openspec init`。
说明：OpenSpec 负责"写"规格（SDD 方式）。**完成后检查 specs 是否含前端 UI spec（页面清单/组件树/交互流程/视觉参考来源）；若全是后端领域 spec，补充前端 spec。** 完成后 step → design。

**Route 3：设计/三重审核（Phase 2, step=design）**
条件：OpenSpec change 已生成，但未做三重审核。
→ 下一步（顺序执行三条）：
  1. `/plan-ceo-review`（战略：值不值得做？）
  2. `/plan-eng-review`（工程：架构是否合理？）
  3. `/plan-design-review`（UX/UI：用户流程是否顺畅？）
说明：收集三份审核结论。**--auto 模式下，有分歧时走 decide_best 自动裁决后继续（修正 spec 再推进），不为人停下；--interactive 模式下，反对就停问人。** 完成后存 `.loop/design-reviews.md`，step → replicate（若有参考项目）或 design-consult（无参考项目时跳过 Route 3.4）。

**Route 3.4：前端 UI 复刻（Phase 2, step=replicate）— v4.1 参考项目复刻**
条件：三重审核完成，且 STATE.yaml 的 `reference_target` 非空（用户通过 `--reference <url|repo>` 指定了参考项目）。
→ 下一步：inline 执行 replicate-workflow.md（7 步逆向工程）
说明：**这是前端生命周期"参考→复刻"环节**。当有可参考的仓库时，按 7 步流程提取设计依据：
  1. 识别技术栈（Read package.json/vite.config/tsconfig/tailwind.config）
  2. 提取设计 token（$D extract + 补 radius/shadows/breakpoints）→ DESIGN.md
  3. 梳理路由表+页面结构+组件树（Glob src/router, src/views, src/components）
  4. 逐组件记录（结构/props/状态/交互/样式）→ docs/components/
  5. 整理 API 接口与数据结构（Glob src/api, src/store, *.proto/swagger）
  6. 收集静态资源（$B scrape 或 cp 图片/图标/字体/logo）
  7. 标注交互/动画/表单校验（Grep + $B snapshot/forms/ux-audit）
详细执行逻辑见 @replicate-workflow.md。
**无参考项目时（reference_target 为空）跳过本路由**，直接进 Route 3.5 greenfield 设计。
**--auto 模式**：自动判断 reference_target（从 ideation.md 提取参考线索），不停。完成后 step → design-consult。

**Route 3.5：前端参考与设计系统（Phase 2, step=design-consult）— v4.2 设计能力全家桶**
条件：三重审核完成，但未做前端参考/设计系统。
→ 下一步（顺序，融合三套设计能力）：
  1. **采集设计上下文**：`teach-impeccable`（一次性，扫描项目建立持久设计规范，写 AI config）
  2. **确定设计方向**：`ui-ux-pro-max`（设计智能库：从 50+ 风格/161 色板/57 字体/99 UX 准则里，基于产品类型选定风格/配色/字体/布局/间距系统）
  3. **防 AI 套路化**：`design-taste-frontend`（taste-skill：读 brief 推断正确设计方向，设三档调谐 [密度/张力/华丽]，映射到真实设计系统而非模板默认）
  4. **竞品参考+设计系统提案**：`/design-consultation`（gstack：竞品截图研究 + 美学/排版/色彩/布局/间距/动效 → DESIGN.md）
说明：**这是前端生命周期"参考→设计决策"环节**。ui-ux-pro-max 提供"选什么"的知识库，taste-skill 防止"选错/套路化"，design-consultation 产出 DESIGN.md。
**--auto 模式**：自动确定竞品+设计方向（基于 ideation.md 产品定位），不停。完成后 step → design-ui。

**Route 3.6：前端设计变体与代码生成（Phase 2, step=design-ui）— v4.2 含 impeccable 品质打磨**
条件：DESIGN.md 已生成，但未做前端设计变体/代码。
→ 下一步（顺序）：
  1. `/design-shotgun`：基于 DESIGN.md 生成多个 UI 变体 → 比较板 → 选择最佳
  2. `/design-html`：把选定变体转成 Vue3 生产级代码（或 HTML）
  3. 可选 `ecc/ui-to-vue`：若有竞品截图，批量转 Vue3 组件（复刻）
  4. **impeccable 品质打磨**（CCG 21 子 skill，按需调用）：
     - `impeccable/arrange`：改进布局/间距/视觉节奏
     - `impeccable/typeset`：修复字体/层级/字号/字重/行高
     - `impeccable/colorize`：补充色彩层次（避免过于单调）
     - `impeccable/animate`：加有目的的动效/微交互
     - `impeccable/polish`：最终对齐/间距/一致性过一遍
     - `impeccable/critique`：UX 视角评估（视觉层级/信息架构/可用性）
     - `impeccable/normalize`：对齐设计系统标准（spacing/token）
     - 其他按需：bolder(大胆)/delight(惊喜)/clarify(文案)/harden(健壮性)/onboard(引导)/optimize(性能)
  5. 可选 `/design-review`：若已有可访问预览，做视觉 QA
说明：**这是前端生命周期"复刻→设计→实现→打磨"环节**。impeccable 让产出从"能用"到"精致"。产出前端业务页面代码（不只是骨架）。
**--auto 模式**：design-shotgun 自动选最佳变体，design-html 自动生成 Vue3，impeccable 子 skill 按 critique 结果自动选择调用，不停。完成后存产物路径，step → discuss，phase → 3。

**Route 4：讨论（Phase 3, step=discuss）**
条件：设计审核通过，但 GSD 项目未初始化或 phase 未讨论。
→ 下一步：先确保 `/gsd:new-project` 已跑，再 `/gsd-discuss-phase <N>`。
说明：捕获实施前的灰色地带决策。**--auto 模式下，GSD 灰色地带走 decide_best 自动选默认/最佳，不问人。** 完成后 step → plan。

**Route 5：规划（Phase 3, step=plan）**
条件：phase 已讨论，但无 PLAN.md。
→ 下一步：`/gsd-plan-phase <N>`
说明：GSD 从 ROADMAP 生成详细 PLAN.md（研究→计划→验证循环）。**完成后检查 plan 是否含前端业务页面实现 plan（不只骨架）；若无前端业务 plan，补充一个。** 完成后 step → execute。

**Route 6：执行（Phase 3, step=execute）— 逐 plan 模式**
条件：PLAN.md 存在，但未全部产出 SUMMARY。
→ **不再调 `/gsd-execute-phase <N>` 一次性跑完**，改为 loop 自己逐 plan 驱动（见 execute_plan_by_plan 步骤）。
说明：loop 当 orchestrator，直接驱动 gsd-executor 子代理一个 plan 一个 plan 跑，每个完成后跑对抗门再下一个。**前端 plan 同样走逐 plan 执行，执行后对抗门额外跑 `/design-review`（视觉 QA）+ `impeccable/polish`（最终品质过一遍）补充代码审查。** 这避免"主工具是异步重操作导致 auto_chain 卡死"（素材 #4）。Superpowers 在此自动触发 TDD/调试。完成后 step → review，phase → 4。

**Route 7：代码审查（Phase 4, step=review）**
条件：执行完成，未做 review。
→ 下一步：`/review`（生产级代码审查）+ `/cso`（OWASP+STRIDE 安全扫描）
说明：审查用 gstack（更强）。完成后发现存 `.loop/reviews.md`，step → qa。

**Route 8：浏览器 QA（Phase 4, step=qa）**
条件：审查完成，未做 QA。
→ 下一步：`/qa <staging-url>`（真实浏览器自动化，Playwright）
备选：`/qa-only` 只测不修。
说明：gstack /qa 独一档（真实浏览器）。**QA 前先验证前端已正确部署（compose up 含 frontend，URL 可访问）；若前端不可访问 → 自动修复部署配置（移除 profiles 隐藏、加 make deploy）后重试。** /qa 测真实 Vue3 SPA 界面（路由/交互/表单）。完成后报告存 `.loop/qa-report.md`，step → verify。

**Route 9：UAT 验收（Phase 4, step=verify）**
条件：QA 通过，未做 UAT。
→ 下一步：`/gsd-verify-work <N>`（对话式用户验收测试）
说明：验收用 GSD。**--auto 模式下，UAT 的验收标准自动判定（按 acceptance_criteria + 对抗门结果），不强制人工。** 完成后 step → ship，phase → 5。

**Route 10：发布流水线（Phase 5, step=ship）**
条件：验收通过，未发布。
→ 下一步（顺序）：`/ship` → `/canary` → `/land-and-deploy`
说明：发布交给 gstack。**发布前确保全栈部署编排正确：docker-compose 的 frontend 服务不被 profiles 隐藏、有 `make deploy` 一键全栈命令。部署后验证前端可访问（curl HTTP 200 + 有 index.html）。** 完成后记录 `.loop/ship-log.md`，step → complete，phase → 6。

**Route 11：迭代/里程碑闭环（Phase 6, step=complete/retro）**
条件：发布完成，未做复盘。
→ 下一步：先 `/gsd-complete-milestone`（归档+打 tag），再交由 loop-iterate workflow 处理 retro→教训→下一轮。
说明：宏观回环接缝。**--auto 模式下，retro 完成后自动进入下一轮（iteration+1），不问人——直到所有里程碑跑完。** 详见 loop-iterate.md。
</step>

<step name="execute_plan_by_plan">
**Route 6 的逐 plan 执行逻辑（核心，路径 B）。**

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

**依赖处理**：读 OVERVIEW.md 依赖图。基座 plan（zllmwiki 的 Plan 1）必须先完成；逐 plan 串行执行天然满足依赖。可并行的 plan（同 wave 无相互依赖）可顺序跑完各自对抗门后合并。
</step>

<step name="decide_best">
**决策点自动选择（--auto 模式核心，对应"弹出选择时以最佳方案自动选择"）。**

在以下场景触发：三重审核分歧、GSD 灰色地带、AskUserQuestion、UAT 判定、范围/架构选择。

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

decisions.jsonl 格式：
```json
{"ts":"<ISO>","phase":<N>,"step":"<step>","size":"small|large","decision":"<内容>","choice":"<选择>","reason":"<理由>","models":{"codex":"...","gemini":"..."}}
```
所有自动决策都记录，用户最后验证时可审查"loop 替我做了哪些决定"。
</step>

<step name="show_and_execute">
显示判定结果，然后调用确定的命令。

```
## Loop Next（第 {iteration} 轮循环 | {auto|interactive} 模式）

**当前：** Phase {N} — {phase_name} | step: {current_step}
**状态：** {status 描述}

▶ **下一步：** `/{command} {args}`
  {为什么这是下一步的一行说明}
```

调用前先调 loop-state 的 safety_gates（按模式分行为）。
**--auto / --force 模式**：safety_gates 命中时尝试自动解决（--force 直接跳过）。主工具用 **inline 执行**——loop 自己 Read 目标 skill 的 SKILL.md + workflow，按其指令在主会话内执行（用 Read/Write/Edit/Bash/AskUserQuestion）。会话不断。
**--interactive 模式**：safety_gates 命中即停。主工具用 SlashCommand 调用，撞决策停问人。
</step>

<step name="adversarial_gate">
**对抗性质量门**（主工具产出后，对该产物跑 CCG 对抗检查）。

仅在产出有实质内容可检查的环节触发：spec / design / plan / execute / review / ship。
（execute 环节是 plan 级，见 execute_plan_by_plan 步骤 4）

- 通过 → 继续 auto_chain
- 未通过 → auto_optimize（最多 3 轮），仍失败则 escalate（设 blocker）
- **--auto 模式**：escalate 后，若属"可自动绕过"的问题（如补文档、修命名），decide_best 自动处理后继续；属硬障碍才停
- **--interactive 模式**：escalate 即停问人
</step>

<step name="auto_chain">
**循环原语（核心，v3.1 inline 执行机制）。**

**⚠️ v3.1 关键变更：从 SlashCommand 自调用改为 inline 执行。**
- v2：SlashCommand 自调用 `/loop:run --next --auto` → 跨会话断链，每环节中断
- v3：Skill() 调用 → 但 ZCode 的 loop allowed-tools 没有 Skill 工具，跑不起来
- **v3.1（最终方案）：inline 执行** —— loop 自己在主会话里 Read 目标 skill 的 SKILL.md + workflow，按其指令在主会话内直接执行。这是 gsd-autonomous INTERACTIVE=false 的真正机制（"Run inline as before"）。会话不结束，循环不断。

**--auto 模式：进入 run_full_loop 单会话 inline 连续循环**

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

**关键区别**：不用 SlashCommand（跨会话断）、不用 Skill()（ZCode 无此工具）、不用 Agent 子代理（Explore 只读）。而是 **loop 自己 inline 执行**——Read 目标 skill 的指令文件，在主会话内按指令操作。会话不结束，循环不断。一次 `/loop:run --next --auto` 跑完全程。

**--force 模式**：跳过所有安全门（Gate 1-5），让 while 循环不停。配合 inline 执行，实现"一条命令跑完不中断"。决策点仍走 decide_best（自动选最佳，不停）。

**--auto / --force 停止条件（只有以下才 break）**：
- 整个项目跑完（所有 Phase + 所有里程碑 retro 完成，next_seed 为空）
- 硬障碍（编译失败3轮无效/依赖缺失/escalate超限/用户暂停）

**--interactive 模式：保留 SlashCommand 行为**
--interactive 不进入 run_full_loop。每个环节用 SlashCommand 调用，撞决策/安全门即停，等人。等价 v1 行为。

因硬障碍 break 时，显示：
```
⛔ 全自动循环遇到硬障碍：{原因}

loop 已自动尝试修复（3 轮）但未能解决。请人工介入：
  1. 查看详情：cat .loop/adversarial/last-verdict.json
  2. 查看自动决策：cat .loop/decisions.jsonl（loop 替你做过的决定）
  3. 手动修复后：/loop:run --next --auto 继续（从当前环节续跑）

或切保守模式：/loop:run --next --interactive
```

**关键：run_full_loop 是 while 循环（非递归、非 SlashCommand 自调用）。主工具用 inline 执行（loop 自己读 skill 指令 + 主会话操作）。会话不断，一条命令跑完。**
</step>

</process>

<success_criteria>
- [ ] 11 条路由按 current_phase+current_step 正确匹配
- [ ] Route 6 走 execute_plan_by_plan（逐 plan + 对抗门），不再调 /gsd-execute-phase 一次性跑完
- [ ] decide_best 正确判定决策大小，小自主选/大多模型讨论
- [ ] 所有自动决策记录到 decisions.jsonl
- [ ] --auto 进入 run_full_loop 单会话连续循环（Skill() 同步调用，非 SlashCommand 自调用）
- [ ] --auto 只有硬障碍才 break；--interactive 撞决策就停
- [ ] 三重审核 --auto 自动裁决继续，--interactive 反对就停
- [ ] safety_gates 按模式分行为（--auto 尝试自动解决，--interactive 命中即停）
- [ ] Route 11 --auto 自动进入下一轮，不问人
</success_criteria>
