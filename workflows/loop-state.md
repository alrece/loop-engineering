<purpose>
Loop Engineering 的状态机核心。读写 `.loop/STATE.yaml`，检测当前处于 7-Phase 闭环的哪个阶段、哪个步骤，并执行安全门检查。
被 loop-orchestrate 和 loop-iterate 复用。本文件只管"状态读写 + 产物完整性校验"，不做路由决策（路由在 orchestrate）。
</purpose>

<required_reading>
Read all files referenced by the invoking skill's execution_context before starting.
</required_reading>

<state_schema>
`.loop/STATE.yaml` 是单一事实源（项目根目录下），与 GSD 的 `.planning/` 并存、互不干扰。结构：

```yaml
version: 1
project: <项目名>
current_phase: 1            # 1-7（见 phase_map）
current_step: ideate        # 见 step_map
iteration: 1                # 第几轮宏观循环（每次完成 Phase 7 的 retro 后 +1）
started_at: <ISO8601>
reference_target: null      # v4.1 参考项目（git URL / 本地路径 / 线上 URL）。非空时触发 Route 3.4 复刻流程；null 时跳过复刻走 greenfield 设计
reference_path: null        # 复刻时参考项目的本地路径（git clone 后或本地目录）
reference_type: null        # git | local | url（决定复刻步骤的源码可读性）
phase_status:
  1: { status: active, step: ideate, blockers: [], artifacts: [] }
  2: { status: pending, step: null, blockers: [], artifacts: [] }
  # ... 1-7
artifacts:                  # 跨工具产物追踪（相对项目根的路径）
  ideate: .loop/ideation.md          # /office-hours 产出
  spec: openspec/changes/            # OpenSpec specs
  design: .loop/design-reviews.md    # 三重审核记录
  replicate: .loop/replicate/        # v4.1 参考项目复刻产物（7步逆向工程文档）
  design-consult: DESIGN.md          # v4 前端参考+设计系统
  design-ui: ~/.gstack/projects/.../designs/  # v4 前端设计变体+代码
  planning: .planning/               # GSD 规划产物
  execute: .planning/PLAN.md         # GSD 执行产物
  review: .loop/reviews.md           # gstack /review + /cso 记录
  qa: .loop/qa-report.md             # gstack /qa 报告
  ship: .loop/ship-log.md            # 发布流水线记录
  retro: .loop/learnings.yaml        # 复盘教训
learnings: .loop/learnings.yaml
gaps: .loop/gaps.yaml
history:                    # 每轮宏观循环的摘要
  # - { iteration: 1, completed: <ISO>, retro_summary: "...", next_seed: "..." }
```

phase_map（7 个 Phase，对应文档 Phase 1-7）：
- 1 = 构想（ideate）
- 2 = 设计（design：规格 + 三重审核）
- 3 = 实施（build：讨论→规划→执行）
- 4 = 质量保证（qa：审查 + QA + 验收）
- 5 = 发布（ship）
- 6 = 迭代（iterate：里程碑归档 + retro）
- 7 = 项目管理（manage：横切工具，不强制经过）

step_map（Phase 内的细分步骤）：
ideate / spec / design / replicate / design-consult / design-ui / discuss / plan / execute / review / cso / qa / verify / ship / canary / deploy / complete / retro

（v4 新增 design-consult = 前端参考+设计系统，design-ui = 前端设计变体+代码生成，位于 design 和 discuss 之间）
（v4.1 新增 replicate = 参考项目复刻（7步逆向工程），位于 design 和 design-consult 之间；reference_target 为空时跳过）
</state_schema>

<process>

<step name="read_state">
读取项目状态。如果 `.loop/STATE.yaml` 不存在：
```
未检测到 Loop Engineering 项目。运行 `/loop:init [项目名]` 初始化。
```
Exit。

存在则解析出：`current_phase`、`current_step`、`iteration`、`phase_status`、`blockers`。
</step>

<step name="safety_gates">
推进前必跑的检查（Gate 1-5）。**行为按运行模式区分**（v2 全自动哲学）：

- **--auto 模式（默认）**：Gate 命中时不直接停，而是**尝试自动解决**（blocker 自动清理、产物缺失自动补、QA/对抗失败自动修复）。只有自动解决失败（属硬障碍）才真停。
- **--interactive 模式**：保留 v1 行为，Gate 命中即 hard-stop 退出。
- 两种模式：`--force` 都跳过所有门（打印警告）。

**Gate 1: 未解决 blocker**
检查 `.loop/STATE.yaml` 中 `current_phase` 的 `blockers` 数组是否非空。
- --interactive：非空 → hard-stop 列出 blocker，Exit
- --auto：非空 → 分析每个 blocker，若可自动解决（如补文档、修命名、修单个 bug）则走 decide_best/auto_optimize 自动处理后清空 blocker；若属硬障碍（编译失败 3 轮无效）则 hard-stop

**Gate 2: 上一阶段产物缺失**
推进到 Phase N 前，检查 Phase N-1 的 `artifacts` 是否真存在磁盘。
- --interactive：缺失 → hard-stop 列出缺失产物，Exit
- --auto：缺失 → 尝试自动补齐（重跑产出该产物的工具，如缺 PLAN.md 则重跑 /gsd-plan-phase）；补齐失败则 hard-stop

**Gate 3: 验收未通过**
Phase 4→5 时，检查 `.loop/qa-report.md` 不含 `[FAIL]`/`严重`。
- --interactive：失败 → hard-stop，Exit
- --auto：失败 → 走 auto_optimize 自动修复 QA 失败项 + 重检；3 轮无效则 hard-stop

**Gate 4: 对抗检查未通过**
检查 `.loop/adversarial/last-verdict.json` 的 `passed`。
- --interactive：passed=false → hard-stop，Exit
- --auto：passed=false → 走 auto_optimize/debate（loop-adversarial.md 已有逻辑）；escalate 超限（属硬障碍）才 hard-stop

**Gate 5: loop 与 GSD 状态一致性**（v2 新增，修复素材 #4）
execute 推进前，读 GSD `.planning/STATE.md`，校验：
- GSD phase_status 与 loop current_step 一致（如 loop step=execute 时，GSD 该 phase 应是 planned/executing，不能是 not_started）
- GSD PLAN.md 存在（execute 前提）
不一致时：
- --auto：以 GSD 状态为准对齐 loop STATE.yaml（如 GSD 还在 plan，loop 回退 step=plan），自动重试推进
- --interactive：hard-stop 提示"两套状态机不一致，需人工对齐"

五道门全过（或 --auto 下自动解决成功） → 返回控制权给调用方。
</step>

<step name="update_state">
由调用方在完成某步后调用，更新状态。参数：
- `--step <step_name>`：标记当前步完成，current_step 前进
- `--phase <N>`：切换 phase
- `--blocker "<desc>"`：追加 blocker
- `--resolve-blocker`：清空当前 phase 的 blockers
- `--artifact "<path>"`：给当前 phase 追加产物路径
- `--next-iteration`：iteration +1，current_phase 重置为 1（retro 闭环）
- `--adversarial-passed <bool>`：记录对抗检查结果（true 时清空对抗相关 blocker；false 时由 loop-adversarial 的 escalate 设 blocker）
- `--adversarial-report <path>`：记录对抗检查报告路径
- `--decision "<json>"`：记录自动决策（--auto 模式下 decide_best 产生）到 `.loop/decisions.jsonl`
- `--mode auto|interactive`：记录/切换当前运行模式（写 STATE.yaml 的 mode 字段）

写回 `.loop/STATE.yaml`（保留注释和结构，原子写：先写 .tmp 再 rename）。
同时 append 一行到 `.loop/timeline.jsonl`：
```json
{"ts":"<ISO>","phase":<N>,"step":"<step>","event":"<advance|block|complete|iterate>","adversarial":"<pass|fail|skip|none>","mode":"<auto|interactive>"}
```
有 `--decision` 时，另 append 一行到 `.loop/decisions.jsonl`（格式见 loop-orchestrate.md decide_best）。
</step>

<step name="advance_loop">
**v3 新增：run_full_loop while 循环内的前进辅助。**

在 --auto 模式的 run_full_loop 循环里，每个环节的主工具（Skill() 调用）完成 + 对抗门通过后，调用本步骤前进到下一个 step：
1. 调 update_state（`--step <next_step>` + 必要时 `--phase <N>`）更新 STATE.yaml + timeline
2. **不触发 SlashCommand 自调用**（v3 核心区别：循环在 while 内 continue，不重新发起命令）
3. 返回控制权给 run_full_loop 的 while 循环顶部（重新 read_state 进入下一轮）

与 v2 的区别：v2 的 auto_chain 用 SlashCommand 自调用 `/loop:run --next --auto`（跨会话断链）；v3 的 advance_loop 只更新状态 + continue 循环（会话不断）。
</step>

</process>

<success_criteria>
- [ ] STATE.yaml 不存在时给出清晰的 init 提示并 exit
- [ ] Gate 1-5 按模式分行为（--auto 尝试自动解决，--interactive 命中即停）
- [ ] 产物完整性校验基于磁盘真实存在性，不轻信 STATE.yaml 的标记
- [ ] update_state 原子写（.tmp + rename），不破坏既有字段
- [ ] advance_loop 只更新状态+continue 循环，不触发 SlashCommand 自调用（v3）
- [ ] timeline.jsonl 每次状态变更都追加，形成可审计的循环轨迹
</success_criteria>
