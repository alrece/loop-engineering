# Loop Engineering — 产品需求文档（PRD）

> 版本：1.1（含对抗性质量门增强）
> 状态：已实现
> 关联文档：README.md（使用说明）、AGENTS.md（AI agent 规范）

---

## 一、产品定位

**一句话**：Loop Engineering 是一个跨工具编排层，把 gstack / OpenSpec / GSD / Superpowers / CCG 五大工具家族编排成带质量保障的、可自动循环的工程闭环。

**它解决的核心问题**：
这些工具各自强大但**各自为政**——gstack 擅长审核却不管执行、GSD 擅长执行却不覆盖构想、OpenSpec 写规格但不审查、CCG 有对抗检查能力却不参与流程编排。用户要手动在工具间切换、手动判断该用谁、手动保证质量，认知负担重且容易遗漏环节。

Loop Engineering 把它们按"看/做/写/守/对抗"的职能切片串成一条**自动循环的流水线**，并在每个环节嵌入质量门，让用户只需 `/loop:run --next --auto` 就能跑完从构想到发布再到复盘的完整闭环。

---

## 二、目标用户与场景

**目标用户**：使用 ZCode（OpenCode 内核）+ 上述工具家族的开发者/团队。

**核心场景**：
1. 从零启动新项目（构想→交付全流程）
2. 多工具协作时的"该用谁"决策
3. 保证每个环节产出质量（对抗检查）
4. 跨会话/跨里程碑的迭代闭环
5. 中断恢复与进度看板

---

## 三、核心能力（已实现）

### 能力 1：全自动长程闭环（v2 核心）
**设计哲学**：提出想法 → 大致规划 → 自动跑完整个项目（决策点用最佳方案自动选择），最后才叫用户验证。
- `--auto`（默认）：全自动，只有硬障碍才停（编译失败3轮无效/依赖缺失/escalate超限/用户暂停）
- `--interactive`（可选）：保守模式，撞决策就停（v1 行为）
- 11 路由按阶段唯一裁决调用最强工具，execute 走逐 plan 模式

| 路由 | 环节 | 主工具 |
|------|------|--------|
| 1 | 构想 | `/office-hours` |
| 2 | 规格 | `/opsx:propose` |
| 3 | 设计 | 三重审核（--auto 自动裁决分歧，不停） |
| 4-6 | 讨论/规划/执行 | `/gsd-discuss/plan` + **逐 plan 执行（gsd-executor）** |
| 7-9 | 审查/QA/验收 | `/review`+`/cso` / `/qa` / `/gsd-verify-work` |
| 10 | 发布 | `/ship`→`/canary`→`/land-and-deploy` |
| 11 | 迭代 | `/gsd-complete-milestone` + retro（--auto 自动进下一轮） |

### 能力 2：分层决策（v2 新增）
- **小决策**（命名/参数/实现细节/非关键库）→ loop 基于 spec/上下文自主选最佳
- **大决策**（架构/范围/关键依赖/数据模型）→ 调多模型（codex+gemini analyzer）讨论后选
- 所有自动决策记录到 `.loop/decisions.jsonl`，用户最后验证时可审查

### 能力 3：状态机/看板
- `.loop/STATE.yaml` 跨工具追踪 + 5 道安全门（Gate 5 校验与 GSD 状态一致性）
- `/loop:status` 输出闭环看板
- 4 道安全门（Gate 1-4）防止跳步/带病上线

### 能力 3：迭代回环（宏观闭环）
`/loop:retro` 触发：retro → 教训提取 → 里程碑审计 → 差距分析 → 下一轮种子。iteration +1，回到构想，形成螺旋迭代。

### 能力 4：对抗性质量门（v1.1 核心增强）
每个有产出的环节产出后，执行"检查→提建议→自动优化→重检→通过才进下一步"：
- **第一层 确定性质量门**：CCG verify-security/quality/change/module（机器判定）
- **第二层 多模型对抗审查**：codeagent-wrapper 并行调 codex+gemini（绕过 config 缺陷直连，视角互补）
- 自动优化+重检（最多 3 轮），超限 escalate 停问人
- 多模型分歧生成对抗讨论记录

---

## 四、功能需求详述

### FR-1：状态机（loop-state.md）
- **FR-1.1** 读写 `.loop/STATE.yaml`，含 7-Phase 状态、iteration、artifacts、history
- **FR-1.2** 4 道安全门：blocker 检查、产物完整性、QA 通过、对抗检查通过
- **FR-1.3** `--force` 可跳过安全门（带警告）
- **FR-1.4** timeline.jsonl 审计日志

### FR-2：编排路由（loop-orchestrate.md）
- **FR-2.1** 11 条路由按 current_phase + current_step 匹配
- **FR-2.2** 冲突策略：按阶段唯一裁决（规划用 gstack+OpenSpec，执行用 GSD，审查用 gstack，发布用 gstack）
- **FR-2.3** `--auto` SlashCommand 自调用循环，每次重读 STATE.yaml

### FR-3：对抗质量门（loop-adversarial.md + loop-adversarial.sh）
- **FR-3.1** 按环节配置检查项（见下表）
- **FR-3.2** 确定性门判定：security/module 信 exit code；quality/change 脚本二次解析 JSON
- **FR-3.3** 多模型对抗：并行 codex+gemini，绕过 config 直连，输出隔离
- **FR-3.4** auto_optimize：综合建议→自动修复→重检，最多 3 轮
- **FR-3.5** debate：多模型分歧时生成讨论记录，视角互补合议、结论矛盾取保守
- **FR-3.6** escalate：超限设 blocker 停问人

**各环节检查项配置**：

| 环节 | 确定性门 | 多模型对抗 | 检查对象 |
|------|---------|-----------|---------|
| spec | verify-change | analyzer | openspec/changes/ |
| design | — | 审 design-reviews.md | 审核结论 |
| plan | verify-module | 审 PLAN.md | PLAN.md |
| execute | security+quality+change | reviewer 审 git diff | 代码变更 |
| review | security | 对比 gstack 结论 | 审查一致性 |
| ship | security+module | 终审 | 全量 |

### FR-4：迭代回环（loop-iterate.md）
- **FR-4.1** `/gsd-complete-milestone` → `/retro` → `/gsd-extract-learnings` → `/gsd-audit-milestone`
- **FR-4.2** learnings.yaml + gaps.yaml 追加（不覆盖历史）
- **FR-4.3** 生成下一轮种子，iteration +1，phase 重置
- **FR-4.4** 默认不自动启动下一轮（需用户确认）

### FR-5：命令入口
- `/loop:init` / `/loop:status` / `/loop:run` / `/loop:adversarial` / `/loop:retro`

---

## 五、非功能需求

- **NFR-1 升级免疫**：所有文件在 gstack/GSD/CCG 不管理的路径，升级不覆盖
- **NFR-2 不碰 CCG**：质量门只调用 run_skill.js + codeagent-wrapper，不改 config/prompts/命令
- **NFR-3 兼容模型切换**：脚本只调 `--backend codex/gemini`，不管底层路由（cc-switch 切 deepseek-v4/qwen3.7-plus 自动兼容）
- **NFR-4 GSD 风格**：SKILL.md 极小，逻辑外置 workflow，`@` include + `<step>` 结构
- **NFR-5 可中断恢复**：状态持久化到 `.loop/`，支持跨会话续跑

---

## 六、成功标准

- [x] 11 路由正确按阶段唯一裁决调用工具
- [x] `--auto` 链式推进且遇 blocker 停止
- [x] 4 道安全门（含 Gate 4 对抗门）生效
- [x] 有产出的环节产出后自动跑对抗检查
- [x] 对抗检查未通过时自动优化+重检（≤3 轮）
- [x] 多模型分歧生成讨论记录
- [x] `/loop:retro` 完成宏观回环（教训→种子→下一轮）
- [x] `/loop:status` 看板准确反映状态
- [x] 所有文件在升级免疫路径

---

## 七、边界（不做什么）

- **不重造** gstack/GSD/OpenSpec/Superpowers 的任何已有能力
- **不替代** GSD 的 `.planning/`，而是在其上层编排
- **不碰** CCG config.toml / prompts / 命令文件
- **不处理** 同源代理（用户用 cc-switch 解决）
- **不重造** gstack /review 或 /cso（CCG 对抗层是独立多模型视角，互补不冲突）
- **不内置** TDD/调试（Superpowers 自动守）

### v4.2 新增能力边界（前端/桌面端支持）

- **必做**：
  - 前端生命周期完整覆盖（参考→复刻→设计→实现→测试→部署）
  - 桌面端技术栈自动检测（Electron/Tauri/Wails/Flutter/Web）
  - 构建验证门确保前端代码可编译（npm run build / tauri build / wails build / flutter build）
  - 部署配置检查确保 frontend 服务不被 profiles 隐藏
  - Vue3 业务页面生成（design-html）+ impeccable 品质打磨（21 子 skill）
  - QA 环节真实浏览器自动化（Playwright 测真实 Vue3 SPA）

- **不做**：
  - 不生成桌面端原生代码（Electron/tauri.conf.json 等配置文件仍需用户维护）
  - 不执行完整 Electron/tauri 构建（只跑 `npm run build` + debug 模式，生产构建仍需用户手动 `tauri build`）
  - 不替代 Electron/Flutter 官方 CLI（只调用其构建命令，不重造）

---

## 八、依赖

| 依赖 | 用途 | 状态 |
|------|------|------|
| gstack 套件 | 构想/审核/QA/安全/部署/复盘 | ✅ 已就绪 |
| OpenSpec CLI + /opsx | 规格定义 | ✅ 已就绪 |
| GSD 套件 | 规划/执行/验证/里程碑 | ✅ 已就绪 |
| Superpowers | TDD/调试自动触发 | ✅ 已就绪 |
| CCG verify-* | 确定性质量门 | ✅ 已就绪 |
| codeagent-wrapper + codex/gemini 后端 | 多模型对抗 | ✅ 已就绪（cc-switch 切真异构后更佳） |

---

## 九、演进方向（未来）

- 支持自定义环节检查项配置（让用户调整各环节跑哪些门）
- 对抗检查历史趋势分析（同类型问题跨循环出现的频率）
- 与 GSD `.planning/` 更深度的双向状态同步
- 支持部分团队跳过对抗门（trust mode）
