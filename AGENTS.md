# AGENTS.md — Loop Engineering AI Agent 行为规范

> 本文档指导 AI agent 如何**按规范**使用 Loop Engineering skill。
> agent 在执行任何 `/loop:*` 命令前，必须先读取本文件并遵守其中的行为约束。

---

## 0. 铁律（MUST / MUST NOT）

### MUST
1. **先读 SKILL.md 和它 @ include 的 4 个 workflow**（loop-state/orchestrate/iterate/adversarial），再执行任何操作。绝不凭记忆编造路由规则。
2. **以 `.loop/STATE.yaml` 为单一事实源**。所有状态判定（当前 Phase、step、blocker）都从这里读，不臆测。
3. **--auto 模式（默认）下，遇到决策点用最佳方案自动选择后继续**（小决策自主选，大决策调 decide-large 多模型讨论），只有硬障碍才停。**--interactive 模式下**，撞决策/安全门即停问人。
4. **有产出的环节（spec/design/plan/execute/review/ship）产出后必跑 adversarial_gate**。execute 是 plan 级（逐 plan 检查）。
5. **编排调用现有工具**，不重造 gstack/GSD/OpenSpec/CCG 的能力。路由表在 loop-orchestrate.md，不发明新路由。
6. **Route 6(execute) 走逐 plan 模式**：驱动 gsd-executor 子代理一个 plan 一个 plan 跑，每个完成后跑 plan 级对抗门，不再调 /gsd-execute-phase 一次性跑完。
7. **所有自动决策记录到 `.loop/decisions.jsonl`**，供用户最后验证时审查。
8. **用中文输出**（遵循全局 AGENTS.md/CLAUDE.md 语言规则），代码/命令/路径/专有名词除外。
9. **状态变更写回 STATE.yaml（原子写）+ 追加 timeline.jsonl**，保证可审计可恢复。
10. **前端生命周期必须完整 + 设计能力全家桶**（v4.2）：Route 3.4（参考项目复刻，有 reference_target 时执行 7 步逆向工程）→ Route 3.5（teach-impeccable 采集上下文 + ui-ux-pro-max 设计决策 + design-taste-frontend 防 AI 套路 + /design-consultation 竞品参考）→ Route 3.6（/design-shotgun 变体 + /design-html Vue3 代码 + **impeccable 21 子 skill 品质打磨**）不可跳过（Route 3.4 无参考时可跳过）。前端产出后必须经过 impeccable 品质打磨（至少 critique + polish），不能只"能用"就交付。spec 必须含前端 UI spec，plan 必须含前端业务页面 plan，部署必须含 frontend 且不被 profiles 隐藏。
11. **`/loop:refine` 总是生成三套提示词，必须让用户选，不得替用户选**（v4.3）：接收一句话需求 → 8 维度深度分析缺失点 → 用 AskUserQuestion 一次动态追问 3-6 个问题 → **总是**产出三套（标准/精简/高阶强约束）→ 用 AskUserQuestion 让用户选一套 → 写入 `.loop/refined-prompt.md`。agent 不擅自定版、不臆测缺失维度（缺失即追问）、不跳过追问环节。

### MUST NOT
1. **不得在 --auto 模式下因"需要人工决策"而停**——那是 --interactive 的行为。--auto 只因硬障碍停（编译失败3轮无效/依赖缺失/escalate超限/用户暂停）。
2. **不得让对抗检查未通过的产物进入下游环节**（除非 --auto 下 auto_optimize+decide_best 已自动解决）。
3. **不得修改 CCG 的任何文件**（config.toml / prompts / 命令），只调用 run_skill.js + codeagent-wrapper。
4. **不得绕过路由表直接做主工具的活**（如自己写代码审查，而应调 `/review` 或对抗门）。
5. **不得在 auto_optimize 里无限重试**。最多 3 轮，超限走 decide_best（--auto）或 escalate（--interactive）。
6. **不得用 SlashCommand 自调用实现 --auto 循环**（v3.1 核心变更）——SlashCommand 跨会话断链，导致每环节中断。--auto 必须用 **run_full_loop 的 while 循环 + inline 执行**（loop 自己 Read 目标 skill 的 SKILL.md + workflow，按指令在主会话内执行，会话不断）。不用 Skill()（ZCode 无此工具）、不用 Agent 子代理（Explore 只读）。--interactive 才用 SlashCommand。
7. **不得跳过 Gate 5（loop 与 GSD 状态一致性校验）**——execute 推进前必读 GSD STATE.md 对齐。

---

## 1. 命令执行规范

### `/loop:init [项目名]`
1. 检查 `.loop/STATE.yaml` 是否已存在——存在则询问是否覆盖（默认不覆盖，防丢历史）
2. 创建 `.loop/` 目录 + STATE.yaml（7-Phase 模板）+ learnings.yaml/gaps.yaml/timeline.jsonl（空）+ adversarial/（空）
3. STATE.yaml 初始化：`current_phase: 1, current_step: ideate, iteration: 1`
4. 询问是否立即调 `/office-hours` 进入构想

### `/loop:refine <提示词>`（v4.3 新增）
提示词专业化优化器，横切工具（不依赖 init、不推进闭环）。完全交给 loop-refine.md workflow：
1. 接收用户的一句话需求（`$ARGUMENTS`），按 8 个维度深度分析（目标用户/核心场景/技术栈/规模性能/鉴权安全/优先级MVP/既有代码约束/验收标准）
2. 基于分析**动态生成 3-6 个追问**（针对缺失/模糊维度），用 AskUserQuestion 一次并行追问
3. 综合答复后**总是产出三套**：标准版（日常使用，层级清晰）/ 精简版（迭代对话，紧凑）/ 高阶强约束版（AI Agent 强化：强制文件读取 + 鉴权保护 + 原有逻辑保护 + 质量门强制）
4. 用 AskUserQuestion 让用户选一套——**agent 不替选**
5. 写入 `.loop/refined-prompt.md`（含原始提示词/追问记录/三套全文/选定版本）
6. 提示下一步：`/office-hours`（带优化后提示词）或 `/loop:run --next`。**不自动调用**

### `/loop:status`
1. 读 STATE.yaml
2. 渲染看板：当前 Phase/step、进度条、各 Phase 状态、blocker、对抗检查状态（读 last-verdict.json）、历史循环摘要、下一步建议命令
3. **只读，不修改任何状态**

### `/loop:run [--next] [--auto]`
执行顺序（严格按此）：
1. **read_state**：读 STATE.yaml，无则提示 `/loop:init`
2. **safety_gates**：跑 Gate 1-4（无 `--force` 则遇门即停并退出）
3. **determine_next_action**：按 loop-orchestrate.md 的 11 路由匹配下一步命令
4. **show_and_execute**：显示判定 → 通过 SlashCommand 调用主工具命令
5. **adversarial_gate**：主工具产出后，若当前 step 在 gate_config 覆盖范围，跑对抗检查（见第 3 节）
6. **auto_chain**：若带 `--auto` 且对抗门通过，SlashCommand 自调用 `/loop:run --next --auto`

**`--phase N` / `--from N`**：先过 safety_gates，确认产物完整，再切换 phase。

### `/loop:adversarial [step]`
1. step 缺省取 STATE.yaml 的 current_step
2. 完全交给 loop-adversarial.md 的 run_gate → evaluate → auto_optimize/debate/escalate
3. 支持 `--debate`（强制记录两模型观点）、`--deterministic-only`（只确定性门）

### `/loop:retro`
完全交给 loop-iterate.md（retro→教训→审计→种子→闭环）。

---

## 2. 路由执行规范（11 条路由）

**按阶段唯一裁决**——每阶段只用一个工具家族，不并行两套：

| 阶段 | 用谁 | 不用谁 |
|------|------|--------|
| 规划 | gstack 商业审核 + OpenSpec 技术规格 | 不用 GSD 规划 |
| 执行 | GSD 执行引擎 | 不用 gstack autoplan |
| 审查 | gstack /review（更强） | 不用 GSD code-review |
| 发布 | gstack ship/canary/deploy | 不用其他 |

**对抗检查层与主工具并存不冲突**：主工具"产出"，CCG 对抗层"审查产出"。职责不同，互补。

调用主工具时，**用 SlashCommand 工具**（不是凭记忆执行其逻辑）。调用前在终端显示判定结果。

---

## 3. 对抗质量门执行规范（核心）

### 何时触发
当前 step 在 `spec/design/plan/execute/review/ship` 之一，且主工具刚产出内容。

### 如何执行
调用脚本（不要自己重新实现检查逻辑）：
```bash
~/.claude/skills/loop-engineering/scripts/loop-adversarial.sh full "$STEP" "$TARGET_PATH" "$GIT_REF"
```

### 判定处理（严格按 loop-adversarial.md）
- **passed=true** → update_state `--adversarial-passed true`，放行
- **确定性门 fail / 多模型共识 fail** → 进入 auto_optimize
- **多模型分歧**（consensus=false）→ 进入 debate

### auto_optimize 规范
1. 综合确定性门 findings + 两模型 Suggestions → 优化清单
2. 每个问题给具体修复（改哪行、补什么文档）
3. 按问题类型自动应用（Edit 改代码、生成文档、修规格）
4. 重检（再跑一次 run_gate）
5. **最多 3 轮**。通过则放行，仍 fail 则 escalate
6. escalate：update_state `--blocker "对抗检查未通过: {原因}"`，显示失败详情 + 讨论记录路径，**停止推进等用户处理**

### debate 规范
- **视角互补**（codex 发现后端问题，gemini 发现前端问题）→ 两者建议都采纳，合成清单，回 auto_optimize
- **结论矛盾**（同一处一个 PASS 一个 FAIL）→ 取保守（有疑虑就改）+ 确定性门仲裁
- 生成 `.loop/adversarial/debates/{ts}.md` 供追溯

### 可靠性修正（必读）
- verify-quality 的 exit code **不可信**（复杂度超标只产生 warning 不阻断）——脚本已二次解析 JSON，agent 不要自己改用 exit code
- verify-change **必须用 staged/committed 模式**（working 模式行数恒 0）——脚本已处理
- trust 脚本输出的 JSON，不要重新判定

---

## 4. 安全门执行规范（Gate 1-4）

推进前**顺序**检查，无 `--force` 时遇任一门即停并退出：

| 门 | 检查 | 停止时提示 |
|----|------|-----------|
| Gate 1 | STATE.yaml 当前 phase 的 blockers 数组非空 | 列出 blocker，提示解决后删除条目 |
| Gate 2 | 上一 phase 的 artifacts 在磁盘真实存在 | 列出缺失产物路径 |
| Gate 3 | 从 Phase 4→5 时 qa-report.md 不含 FAIL/严重 | 提示先修复 |
| Gate 4 | `.loop/adversarial/last-verdict.json` 的 passed=true | 提示看 last-verdict.json 或 `/loop:adversarial` |

**`--force` 行为**：打印 `⚠ --force: 跳过安全门`，跳过所有门直接推进。**agent 不得自行加 --force，必须用户显式传**。

---

## 5. 状态读写规范

### 读
- 每次执行 `/loop:run` 都**重新读** STATE.yaml（不用缓存，因为上一步可能改了它）
- 对抗门读 last-verdict.json

### 写（update_state）
- **原子写**：先写 `.loop/STATE.yaml.tmp` 再 rename，避免半写状态
- **保留结构**：不破坏既有字段（phase_status、artifacts、history）
- **追加 timeline.jsonl**：`{"ts","phase","step","event":"advance|block|complete|iterate","adversarial":"pass|fail|skip|none"}`

### 支持的 update_state 参数
`--step` / `--phase` / `--blocker` / `--resolve-blocker` / `--artifact` / `--next-iteration` / `--adversarial-passed` / `--adversarial-report`

---

## 6. 循环原语规范

### `--auto` 自调用
- 用 **SlashCommand 工具**执行 `/loop:run --next --auto`，**不是递归函数调用**
- 这样每次循环独立读 STATE.yaml，能捕捉上一步的修改
- 停止条件：宏观循环完成 / 撞 blocker / error/paused 状态

### 停止时显示
```
⛔ 自动链停止：{原因}

解决后用：/loop:run --next --auto 继续。
```

---

## 7. 错误处理规范

- **底层工具未初始化**（如 OpenSpec 没在项目 init）→ 路由规则提示先初始化，不强行推进
- **codeagent-wrapper 不可用**（后端未启动）→ 对抗门的多模型部分降级，只跑确定性门，并提示用户
- **脚本执行失败**（run_skill.js 报错）→ 记录到 timeline.jsonl，不阻断主流程（对抗门是质量增强，不应让脚本错误卡死闭环）
- **STATE.yaml 损坏**→ 提示 `/loop:init`，不尝试自动修复（防数据丢失）

---

## 8. 输出规范

遵循全局 AGENTS.md 的语言规则：
- 所有面向用户输出用**简体中文**
- gstack 的 D<N>/ELI10/Recommendation/Completeness/Net 等格式标记按全局映射表转中文
- 例外（保持原文）：代码、命令、路径、函数名、配置 key、专有名词（Redis/Kubernetes 等）

看板/进度显示用清晰的 ASCII 框 + 表格，不用英文 markdown 套话。

---

## 9. 与其他工具共存的规范

- 用户可继续单独用 `/gsd-*` `/review` 等任何命令，loop 不干涉
- loop 只在显式跑 `/loop:*` 时介入
- 不修改 GSD 的 `.planning/`（只读它的产物判断 GSD 进度）
- 不修改 gstack 的 `.gstack/`（只读 review/qa 产物）

---

## 10. 自检清单（agent 每次执行后核对）

- [ ] 是否先读了 SKILL.md + 4 workflow？
- [ ] 是否以 STATE.yaml 为事实源（重新读，未臆测）？
- [ ] **--auto 模式**：决策点是否走了 decide_best（小自主/大多模型），没因"需人工"而停？
- [ ] **--auto 模式**：是否只有硬障碍才停（编译3轮无效/依赖缺失/escalate超限/用户暂停）？
- [ ] **execute 环节**：是否走逐 plan 模式（gsd-executor 单 plan + plan 级对抗门），而非一次性 /gsd-execute-phase？
- [ ] 自动决策是否记录到 .loop/decisions.jsonl？
- [ ] execute 推进前是否跑了 Gate 5（与 GSD STATE.md 一致性校验）？
- [ ] 有产出的环节是否跑了 adversarial_gate？
- [ ] 对抗未通过是否走了 auto_optimize（≤3轮）→ decide_best（--auto）/ escalate（--interactive）？
- [ ] 状态变更是否原子写回 STATE.yaml + 追加 timeline.jsonl？
- [ ] **--auto 是否用 run_full_loop 的 while 循环 + inline 执行**（loop 自己 Read skill 指令 + 主会话执行，非 SlashCommand/Skill/Agent，单会话连续）？
- [ ] 是否遵守"按阶段唯一裁决"（没并行两套工具）？
- [ ] 是否用中文输出（代码/路径除外）？
- [ ] 是否没修改 CCG/GSD/gstack 任何文件、没自行加 --force？
- [ ] **/loop:refine**：是否总是生成三套（标准/精简/高阶强约束）并用 AskUserQuestion 让用户选（没替选）？
- [ ] **/loop:refine**：是否对缺失维度动态追问 3-6 个问题（没臆测、没跳过追问）？
