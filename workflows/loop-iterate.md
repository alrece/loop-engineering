<purpose>
Loop Engineering 的迭代回环（强化文档 Phase 6）。这是整个系统最关键的外层闭环：
交付 → 复盘 → 经验 → 下一轮构想。把 retro 的产出、教训提取、里程碑审计、与原始意图的差距，
沉淀为可复用的资产，并自动生成下一轮迭代的种子。
</purpose>

<required_reading>
@$HOME/.claude/get-shit-done/workflows/loop-state.md
</required_reading>

<process>

<step name="retrospective">
先确保里程碑已归档。若 `.loop/STATE.yaml` 的 current_phase 还是 5 或 6 的 ship/complete：
先调用 `/gsd-complete-milestone`（归档 + 打 tag），再继续。

然后调用 `/retro`（gstack 工程回顾，识别改进点）。
retro 的对话产出由用户/模型共同完成，本步骤负责把关键结论结构化抽取出来：
- 做得好的（keep）
- 要改进的（improve）
- 下次想试的（try）
</step>

<step name="extract_learnings">
调用 `/gsd-extract-learnings`（GSD 提取决策/教训/模式）。
把产出与上一步的 retro 结论合并，写入 `.loop/learnings.yaml`（追加，不覆盖历史）：

```yaml
- iteration: <N>
  date: <ISO>
  milestone: <里程碑名>
  decisions: [<关键架构/范围决策>]
  lessons:
    - { kind: keep|improve|try, text: "<内容>", source: "retro|gsd" }
  patterns: [<可复用的工程模式>]
```
</step>

<step name="audit_against_intent">
调用 `/gsd-audit-milestone`（对比原始意图审计完成度）。
把"计划做什么 vs 实际交付"的差距写入 `.loop/gaps.yaml`（追加）：

```yaml
- iteration: <N>
  date: <ISO>
  intended: [<原始规格/ROADMAP 意图>]
  delivered: [<实际交付>]
  gaps:
    - { severity: 严重|重要|次要, item: "<差距描述>", root_cause: "<根因>" }
  coverage_pct: <N>
```
这是反馈回到起点的关键：gaps 直接决定下一轮要不要补做、要改什么。
</step>

<step name="seed_next_iteration">
基于 learnings + gaps，生成下一轮迭代的种子（--auto 模式下自动启动下一轮，见 close_loop）：

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
</step>

<step name="close_loop">
调用 loop-state 的 update_state（`--next-iteration`）：
- iteration += 1
- current_phase 重置为 1（构想）
- current_step 重置为 ideate
- history 追加本轮摘要 + next_seed
- 清空 phase_status 的 artifacts（保留 status: done 标记作为历史）

**--auto 模式（v2 全自动，默认）**：retro 完成后**自动进入下一轮**，不等用户确认。
立即通过 SlashCommand 自调用 `/loop:run --next --auto` 从 /office-hours 开始新一轮。
循环继续，直到所有里程碑跑完（next_seed 为空或用户显式暂停）。

```
✅ 第 {N} 轮闭环完成，自动进入第 {N+1} 轮。
   种子：{next_seed 摘要}
   （--auto 模式：自动继续，无需确认）
```

**--interactive 模式**：保留 v1 行为，询问用户确认才进下一轮：
```
闭环完成。是否进入第 {N+1} 轮迭代？
  是 → `/loop:run --next --auto`（自动从 /office-hours 开始新一轮）
  否 → `/loop:status`（查看历史循环记录）
```

**停止条件**：next_seed 为空（无下一轮目标）或检测到用户暂停 → 停止自动循环，提示用户验证。
</step>

</process>

<success_criteria>
- [ ] 先 /gsd-complete-milestone 归档，再 /retro，顺序正确
- [ ] learnings.yaml 追加而非覆盖，保留历史循环的教训积累
- [ ] gaps.yaml 记录意图 vs 交付差距，作为下一轮输入
- [ ] next_seed 基于 gaps + 未完成 try 项生成，闭环回到构想
- [ ] iteration 自增、phase 重置为 1
- [ ] --auto 模式：自动进入下一轮（不等用户确认）；--interactive 模式：等用户确认
- [ ] 整个回环调用 gstack(retro) + GSD(extract-learnings, audit-milestone)，不重造能力
</success_criteria>
