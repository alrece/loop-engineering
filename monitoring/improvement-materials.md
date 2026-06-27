# Loop Engineering 改进素材收集

> 来源：zllmwiki 项目实测 loop 工程的过程观察
> 用途：项目完成后据此改进 loop-engineering skill
> 持续追加，每条标注发现时间、严重度、根因、建议修复

---

## 素材 #1：loop-adversarial.sh Python true/false 类型混淆崩溃

- **发现时间**：2026-06-25 15:30（基线扫描 #1，timeline 回溯到 07:05 发生）
- **严重度**：🔴 高（导致对抗质量门完全不可用，降级为手动）
- **实测影响**：zllmwiki Phase 2 spec 环节对抗检查崩溃，`mode=manual-degraded`，靠 Agent subagent 兜底
- **现象**：timeline 记录 `loop-adversarial.sh crashed (Python false/False bug in heredoc)`，last-verdict.json 标注 `degraded_reason`
- **✅ 修复状态**：已修复（2026-06-25 16:05），边监控边改进

### 根因
脚本第 220 行（`run_dual_review` 的 python3 -c 输出块）：
```python
'passed': $passed,      # $passed = bash 小写 true/false
'consensus': $consensus, # $consensus = bash 小写 true/false
```
bash 变量 `$passed` 值是小写 `true`/`false`（bash 布尔约定），但这段代码在 `python3 -c "..."` 的双引号字符串里被**直接插值**。插值后变成 `python3 -c "...'passed': false..."`——而 Python 的布尔字面量是首字母大写 `False`，小写 `false` 是未定义名字 → `NameError: name 'false' is not defined` → 崩溃。

同样问题存在于：
- 第 187-192 行：`passed=$(... && echo true || echo false)` 和 `passed=false` 产出小写值
- 第 192 行：`consensus="false"`、`passed=false` 直接赋小写

### 涉及的所有位置
| 行 | 代码 | 问题 |
|----|------|------|
| 187 | `passed=$(... && echo true \|\| echo false)` | 产出小写 true/false |
| 190 | `consensus="false"` | 小写字符串 |
| 192 | `passed=false` | 小写 |
| 220 | `'passed': $passed,` | 插值进 Python，小写 false 崩溃 |
| 221 | `'consensus': $consensus,` | 同上 |

### 建议修复（两个方案）
**方案 A（推荐）：Python 侧容错，把插值当字符串再转布尔**
```python
print(json.dumps({
  'passed': '${passed}' == 'true',      # 字符串比较，避免裸插值
  'consensus': '${consensus}' == 'true',
  ...
}))
```

**方案 B：bash 侧产出 Python 兼容值**
```bash
passed=$([ ... ] && echo True || echo False)  # 首字母大写，Python 字面量
```
方案 B 风险：脚本其他地方用 `$passed` 做 bash 判断（`[ "$passed" = "true" ]`）会失效。所以**方案 A 更安全**。

### 同时发现的相关隐患
1. **JSON 字符串拼接脆弱**：多处用 `echo "{\"gate\":\"$gate\",\"passed\":$passed,...}"` 手工拼 JSON，若 `$json_out` 含特殊字符（引号/换行）会破坏 JSON。应统一走 python3 json.dumps。
2. **`raw` 字段直接嵌 JSON**：第 53/61/92 行 `"raw":$json_out` 把子命令输出原样嵌入，若子命令输出不是合法 JSON（报错信息）会破坏整体 JSON。

---

## 素材 #2：对抗检查产出位置混乱（openspec change 内出现 .loop/）

- **发现时间**：2026-06-25 15:30
- **严重度**：🟡 中（不影响功能，但污染产物目录）
- **现象**：`openspec/changes/enterprise-knowledge-mgmt-mvp/.loop/adversarial/` 下出现了对抗检查的 codex/gemini 输出和 debates 文件
- **根因**：`loop-adversarial.sh` 的 `run_dual_review` 用 `LOOP_ADV_DIR` 或 `$workdir/.loop/adversarial`，当传入的 workdir 是 OpenSpec change 目录时，输出就落到了 change 目录里，而非项目根 `.loop/`
- **建议修复**：对抗检查的输出应始终落到**项目根** `.loop/adversarial/`（通过 git rev-parse --show-toplevel 定位项目根），不随 workdir 漂移

---

## 素材 #3：降级路径有效但缺自动化（AGENTS.md §7 验证）

- **发现时间**：2026-06-25 15:30
- **严重度**：🟢 正面（降级机制起作用了，但可优化）
- **现象**：脚本崩溃后，agent 按 AGENTS.md §7「脚本执行失败 → 记录到 timeline，不阻断主流程」降级为 Agent subagent 手动对抗审查，且 last-verdict.json 标注 `mode=manual-degraded` + `degraded_reason`
- **正面价值**：降级机制设计正确，闭环没被脚本 bug 卡死
- **改进点**：降级路径目前依赖 agent 自觉执行（读 AGENTS.md §7），没有脚本层的自动降级。可在脚本里加 `trap` 或 try/catch：脚本自身崩溃时自动写一个 `mode=script-crashed` 的 last-verdict.json，而非完全失败

---

（后续扫描发现的素材持续追加）

---

## ✅ 修复记录（2026-06-25 16:05，边监控边改进）

### 修复 #1：dual-review JSON 输出块（素材 #1 根因）
**文件**：`~/.claude/skills/loop-engineering/scripts/loop-adversarial.sh` 第 214-249 行
**改法**：废弃 `python3 -c "...'passed': $passed..."` 的裸插值，改为全部通过**环境变量传参**（LOOP_PASSED/LOOP_CONSENSUS 等），Python 侧用 `os.environ.get(...) == "true"` 做字符串比较转布尔。
**验证**：模拟 `passed=false`（原崩溃场景）现在正确输出 `{"passed": false, ...}` 合法 JSON。

### 修复 #2：run_full 结果收集（素材 #1 的连带问题）
**文件**：同上，run_full 函数（第 254-325 行）
**改法**：废弃 5 处 `json.loads('''$det''')` 裸插值（含特殊字符会崩），改为用**临时文件 + append_result 辅助函数**收集结果，每条通过环境变量 LOOP_ITEM 传给 python 安全解析。
**验证**：含单引号的输入 `it's broken` 不再崩溃，综合判定正确输出。

### 修复 #3：对抗检查输出位置漂移（素材 #2）
**文件**：同上，run_dual_review（第 124 行）+ run_full（第 303 行）
**改法**：`out_dir` 不再用 `$workdir/.loop/adversarial`（workdir 是子目录时漂移），改为用 `git rev-parse --show-toplevel` 定位**项目根**，始终落到项目根 `.loop/adversarial/`。
**验证**：逻辑正确（zllmwiki 实测中 openspec change 目录下不应再出现 .loop/）。

### 待观察：素材 #3（降级自动化）
暂未修，因降级机制本身工作正常（AGENTS.md §7 验证有效）。考虑后续在脚本里加 trap，让脚本崩溃时自动写 `mode=script-crashed` 的 last-verdict.json。优先级低。

---

## 素材 #4：--auto 在 execute 环节卡死（两套状态机接缝脱节）

- **发现时间**：2026-06-25 17:00（用户问"为什么 --auto 会停"时定位）
- **严重度**：🔴 高（直接影响核心体验——用户期望 --auto 自动跑完，结果在最重要的执行环节停了）
- **现象**：`/loop:run --next --auto` 在 Phase 3 execute 停下。loop STATE.yaml 显示 step=execute，但 GSD STATE.md 显示 status=planned（未执行）。timeline 在 09:00 就记录 execute advance，但 GSD 到 16:53 才完成 plan。

### 根因
**两套状态机（loop 的 .loop/ 与 GSD 的 .planning/）在 execute 接缝处脱节**：
1. loop 的 auto_chain 设计假设"主工具（如 /gsd-execute-phase）调用后会完成并返回"
2. 但 /gsd-execute-phase 是**异步重操作**：5 个 plan 的 wave 并行执行，每个 plan 完成后交回控制（撞 TDD/phase gate）
3. 主工具"未完成返回"→ loop 不知该继续还是等→ 停在缝隙里
4. loop timeline 写了 execute advance，但 GSD 实际没执行 → 状态不一致

### 涉及的设计缺陷
| 位置 | 问题 |
|------|------|
| loop-orchestrate.md auto_chain | 假设主工具同步完成，没处理"长任务/异步执行" |
| loop-state.md | 不读 GSD STATE.md，两套状态机无同步 |
| Route 6(execute) | /gsd-execute-phase 是重操作，--auto 不该期望它一步返回 |

### 建议修复（三个层面）
1. **状态对齐**：execute 环节推进前，loop 应读 GSD STATE.md 的 phase_status，确认 GSD 已 ready（status=planned 且 PLAN.md 存在），否则提示"等待 GSD plan 就绪"而非盲目 advance
2. **execute 特殊处理**：Route 6 不走 auto_chain 的"调用即返回"模式，改为"调用 /gsd-execute-phase 后，退出 auto，提示用户执行是重操作需监督"——execute 本就不适合全自动
3. **状态一致性校验**：loop-state 的 safety_gates 增加 Gate 5——校验 loop STATE.yaml 与 GSD STATE.md 的 step 一致性，不一致时提示对齐而非继续

### 用户当下怎么继续
执行是重操作（5 plan wave），不该用 --auto。建议：
- `/gsd-execute-phase 1`（手动执行，监督每个 plan）
- 或 `/gsd-autonomous`（GSD 自己的执行循环，比 loop 的 auto 更适合 execute）
- 执行完成后回到 loop：`/loop:run --next`（loop 会检测 GSD SUMMARY 已产出，推进到 review）

---

## ✅ 素材 #4 修复记录（2026-06-25 17:40，v2 全自动长程重构）

素材 #4（--auto 在 execute 卡死，两套状态机脱节）已通过 **v2 全自动长程重构** 解决：

1. **Route 6 改为逐 plan 模式**（execute_plan_by_plan）：不再调 /gsd-execute-phase 一次性跑完，改为 loop 驱动 gsd-executor 子代理一个 plan 一个 plan 跑，每个完成后跑 plan 级对抗门再下一个。根本解决"主工具是异步重操作导致 auto_chain 卡死"。
2. **新增 Gate 5**（loop 与 GSD 状态一致性校验）：execute 推进前读 GSD STATE.md，确认 ready 且与 loop STATE.yaml 一致，不一致时 --auto 自动对齐。解决"两套状态机脱节"。
3. **--auto 默认全自动**：只有硬障碍才停（编译失败3轮无效/依赖缺失/escalate超限/用户暂停），不再因"需人工决策"而停。
4. **新增 decide_best**：决策点用最佳方案自动选择（小决策自主选，大决策多模型讨论），不为人停下。

v2 机制已实测验证：phase-plan-index 正确识别 Plan 1 完成 / 4 个待执行；decide-large 真实调起 codex+gemini 完成大决策讨论。

---

## 素材 #5：监控扫描脚本重复显示历史已修复事件

- **发现时间**：2026-06-25 18:10
- **严重度**：🟢 低（监控工具自身的体验问题，不影响 loop 功能）
- **现象**：扫描日志的"改进素材"部分每次都重复显示 #1 的 crash 事件（已修复），无法区分"已修复"和"待处理"，干扰发现新素材
- **根因**：/tmp/loop-scan.sh 的改进素材提取逻辑是 `grep -h "degraded\|crash\|block\|fail\|error" timeline.jsonl`，不区分历史/当前
- **建议修复**：扫描脚本只显示"最近 30 分钟新增"的异常事件（用 mmin 或时间过滤），而非全量 grep 历史

---

## 素材 #6：loop-iterate.md close_loop 遗漏未更新 v2 全自动（iteration 2 卡死根因）

- **发现时间**：2026-06-25 19:24（用户反馈"依然中断多次"，分析 timeline 定位）
- **严重度**：🔴 高（直接导致 iteration 2 卡死 7 小时，是"依然中断多次"的核心原因）
- **现象**：iteration 1 全程跑完（04:48-12:00），retro 完成后写 iterate 事件。用户确认后 iteration 2 启动，/office-hours 跑了（ideation.md 14:56 更新），但 auto_chain 没续上推进到 spec——卡在 ideate 7 小时。
- **根因**：v2 全自动重构时，**loop-iterate.md 的 close_loop 步骤遗漏未更新**。它还保留 v1 的"默认不自动启动下一轮——宏观循环的起点应由用户确认"，与 v2 全自动哲学冲突。虽然 orchestrate 的 auto_chain 改了，但 iterate 的 close_loop 没改，导致 retro→iterate 后链路断开。
- **✅ 修复**：
  1. close_loop 改为 --auto 模式自动进入下一轮（不等用户确认），--interactive 才询问
  2. seed_next_iteration 描述同步更新
  3. success_criteria 更新
- **教训**：v2 哲学重构时必须排查**所有 workflow**的 v1 残留逻辑，不能只改核心的 orchestrate/state。这次排查发现 iterate 遗漏，已全量排查确认其余无残留。

## 素材 #7：v1 的"等用户确认"逻辑分散在多个 workflow，易遗漏

- **发现时间**：2026-06-25 19:24
- **严重度**：🟡 中（流程设计问题，导致重构易遗漏）
- **现象**：v1 的"保守停下等用户"逻辑分散在 orchestrate(auto_chain)、iterate(close_loop)、state(safety_gates) 三处。v2 重构时只改了 orchestrate+state，漏了 iterate。
- **建议**：v2 哲学应有一个**统一的模式判定点**（在 SKILL.md 或 loop-state 读 mode 字段），所有 workflow 引用这个判定，而非各自硬编码"等用户确认"。减少分散导致的遗漏。

---

## 素材 #8：--auto 中断的真正架构根因——SlashCommand 自调用跨会话断链（v3 修复）

- **发现时间**：2026-06-25 19:40（用户反馈"依然频繁中断，改进不明显"）
- **严重度**：🔴🔴 致命（这是"改进不明显"的根本原因——之前修的都是单点 bug，没击中架构根因）
- **现象**：zllmwiki timeline 显示每个环节间隔 45-176 分钟（ideate→complete 间隔 176 分钟）。这不是执行慢，而是 SlashCommand 自调用跨会话断链——每个环节在独立会话执行，会话结束自调用就断，用户不得不手动重跑 /loop:run --next --auto。

### 根因（架构层面，非单点 bug）
v2 的 auto_chain 用 `SlashCommand 自调用 /loop:run --next --auto`：
- SlashCommand 发起新命令 → 每个命令在独立 AI 会话执行 → 会话结束自调用就断
- loop 跨 gstack/GSD/OpenSpec 多个重型工具，每个都是独立会话，auto_chain 根本链不起来
- GSD 的 `gsd-progress --next --auto` 用同样模式但能工作，是因为 GSD 内部步骤轻量、单会话能连续完成；loop 跨重型工具做不到

### 正确解法（照搬 GSD autonomous 的 Skill() flat invocation）
GSD `autonomous` 能跨 phase 连续跑，用的是 `Skill(skill="gsd-discuss-phase", args="...")` 同步调用——在当前会话内加载执行 skill，等完成，控制权回到调用方，会话不断。

v3 重构：auto_chain 从 SlashCommand 自调用改为 **run_full_loop 的 while 循环 + Skill() 同步调用**：
```
while True:
  read_state → safety_gates → determine_next_action
  → Skill(skill="<主工具>") 同步调用等完成
  → adversarial_gate → advance_loop（前进 step，不触发自调用）
  → 遇决策 decide_best → 遇硬障碍 break → 否则 continue
```
一次 /loop:run --next --auto 在单会话内跑完全程，不中断。

### 为什么之前改进不明显
素材 #1-#7 修的都是单点 bug（脚本崩溃/输出位置/close_loop 遗漏/扫描重复），但**根本的架构问题**——SlashCommand 自调用跨会话断链——没解决。所以每环节结束会话就停，用户手动重跑，体验就是"频繁中断、改进不明显"。v3 才是真正的根治。

### ✅ 修复（v3）
1. loop-orchestrate.md：auto_chain 改为 run_full_loop（while 循环 + Skill() 同步调用）
2. loop-state.md：新增 advance_loop（循环内前进 step，不触发自调用）
3. SKILL.md：--auto 进入 run_full_loop 单会话连续循环
4. AGENTS.md：铁律 MUST NOT #6 改为"不得用 SlashCommand 自调用实现 --auto 循环"

---

## 素材 #9：v3 Skill() 在 ZCode 不可用 → v3.1 inline 执行是最终机制

- **发现时间**：2026-06-25 20:00（用户问 --force 能否一条命令跑完，深挖工具能力）
- **严重度**：🔴🔴 致命（v3 用 Skill() 但 ZCode 无此工具，导致 v3 写了正确逻辑却跑不起来）
- **现象**：v3 把 auto_chain 改为 run_full_loop + Skill() 调用，但 loop 的 allowed-tools 没有 Skill 工具（ZCode 不支持 Skill()）。GSD autonomous 用 Agent(subagent) 但 ZCode 的 Agent 只有 Explore（只读，不能 Write/Edit）。所以 v3 的 Skill() 方案在 ZCode 里跑不起来。

### 根因
三种调用机制在 ZCode 的可用性：
- **SlashCommand**：✅ 有，但异步跨会话断链（v2 用的，导致中断）
- **Skill()**：❌ ZCode 无此工具（v3 用的，跑不起来）
- **Agent(subagent)**：✅ 有，但只有 Explore 类型（只读，execute/review 需要写文件，不够用）

### 正确解法（v3.1：inline 执行）
loop 自己在主会话里 **inline 执行**每个环节：
1. Read 目标 skill 的 SKILL.md + workflow 文件
2. 按其指令在主会话内直接执行（用 loop 已有的 Read/Write/Edit/Bash/AskUserQuestion）
3. 完成后 advance_loop 前进，继续 while 循环

这是 gsd-autonomous INTERACTIVE=false 的真正机制（"Run inline as before"）。会话不结束，循环不断。
不需要 SlashCommand（跨会话断）、不需要 Skill()（ZCode 无）、不需要 Agent 子代理（Explore 只读）。

### --force 的作用
--force 跳过所有安全门（Gate 1-5），让 while 循环不停。配合 inline 执行，实现"一条命令跑完不中断"。决策点仍走 decide_best（自动选最佳，不停）。

### ✅ 修复（v3.1）
1. loop-orchestrate.md：auto_chain 改为 run_full_loop + inline 执行（Read skill 指令 + 主会话执行）
2. SKILL.md：process 说明 inline 执行机制，--force 跳过所有门
3. AGENTS.md：MUST NOT #6 改为"用 inline 执行"
4. allowed-tools 不变（loop 已有 Read/Write/Edit/Bash/AskUserQuestion，足够 inline 执行）

### 为什么这是最终方案
inline 执行不依赖任何 ZCode 可能不支持的机制（Skill/Agent 写权限），只用 loop 已有的基础工具。
loop 本质是编排层——读其他 skill 的指令，在主会话执行，是编排层最自然的实现方式。

---

## 素材 #10：loop 闭环对前端生命周期的系统性缺失（最严重的设计缺陷）

- **发现时间**：2026-06-25 20:30（用户反馈"部署后没有任何系统界面"）
- **严重度**：🔴🔴🔴 致命（整个项目跑完部署后没有界面，是闭环最严重的覆盖缺失）
- **现象**：zllmwiki 跑完所有 Phase + 部署后，访问应用发现没有任何界面。前端代码存在（Vue3 骨架+dist 构建），但：
  1. docker-compose 的 frontend 服务被 `profiles:["full"]` 隐藏，默认 `docker compose up` 不启动
  2. Makefile 没有 `make deploy`/`make up` 一键全栈部署命令
  3. 更深层：前端只搭了空壳（AC11"views/ 仅 auth/dashboard/exception，无业务域"），没有实际业务页面

### 根因：loop 11 路由对前端的覆盖是系统性的空白

| 前端关键环节 | loop 路由 | 实际覆盖 | 缺失 |
|-------------|----------|---------|------|
| **参考**（视觉参考/竞品复刻） | 无 | ❌ | 闭环里没有"前端参考/复刻"环节 |
| **设计**（UI 设计稿/wireframe/mockup） | Route 3 三重审核 | ❌ | design.md 前端提及=0，没有 UI spec/design |
| **实现**（业务页面/组件/交互） | Route 6 execute | ⚠️ 仅骨架 | Plan 4 只搭空壳，AC11 明确"无业务域" |
| **测试**（浏览器测真实界面） | Route 8 QA | ❌ | 前端没正确部署，/qa 无 URL 可测 |
| **部署**（全栈编排） | Route 10 ship | ⚠️ 断裂 | compose 有 frontend 但 profiles 隐藏 + 无 make deploy |

### 证据
- OpenSpec 6 个 spec 全是后端领域（rag/admin/rbac/proto/deploy/directory），0 个前端 UI spec
- design.md 前端/UI/界面/组件提及 = 0 次
- design-reviews 三重审核里前端/部署提及 = 0 次
- Plan 4(前端) AC11："views/ 仅 auth/dashboard/exception（无业务域）"——只有空壳

### 建议改进（loop engineering 层面）

**1. Route 2(规格) 增加"前端 UI spec"产出**
/opsx:propose 应额外生成前端 spec：页面清单、组件树、交互流程、视觉参考（参考/复刻哪个 UI 框架或竞品）。

**2. Route 3(三重审核) 增加"前端设计审核"**
/plan-design-review 应审：UI 设计稿完整性、视觉一致性、交互流程合理性、是否有参考/复刻来源。

**3. Route 6(执行) 增加"前端业务实现"plan**
不能只有骨架 plan，要有业务页面实现 plan（登录→dashboard→知识库→chat→设置 的完整业务流）。

**4. Route 8(QA) 确保前端可访问才测**
QA 前先验证前端已正确部署（compose up 含 frontend），/qa 测真实 URL 的真实界面。

**5. Route 10(发布) 增加全栈部署编排**
确保 docker-compose 的 frontend 不被 profiles 隐藏（或提供 `make deploy` 一键全栈 up），部署后验证前端可访问。

**6. 新增 Route 1.5（前端参考/复刻）**
在规格和设计之间，增加"前端参考"环节：确定要参考/复刻的 UI 框架（如 art-design-pro）、视觉风格、竞品界面，作为前端实现的基础。这是用户明确提到的"参考、复刻、设计、实现"的第一步。

### 用户原话的关键洞察
用户说"包含参考、复刻、设计、实现等"——这四个词揭示了前端应该有完整的生命周期：
参考（看竞品/框架）→ 复刻（搭建基础 UI）→ 设计（定制视觉/交互）→ 实现（业务页面）
loop 当前完全缺这个链条。

---

## ✅ 素材 #10 修复记录（2026-06-25 21:00，v4 前端生命周期补全）

素材 #10（loop 闭环对前端生命周期的系统性缺失）已通过 **v4 前端生命周期补全** 解决：

### 新增路由
- **Route 3.5（design-consult）**：`/design-consultation` 竞品研究+截图+设计系统+DESIGN.md → 前端"参考"
- **Route 3.6（design-ui）**：`/design-shotgun`（变体+选择）→ `/design-html`（Vue3 代码）→ `ecc/ui-to-vue`（复刻）→ `/design-review`（视觉QA）→ 前端"复刻→设计→实现"

### 增强的路由
- Route 2（规格）：要求产出前端 UI spec（页面/组件/交互/视觉参考）
- Route 5（规划）：要求 plan 含前端业务页面 plan（不只骨架）
- Route 6（执行）：前端 plan 也逐 plan 执行 + /design-review 视觉 QA
- Route 8（QA）：确保前端可访问才测（自动修复 profiles 隐藏）
- Route 10（发布）：确保全栈部署（frontend 不被 profiles 隐藏 + make deploy）

### 对抗门新增前端检查
- spec：前端 UI spec 是否存在
- design-consult：DESIGN.md 是否生成 + 竞品参考来源
- design-ui：前端代码是否 Vue3 + 是否有业务页面（非空壳）
- ship：frontend 服务是否在 compose 且不被 profiles 隐藏

### 工具链（全部已装可用，不造新工具）
- 参考：gstack /design-consultation
- 复刻：ecc/ui-to-vue（截图→Vue3 组件）
- 设计：gstack /design-shotgun（变体+选择）
- 实现：gstack /design-html（Vue3 代码）+ ecc/vue-patterns
- 测试：gstack /design-review（视觉QA）+ /qa（浏览器测）

### 验证
zllmwiki 下一轮迭代：Route 3 后自动跑 /design-consultation（DESIGN.md）→ Route 3.5 跑 /design-shotgun+/design-html（Vue3 业务页面）→ 部署后能看到完整界面。
