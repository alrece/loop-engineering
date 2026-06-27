<purpose>
Loop Engineering 的对抗性质量门。在闭环每个环节产出后，对产物做"检查 → 提建议 → 自动优化 → 重检 → 通过才进下一步"的对抗闭环，
提高 loop 循环的产出质量。

两层检查：
1. **确定性质量门**：调用 loop-adversarial.sh → CCG verify-* 脚本（安全/质量/变更/模块），机器判 pass/fail，快且可靠
2. **多模型对抗审查**：调用 loop-adversarial.sh → codeagent-wrapper 并行调 codex+gemini（绕过 config.toml 缺陷直连），异构视角捕捉盲点

这是 CCG"对抗性检查"能力在闭环里的落地——CCG 负责提供检查能力，loop 负责编排何时检查、发现问题后如何优化重检。
</purpose>

<required_reading>
@$HOME/.claude/get-shit-done/workflows/loop-state.md
</required_reading>

<gate_config>
各环节的检查项配置（与 loop-adversarial.sh 的 full 模式一致）：

| 环节(step) | 确定性门 | 多模型对抗 | 检查对象 |
|------------|---------|-----------|---------|
| spec(规格) | verify-change(--mode staged) | codex/gemini analyzer | openspec/changes/ + **前端 UI spec 是否存在**（页面/组件/交互/视觉参考） |
| design(设计) | —（无确定性门） | codex/gemini 审 design-reviews.md | 审核结论 |
| **design-consult**(前端参考) | — | codex/gemini 审 DESIGN.md | **DESIGN.md 是否生成 + 是否有竞品参考来源** |
| **design-ui**(前端设计) | — | codex/gemini 审前端代码 | **design-html 是否产出前端代码 + 是否 Vue3 框架 + 是否有业务页面（非空壳）** |
| plan(规划) | verify-module .planning/ | codex/gemini 审 PLAN.md | PLAN.md + **是否含前端业务页面 plan（不只骨架）** |
| execute(执行) | verify-security + verify-quality + verify-change | codex/gemini reviewer 审 git diff | **plan 级** + 前端 plan 额外跑 `/design-review`（视觉 QA） |
| review(审查) | verify-security | 对比 gstack /review 与多模型结论 | 审查一致性 |
| ship(发布前) | verify-security + verify-module | codex/gemini 终审 | 全量 + **前端服务是否在 compose 且不被 profiles 隐藏 + 有 make deploy** |

**execute 环节是 plan 级检查**（v2 逐 plan 模式）：loop-orchestrate 的 execute_plan_by_plan 每跑完一个 plan，对该 plan 的 git diff 范围（`git diff <plan起始commit>..HEAD`）跑质量门，而非整个 phase。脚本 target_path 接受 plan 的文件范围或 commit 范围。

不检查的环节：ideate(构想, 无代码)、discuss(讨论, 无产物)、qa(浏览器测试由 gstack /qa 负责)、verify(UAT 由 GSD 负责)、retro(复盘, 非产出)。
这些环节质量由各自的主工具保障，不需要对抗层。
</gate_config>

<decide_large>
**大决策多模型讨论**（v2 新增，供 loop-orchestrate 的 decide_best 调用）。

当 loop 遇到大决策（架构方向/范围增减/关键依赖/数据模型/安全策略）时，调用：
```bash
~/.claude/skills/loop-engineering/scripts/loop-adversarial.sh decide-large "<决策描述>" "<context_path>"
```
脚本并行调 codex+gemini analyzer 角色，让两模型各自给出方案 + 理由，输出：
```json
{
  "consensus": true|false,
  "choice": "<共识方案或综合方案>",
  "reason": "<选择理由>",
  "codex": {"proposal": "...", "reason": "..."},
  "gemini": {"proposal": "...", "reason": "..."}
}
```
- consensus=true：两模型方案一致，直接采用
- consensus=false：两模型方案不同，取综合（合并两者优点）或取更保守的，记录分歧
loop 的 decide_best 据此执行，并记录到 decisions.jsonl。
</decide_large>

<process>

<step name="run_gate">
对当前环节产出跑对抗检查。调用脚本：

```bash
# 完整质量门（确定性 + 多模型），自动按环节配置选检查项
~/.claude/skills/loop-engineering/scripts/loop-adversarial.sh full "$STEP" "$TARGET_PATH" "$GIT_REF"
```
- `$STEP`：当前环节（spec/design/plan/execute/review/ship）
- `$TARGET_PATH`：检查对象路径（默认项目根或 .planning/）
- `$GIT_REF`：多模型审查的 diff 基准（默认 HEAD）

脚本输出 JSON 到 stdout，并写 `.loop/adversarial/last-verdict.json`：
```json
{
  "passed": true|false,
  "gates": [
    {"gate": "security", "passed": true, "raw": {...}},
    {"gate": "dual-review", "passed": true, "consensus": true, "codex": {...}, "gemini": {...}}
  ]
}
```
</step>

<step name="evaluate">
读 last-verdict.json 判定：

**情况 A：passed=true**
更新 STATE（loop-state 的 update_state --adversarial-passed true），放行进入下一步。

**情况 B：passed=false**
进入 auto_optimize 循环。先区分失败原因：
- **确定性门 fail**（security/quality/module）：有明确的 findings（漏洞/复杂度超标/缺文档），进入 auto_optimize
- **多模型分歧**（disagreements>0）：consensus=false，生成对抗讨论记录，进入 debate
- **多模型共识 fail**（consensus=true 但 RECOMMENDATION≠PASS）：两模型都认为有问题，进入 auto_optimize
</step>

<step name="auto_optimize">
**自动优化+重检循环**（对应"自动优化+重检"决策）。最多 MAX_RETRY=3 轮。

每轮：
1. **综合建议**：确定性门的 findings（每条带 file_path + recommendation）+ 两模型审查的 Suggestions/Critical Issues → 合并为优化清单
2. **生成优化方案**：为每个问题给出具体修复（改哪行、补什么文档、修什么规格）
3. **自动应用**：按问题类型调对应手段：
   - 安全漏洞/代码问题 → 直接修代码（Edit）
   - 缺文档 → 生成 README.md/DESIGN.md（verify-module 要求）
   - 复杂度超标 → 重构拆分函数
   - 规格问题 → 修正 OpenSpec specs
4. **重检**：再跑一次 run_gate（同 step）

**重检通过**（passed=true）→ 跳出循环，update_state --adversarial-passed true，进下一步。
**重检仍 fail 且已达 MAX_RETRY** → 进入 escalate。
</step>

<step name="debate">
**对抗讨论**（多模型分歧时触发）。

读脚本生成的 `.loop/adversarial/debates/{ts}.md`（含两模型各自观点 + 分歧点）。
关键分歧的处理：
- 如果分歧是**视角互补**（如 codex 关注后端安全，gemini 关注前端 a11y，各自发现不同问题）→ 两者建议都采纳，合成完整优化清单，回到 auto_optimize
- 如果分歧是**结论矛盾**（如同一处代码一个说 PASS 一个说 FAIL）→ 综合判断：
  - 取更保守的结论（有疑虑就改）
  - 或结合确定性门的结果做仲裁（确定性门说了算）
- 生成的讨论记录供追溯，但不自动通过——需在 escalate 确认
</step>

<step name="escalate">
**升级到人工**（重检超限或无法自动决断的分歧）。

调用 loop-state 的 update_state --blocker "<对抗检查未通过: {原因}>"。
显示：
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
不自动推进，等用户处理 blocker。
</step>

</process>

<conflict_note>
本对抗层与各阶段主工具**并存不冲突**，不违反"按阶段唯一裁决"原则：
- 主工具负责**产出**（gstack 写审核结论、GSD 写代码、OpenSpec 写规格）
- CCG 对抗层负责**审查产出**（多视角挑刺、确定性门把关）
两者职责不同：一个是"做"，一个是"查"。这与 gstack 的 /review（gstack 自己审自己的产出）不重复——
CCG 对抗层提供的是**独立的多模型视角**，补充 gstack 单一视角的盲区。
</conflict_note>

<success_criteria>
- [ ] run_gate 按 gate_config 正确选检查项（不漏不多）
- [ ] 确定性门 fail 时，findings 带明确的 file_path + recommendation
- [ ] auto_optimize 最多 3 轮，每轮都重检（不假优化）
- [ ] 多模型分歧生成 debates/{ts}.md，视角互补则合议、结论矛盾则取保守
- [ ] 重检通过才放行；超限 escalate 并设 blocker
- [ ] last-verdict.json 每次检查都更新，供 loop-state Gate 4 读取
- [ ] 不修改 CCG 任何文件，只调 run_skill.js + codeagent-wrapper
</success_criteria>
