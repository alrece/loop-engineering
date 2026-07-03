<purpose>
The iteration loop of Loop Engineering (reinforces documented Phase 6). This is the most critical outer closed loop of the entire system:
deliver → retrospective → lessons → next-round ideation. It takes the retro's output, lesson extraction, milestone audit, and the gap against the original intent,
distills them into reusable assets, and auto-generates the seed for the next iteration round.

<!-- 中文译注：迭代回环（强化文档 Phase 6）——整个系统最关键的外层闭环：交付→复盘→经验→下一轮构想；把 retro 产出、教训提取、里程碑审计、与原始意图的差距沉淀为可复用资产，并自动生成下一轮迭代的种子。 -->
</purpose>

<required_reading>
@$HOME/.claude/get-shit-done/workflows/loop-state.md
</required_reading>

<process>

<step name="retrospective">
First ensure the milestone has been archived. If `.loop/STATE.yaml`'s current_phase is still ship/complete of phase 5 or 6:
first call `/gsd-complete-milestone` (archive + tag), then continue.

Then call `/retro` (gstack engineering retrospective, identifying improvement points).
The retro's conversational output is produced jointly by the user/model; this step is responsible for structurally extracting the key conclusions:
- What went well (keep)
- What to improve (improve)
- What to try next time (try)
<!-- 中文译注：retrospective——先确保里程碑已归档（current_phase 还是 5/6 的 ship/complete 则先 /gsd-complete-milestone 归档+打 tag 再继续）；然后调 /retro（gstack 工程回顾识别改进点）；把关键结论结构化抽取：做得好的(keep)/要改进的(improve)/下次想试的(try)。 -->
</step>

<step name="extract_learnings">
Call `/gsd-extract-learnings` (GSD extracts decisions/lessons/patterns).
Merge the output with the previous step's retro conclusions and write to `.loop/learnings.yaml` (append, do not overwrite history):

```yaml
- iteration: <N>
  date: <ISO>
  milestone: <里程碑名>
  decisions: [<关键架构/范围决策>]
  lessons:
    - { kind: keep|improve|try, text: "<内容>", source: "retro|gsd" }
  patterns: [<可复用的工程模式>]
```
<!-- 中文译注：extract_learnings——调 /gsd-extract-learnings（提取决策/教训/模式）；把产出与 retro 结论合并写入 .loop/learnings.yaml（追加不覆盖历史）；下面 YAML 代码块保留原文。 -->
</step>

<step name="audit_against_intent">
Call `/gsd-audit-milestone` (audits completion against the original intent).
Write the gap of "planned vs actually delivered" to `.loop/gaps.yaml` (append):

```yaml
- iteration: <N>
  date: <ISO>
  intended: [<原始规格/ROADMAP 意图>]
  delivered: [<实际交付>]
  gaps:
    - { severity: 严重|重要|次要, item: "<差距描述>", root_cause: "<根因>" }
  coverage_pct: <N>
```
This is the key feedback back to the starting point: gaps directly determine whether the next round needs to make up work and what to change.
<!-- 中文译注：audit_against_intent——调 /gsd-audit-milestone（对比原始意图审计完成度）；把"计划做什么 vs 实际交付"差距写入 .loop/gaps.yaml（追加）；gaps 直接决定下一轮要不要补做、要改什么——这是反馈回起点的关键。 -->
</step>

<step name="seed_next_iteration">
Based on learnings + gaps, generate the seed for the next iteration round (under --auto mode it auto-starts the next round; see close_loop):

```
## 第 {N} 轮迭代回顾完成

**复盘要点：**
{learnings 摘要，3-5 条}

**与原始意图的差距：**
{gaps 摘要，按严重度}

**下一轮建议种子：**
基于本轮 gaps 和未完成的 try 项，下一轮 /office-hours 应聚焦：
  1. {gap 1 转化的新需求}
  2. {未完成的 try 项}
  3. {retro 的 improve 项}

把这些写入 `.loop/STATE.yaml` 的 history[{N}].next_seed，供下一轮 ideate 读取。
```
<!-- 中文译注：seed_next_iteration——基于 learnings+gaps 生成下一轮迭代种子；下一轮 /office-hours 应聚焦 gap 转化的新需求+未完成的 try 项+retro 的 improve 项；写入 STATE.yaml 的 history[{N}].next_seed 供下一轮 ideate 读取。 -->
</step>

<step name="close_loop">
Invoke loop-state's update_state (`--next-iteration`):
- iteration += 1
- current_phase reset to 1 (Ideation)
- current_step reset to ideate
- history appends this round's summary + next_seed
- clear phase_status's artifacts (keep the status: done marker as history)

**--auto mode (v2 fully autonomous, default)**: after retro completes, **auto-enter the next round**, without waiting for user confirmation.
Immediately self-invoke `/loop:run --next --auto` via SlashCommand to start a new round from /office-hours.
The loop continues until all milestones are done (next_seed empty or the user explicitly pauses).

```
✅ 第 {N} 轮闭环完成，自动进入第 {N+1} 轮。
   种子：{next_seed 摘要}
   （--auto 模式：自动继续，无需确认）
```

**--interactive mode**: retains v1 behavior; asks the user to confirm before entering the next round:
```
闭环完成。是否进入第 {N+1} 轮迭代？
  是 → `/loop:run --next --auto`（自动从 /office-hours 开始新一轮）
  否 → `/loop:status`（查看历史循环记录）
```

**Stop condition**: next_seed is empty (no next-round goal) or a user pause is detected → stop the auto-loop and prompt the user to verify.
<!-- 中文译注：close_loop——调 update_state --next-iteration：iteration+1、current_phase 重置为 1（构想）、current_step 重置为 ideate、history 追加本轮摘要+next_seed、清空 artifacts（保留 done 标记为历史）；--auto 模式 retro 完成后自动进下一轮不等用户确认，立即 SlashCommand 自调用 /loop:run --next --auto 从 /office-hours 开始新一轮，循环继续直到所有里程碑跑完；--interactive 保留 v1 行为询问用户确认才进下一轮；停止条件 next_seed 为空或检测到用户暂停→停止自动循环提示用户验证。 -->
</step>

</process>

<success_criteria>
- [ ] First /gsd-complete-milestone to archive, then /retro; order correct.
- [ ] learnings.yaml appends rather than overwrites, preserving the accumulation of lessons across historical loops.
- [ ] gaps.yaml records the intent-vs-delivered gap, as input for the next round.
- [ ] next_seed is generated based on gaps + unfinished try items, closing the loop back to ideation.
- [ ] iteration auto-increments; phase resets to 1.
- [ ] --auto mode: auto-enters the next round (no user confirmation); --interactive mode: waits for user confirmation.
- [ ] The whole loop calls gstack (retro) + GSD (extract-learnings, audit-milestone); does not rebuild capabilities.
<!-- 中文译注：成功标准——先 /gsd-complete-milestone 归档再 /retro 顺序正确；learnings.yaml 追加不覆盖保留历史教训积累；gaps.yaml 记录意图 vs 交付差距作下一轮输入；next_seed 基于 gaps+未完成 try 项生成闭环回构想；iteration 自增 phase 重置为 1；--auto 自动进下一轮不等用户，--interactive 等用户确认；整个回环调 gstack(retro)+GSD(extract-learnings,audit-milestone)不重造能力。 -->
</success_criteria>
