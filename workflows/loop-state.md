<purpose>
The state-machine core of Loop Engineering. It reads/writes `.loop/STATE.yaml`, detects which stage and step of the 7-Phase closed loop the project is in, and performs safety-gate checks.
Reused by loop-orchestrate and loop-iterate. This file only handles "state read/write + artifact-completeness validation"; it does NOT make routing decisions (routing is in orchestrate).

<!-- 中文译注：状态机核心——读写 .loop/STATE.yaml，检测当前处于 7-Phase 闭环哪个阶段/步骤，并跑安全门检查；被 loop-orchestrate 和 loop-iterate 复用；本文件只管"状态读写+产物完整性校验"，不做路由决策（路由在 orchestrate）。 -->
</purpose>

<required_reading>
Read all files referenced by the invoking skill's execution_context before starting.
<!-- 中文译注：开始前读调用 skill 的 execution_context 引用的所有文件。 -->
</required_reading>

<state_schema>
`.loop/STATE.yaml` is the single source of truth (under the project root); it coexists with GSD's `.planning/` without interfering. Structure:

<!-- 中文译注：.loop/STATE.yaml 是单一事实源（项目根目录下），与 GSD .planning/ 并存互不干扰。下面 YAML 代码块保留原文（含中文注释）。 -->

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
  refine: .loop/refined-prompt.md    # v4.3 /loop:refine 产出（提示词优化：原始/追问记录/三套/选定版）
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

phase_map (7 Phases, corresponding to documented Phase 1-7):
- 1 = Ideation (ideate)
- 2 = Design (design: spec + triple review)
- 3 = Implementation (build: discuss → plan → execute)
- 4 = Quality assurance (qa: review + QA + acceptance)
- 5 = Ship (ship)
- 6 = Iteration (iterate: milestone archive + retro)
- 7 = Project management (manage: cross-cutting tools, not mandatory to pass through)

<!-- 中文译注：phase_map——1 构想、2 设计（规格+三重审核）、3 实施（讨论→规划→执行）、4 质量保证（审查+QA+验收）、5 发布、6 迭代（里程碑归档+retro）、7 项目管理（横切工具不强制经过）。 -->

step_map (fine-grained steps within a Phase):
ideate / spec / design / replicate / design-consult / design-ui / discuss / plan / execute / review / cso / qa / verify / ship / canary / deploy / complete / retro

(v4 adds design-consult = front-end reference + design system, design-ui = front-end design variants + code generation, located between design and discuss.)
(v4.1 adds replicate = reference-project replication (7-step reverse engineering), located between design and design-consult; skipped when reference_target is empty.)

<!-- 中文译注：step_map——Phase 内细分步骤；v4 新增 design-consult（前端参考+设计系统）和 design-ui（前端设计变体+代码生成），位于 design 和 discuss 之间；v4.1 新增 replicate（参考项目复刻 7 步逆向工程），位于 design 和 design-consult 之间，reference_target 为空时跳过。 -->
</state_schema>

<process>

<step name="read_state">
Read the project state. If `.loop/STATE.yaml` does not exist:
```
未检测到 Loop Engineering 项目。运行 `/loop:init [项目名]` 初始化。
```
Exit.

If it exists, parse out: `current_phase`, `current_step`, `iteration`, `phase_status`, `blockers`.
<!-- 中文译注：read_state——读项目状态；STATE.yaml 不存在则提示 /loop:init 并 Exit；存在则解析出 current_phase/current_step/iteration/phase_status/blockers。 -->
</step>

<step name="safety_gates">
The mandatory checks before advancing (Gate 1-5). **Behavior is split by run mode** (v2 fully-autonomous philosophy):

- **--auto mode (default)**: on a gate hit, do NOT stop directly; instead **attempt auto-resolution** (auto-clear blockers, auto-fill missing artifacts, auto-fix QA/adversarial failures). Only stop for real if auto-resolution fails (a Hard Blocker).
- **--interactive mode**: retains v1 behavior; a gate hit → hard-stop exit.
- Both modes: `--force` skips all gates (prints a warning).

<!-- 中文译注：safety_gates——推进前必跑的检查（Gate 1-5），行为按模式区分：--auto Gate 命中时尝试自动解决（blocker 自动清理、产物缺失自动补、QA/对抗失败自动修复），只有自动解决失败（硬障碍）才真停；--interactive 保留 v1 行为 Gate 命中即 hard-stop；两种模式 --force 都跳过所有门（打印警告）。 -->

**Gate 1: Unresolved blocker**
Check whether the `blockers` array of `current_phase` in `.loop/STATE.yaml` is non-empty.
- --interactive: non-empty → hard-stop, list blockers, Exit.
- --auto: non-empty → analyze each blocker; if auto-resolvable (e.g. add docs, fix naming, fix a single bug) go through decide_best/auto_optimize to handle and clear the blocker; if a Hard Blocker (compile failure 3 rounds ineffective) → hard-stop.

**Gate 2: Previous-stage artifact missing**
Before advancing to Phase N, check whether Phase N-1's `artifacts` actually exist on disk.
- --interactive: missing → hard-stop, list missing artifacts, Exit.
- --auto: missing → attempt auto-fill (re-run the tool that produces that artifact, e.g. re-run /gsd-plan-phase if PLAN.md is missing); on fill failure → hard-stop.

**Gate 3: Acceptance not passed**
When going Phase 4→5, check that `.loop/qa-report.md` contains no `[FAIL]`/`severe`.
- --interactive: fail → hard-stop, Exit.
- --auto: fail → go through auto_optimize to auto-fix QA failures + re-check; on 3 rounds ineffective → hard-stop.

**Gate 4: Adversarial check not passed**
Check the `passed` field of `.loop/adversarial/last-verdict.json`.
- --interactive: passed=false → hard-stop, Exit.
- --auto: passed=false → go through auto_optimize/debate (loop-adversarial.md already has the logic); only hard-stop if escalate exceeds the limit (a Hard Blocker).

**Gate 5: loop-vs-GSD state consistency** (v2 new, fixing material #4)
Before advancing execute, read GSD's `.planning/STATE.md` and verify:
- GSD's phase_status is consistent with loop's current_step (e.g. when loop step=execute, GSD's phase should be planned/executing, not not_started).
- GSD's PLAN.md exists (a precondition for execute).
On inconsistency:
- --auto: treat GSD's state as authoritative and align loop STATE.yaml (e.g. if GSD is still in plan, roll loop back to step=plan), then auto-retry advancing.
- --interactive: hard-stop, prompt "the two state machines are inconsistent; manual alignment needed".

All five gates pass (or auto-resolution succeeds under --auto) → return control to the caller.
<!-- 中文译注：Gate 1 未解决 blocker（--interactive 非空 hard-stop，--auto 可自动解决则走 decide_best/auto_optimize 处理后清空，硬障碍才 hard-stop）；Gate 2 上一阶段产物缺失（--interactive hard-stop，--auto 尝试自动补齐）；Gate 3 验收未通过（--interactive hard-stop，--auto auto_optimize 修复+重检 3 轮无效则 hard-stop）；Gate 4 对抗检查未通过（--interactive hard-stop，--auto auto_optimize/debate escalate 超限才 hard-stop）；Gate 5 loop 与 GSD 状态一致性（execute 前读 GSD STATE.md 校验一致，--auto 以 GSD 为准对齐+重试，--interactive hard-stop）。五道门全过（或 --auto 自动解决成功）返回控制权。 -->
</step>

<step name="update_state">
Called by the caller after completing a step to update state. Parameters:
- `--step <step_name>`: mark the current step done, advance current_step.
- `--phase <N>`: switch phase.
- `--blocker "<desc>"`: append a blocker.
- `--resolve-blocker`: clear the current phase's blockers.
- `--artifact "<path>"`: append an artifact path to the current phase.
- `--next-iteration`: iteration +1, reset current_phase to 1 (retro close loop).
- `--adversarial-passed <bool>`: record the adversarial-check result (true clears adversarial-related blockers; false is set as a blocker by loop-adversarial's escalate).
- `--adversarial-report <path>`: record the adversarial-check report path.
- `--decision "<json>"`: record an automatic decision (produced by decide_best under --auto) to `.loop/decisions.jsonl`.
- `--mode auto|interactive`: record/switch the current run mode (writes STATE.yaml's mode field).

Write back to `.loop/STATE.yaml` (preserve comments and structure; atomic write: write .tmp first then rename).
Also append a line to `.loop/timeline.jsonl`:
```json
{"ts":"<ISO>","phase":<N>,"step":"<step>","event":"<advance|block|complete|iterate>","adversarial":"<pass|fail|skip|none>","mode":"<auto|interactive>"}
```
With `--decision`, also append a line to `.loop/decisions.jsonl` (format in loop-orchestrate.md decide_best).
<!-- 中文译注：update_state——由调用方完成某步后调用更新状态，参数含 step/phase/blocker/resolve-blocker/artifact/next-iteration/adversarial-passed/adversarial-report/decision/mode；写回 STATE.yaml（保留注释结构，原子写 .tmp+rename），追加 timeline.jsonl，有 --decision 另追加 decisions.jsonl。 -->
</step>

<step name="advance_loop">
**v3 new: the advance helper inside the run_full_loop while-loop.**
<!-- 中文译注：advance_loop——v3 新增，run_full_loop while 循环内的前进辅助。 -->

In the run_full_loop loop under --auto mode, after each stage's main tool (Skill() invocation) completes + the adversarial gate passes, call this step to advance to the next step:
1. Call update_state (`--step <next_step>` + `--phase <N>` if needed) to update STATE.yaml + timeline.
2. **Do NOT trigger SlashCommand self-invocation** (v3 core difference: the loop continues inside the while; it does not re-issue a command).
3. Return control to the top of run_full_loop's while-loop (re-read_state to enter the next round).

Difference from v2: v2's auto_chain used SlashCommand self-invocation of `/loop:run --next --auto` (breaks across sessions); v3's advance_loop only updates state + continues the loop (the session does not break).
<!-- 中文译注：--auto 模式 run_full_loop 循环里，每环节主工具完成+对抗门通过后调本步骤前进：1.调 update_state 更新 STATE.yaml+timeline；2.不触发 SlashCommand 自调用（v3 核心：循环在 while 内 continue，不重新发起命令）；3.返回 while 循环顶部（重 read_state 进下一轮）；与 v2 区别：v2 用 SlashCommand 自调用跨会话断链，v3 只更新状态+continue 会话不断。 -->
</step>

</process>

<success_criteria>
- [ ] When STATE.yaml does not exist, give a clear init prompt and exit.
- [ ] Gate 1-5 behavior split by mode (--auto attempts auto-resolution, --interactive stops on hit).
- [ ] Artifact-completeness validation is based on real on-disk existence, not trusting STATE.yaml's markers.
- [ ] update_state atomic write (.tmp + rename), without breaking existing fields.
- [ ] advance_loop only updates state + continues the loop; it does NOT trigger SlashCommand self-invocation (v3).
- [ ] timeline.jsonl is appended on every state change, forming an auditable loop trail.
<!-- 中文译注：成功标准——STATE.yaml 不存在给清晰 init 提示并 exit；Gate 1-5 按模式分行为；产物校验基于磁盘真实存在性不轻信标记；update_state 原子写不破坏字段；advance_loop 只更新状态+continue 不触发 SlashCommand 自调用（v3）；timeline.jsonl 每次状态变更追加形成可审计轨迹。 -->
</success_criteria>
