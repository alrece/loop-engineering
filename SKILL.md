---
name: loop-engineering
description: "Loop Engineering — 全自动长程工程闭环。提出想法→大致规划→自动跑完整个项目（决策点用最佳方案自动选择），最后才叫用户验证。跨工具编排 gstack(看)/OpenSpec(写)/GSD(做)/Superpowers(守)，每环节嵌入 CCG 对抗性质量门，execute 逐 plan 执行+检查。"
argument-hint: "[--next [--auto|--interactive] | --phase N | --from N | --status | --init <name> [--reference <url|repo>] | --retro | --adversarial [step]]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - SlashCommand
  - AskUserQuestion
---

<objective>
Loop Engineering 是一个**编排层**，不重造 gstack/GSD/OpenSpec 已有能力，而是把它们按文档最佳实践串成可自动循环的工程闭环。

**设计哲学（v2 全自动长程）**：提出想法 → 大致规划 → 自动跑完整个项目，决策点用最佳方案自动选择后继续，直到整个项目跑完才叫用户验证。用户若发现问题，在新一轮规划中修正。

四种能力：
1. **全自动长程闭环**：13 路由（含前端生命周期 Route 3.5/3.6）+ `--auto` 默认全自动（只有硬障碍才停）+ `--interactive` 可选保守。execute 逐 plan 执行+检查
2. **前端生命周期全覆盖 + 设计能力全家桶**（v4.2）：**复刻**（Route 3.4 参考仓库 7 步逆向工程）→ **设计决策**（Route 3.5：teach-impeccable 采集上下文 + ui-ux-pro-max 设计智能库选风格/色板/字体 + design-taste-frontend 防 AI 套路化 + /design-consultation 竞品研究）→ **实现+打磨**（Route 3.6：/design-shotgun 变体 + /design-html Vue3 代码 + impeccable 21 子 skill 品质打磨 polish/arrange/typeset/colorize/animate/delight/critique）→ **测试**（/qa 真实浏览器）。不再出现"部署后无界面"或"界面粗糙"
3. **分层决策**：小决策 loop 自主选最佳；大决策（架构/范围/依赖）调多模型（codex+gemini）讨论后选。所有自动决策记录到 decisions.jsonl 供追溯
4. **对抗性质量门**（CCG）：每个有产出的环节跑对抗检查（确定性门 + 多模型 + 前端检查），发现问题自动优化+重检

设计遵循 GSD 风格：SKILL.md 极小，逻辑外置到 workflow 文件，用 @ include + SlashCommand 自调用实现循环。
</objective>

<execution_context>
@$HOME/.claude/skills/loop-engineering/AGENTS.md
@$HOME/.claude/get-shit-done/workflows/loop-state.md
@$HOME/.claude/get-shit-done/workflows/loop-orchestrate.md
@$HOME/.claude/get-shit-done/workflows/loop-iterate.md
@$HOME/.claude/get-shit-done/workflows/loop-adversarial.md
@$HOME/.claude/get-shit-done/workflows/replicate-workflow.md
</execution_context>

<roles>
工具家族职责（文档一句话总结，编排时严格遵守边界）：
- **gstack 负责"看"**：审核、QA、安全审计、部署、产品思维（CEO 视角）
- **GSD 负责"做"**：规划、执行、验证、里程碑管理
- **OpenSpec 负责"写"**：规格定义（SDD 方式）
- **Superpowers 负责"守"**：TDD 强制、调试、质量门（被动触发，无需调用）
- **CCG 做多模型路由**：按需切换 Claude/Codex/Gemini
</roles>

<process>
Arguments provided: "$ARGUMENTS"

Parse the first token to determine mode：

**`--init <name> [--reference <url|repo>]`** → 执行初始化：
1. 创建项目根 `.loop/` 目录 + `STATE.yaml`（7-Phase 模板，见 loop-state.md 的 state_schema）
2. 创建 `learnings.yaml`、`gaps.yaml`、`timeline.jsonl` 空文件
3. current_phase=1, current_step=ideate, iteration=1
4. **若带 `--reference <url|repo>`**：写入 STATE.yaml 的 reference_target（git URL / 本地路径 / 线上 URL），后续 Route 3.4 会触发复刻流程
5. 询问是否立即调用 `/office-hours` 进入构想（文档 Phase 1 入口）

**`--status`**（或无参数）→ 执行只读看板：
1. 读 `.loop/STATE.yaml`
2. 输出闭环看板：当前 Phase/步骤、迭代轮次、各阶段产物状态、blocker、下一步建议命令、历史循环摘要
3. 不修改任何状态

**`--retro`** → 执行迭代回环：完全交给 loop-iterate.md workflow（retro→教训→审计→种子→闭环）

**`--next [--auto|--interactive|--force]`** → 执行推进（默认 --auto 全自动）：
1. 调 loop-state.md 的 read_state + safety_gates（按模式分行为）
2. **--auto / --force（默认 v3.1）**：进入 loop-orchestrate.md 的 **run_full_loop 单会话 inline 连续循环**——loop 自己在主会话里 Read 每个环节主工具的 SKILL.md + workflow，按其指令 inline 执行（用 Read/Write/Edit/Bash/AskUserQuestion），不用 SlashCommand（跨会话断）、不用 Skill()（ZCode 无此工具）、不用 Agent 子代理（Explore 只读）。每个环节完成后跑对抗门+advance_loop 前进，遇决策点 decide_best 自动选，只有硬障碍才 break。**一次调用跑完全程，不中断。** `--force` 额外跳过所有安全门。
3. **--interactive**：每个环节用 SlashCommand 调用，撞决策/安全门即停问人（保守行为）
4. 遇决策点：调 decide_best（--auto 小决策自主选/大决策多模型讨论；--interactive 停问人）
5. show_and_execute：--auto/--force 用 inline 执行；--interactive 用 SlashCommand

**`--adversarial [step]`** → 手动触发对抗检查（不必等闭环自动触发）：
1. step 可选（spec/design/plan/execute/review/ship），缺省取 STATE.yaml 的 current_step
2. 完全交给 loop-adversarial.md workflow（run_gate→evaluate→auto_optimize/debate/escalate）
3. 支持 `--debate`（强制记录两模型观点）、`--deterministic-only`（只跑确定性门不调多模型）

**`--phase N`** → 跳转到指定 Phase（先过 safety_gates，确认上一阶段产物完整）

**`--from N`** → 从 Phase N 续跑（用于中断恢复，跳过已完成阶段）

**无 `.loop/` 时**：提示 `/loop:init [项目名]`。

Preserve all routing/gate logic from the included workflows. Do not invent new routing rules outside loop-orchestrate.md.
</process>

<success_criteria>
- [ ] $ARGUMENTS 正确路由到各模式（init/status/retro/next/adversarial/phase/from）
- [ ] 编排调用现有工具（/office-hours /opsx:* /plan-*-review /gsd-* /review /cso /qa /ship /canary /land-and-deploy /retro），不重造能力
- [ ] --next 默认 --auto 全自动；--interactive 撞决策即停
- [ ] --auto 只有硬障碍才停（编译失败3轮无效/依赖缺失/escalate超限/用户暂停）
- [ ] **--auto 进入 run_full_loop 单会话 inline 连续循环**（loop 自己 Read skill 指令 + 主会话执行，非 SlashCommand/Skill/Agent），一次跑完全程不中断
- [ ] decide_best 正确分层：小决策自主选，大决策调 decide-large 多模型讨论
- [ ] 所有自动决策记录到 .loop/decisions.jsonl
- [ ] Route 6(execute) 走逐 plan 模式（gsd-executor 单 plan + plan 级对抗门），不再调 /gsd-execute-phase 一次性跑完
- [ ] safety_gates 5 道（Gate 5 校验与 GSD 状态一致性），按模式分行为
- [ ] 有产出的环节产出后跑 adversarial_gate
- [ ] 对抗未通过 auto_optimize（≤3轮），超限 escalate（--auto 仍尝试 decide_best 绕过，硬障碍才停）
- [ ] status 模式只读不改
- [ ] init 生成完整 STATE.yaml + 空资产文件
</success_criteria>
