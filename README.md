# Loop Engineering 使用说明

> **全自动长程工程闭环**：提出想法 → 大致规划 → 自动跑完整个项目（决策点用最佳方案自动选择），最后才叫用户验证。
>
> 跨工具编排 gstack（看）/ OpenSpec（写）/ GSD（做）/ Superpowers（守）/ CCG（对抗检查+多模型），
> 每个有产出的环节嵌入对抗性质量门，execute 逐 plan 执行+检查。
> 保留 `--interactive` 可选的保守模式（撞决策就停）。

---

## 一、它是什么

Loop Engineering 是一个**编排层**，不重造已有工具的能力，而是把它们按最佳实践串成可循环的流水线，并在每个环节嵌入对抗性质量门：

```
构想 → 规格 → 设计(三重审核) → 讨论 → 规划 → 执行 → 审查 → QA → 验收 → 发布 → 复盘 → [下一轮]
 └─gstack   └─OpenSpec  └─gstack      └─GSD   └─GSD  └─GSD └─gstack└gstack└─GSD └─gstack
   ↓          ↓          ↓             ↓        ↓       ↓       ↓                 ↓
 [—]      [对抗门]    [对抗门]        [—]   [对抗门] [对抗门] [对抗门]   [—]         [—]    ← CCG 每环节检查
```

每个阶段调用**该阶段最强的工具**（遵循"按阶段唯一裁决"原则）。主工具负责**产出**，CCG 对抗层负责**审查产出**：

| 阶段 | 主工具（产出） | CCG 对抗门（审查产出） |
|------|---------------|----------------------|
| 构想 | gstack `/office-hours` | —（无代码，不检查） |
| 规格 | OpenSpec `/opsx:propose` | verify-change + codex/gemini analyzer |
| 设计 | gstack 三重审核 | codex/gemini 审审核结论 |
| 讨论/规划/执行 | GSD `/gsd-*` | verify-module/security/quality + 多模型 |
| 审查/QA | gstack `/review` `/cso` `/qa` | 多模型对比 gstack 结论一致性 |
| 验收 | GSD `/gsd-verify-work` | —（UAT 由 GSD 保障） |
| 发布 | gstack `/ship`→`/canary`→`/land-and-deploy` | verify-security + module + 终审 |
| 复盘 | gstack `/retro` + GSD 提取教训 | —（非产出，不检查） |

**核心理念**：两层职责分离——主工具"做"，CCG 对抗层"查"，不重复、不冲突。

---

## 二、快速开始

### 1. 初始化（每个项目一次）

```
/loop:init 我的项目名
```

创建 `.loop/` 状态目录：

```
.loop/
├── STATE.yaml            # 7-Phase 状态机（单一事实源）
├── learnings.yaml        # 跨循环的教训积累
├── gaps.yaml             # 意图 vs 交付的差距记录
├── timeline.jsonl        # 可审计的循环轨迹
└── adversarial/          # 对抗质量门记录
    ├── last-verdict.json #   最近一次检查判定（Gate 4 读这个）
    └── debates/          #   多模型分歧时的对抗讨论记录
```

### 2. 查看当前状态

```
/loop:status
```

输出闭环看板：当前 Phase、迭代轮次、各阶段产物、blocker、**对抗检查状态**、下一步建议。

### 3. 推进闭环

**全自动长程（默认，推荐）**：
```
/loop:run --next --auto
```
自动跑完整个项目：决策点用最佳方案自动选择（小决策自主选，大决策多模型讨论），execute 逐 plan 执行+检查，只有硬障碍才停。**项目跑完才叫你验证。**

**保守模式（可选）**：
```
/loop:run --next --interactive
```
撞决策/安全门就停，等人确认（v1 行为）。

---

## 三、五个命令速查

| 命令 | 用途 |
|------|------|
| `/loop:init [项目名]` | 初始化 `.loop/` 状态机 |
| `/loop:status` | 看闭环看板（只读） |
| `/loop:run [--next] [--auto\|--interactive]` | 推进闭环（默认 --auto 全自动） |
| `/loop:adversarial [step]` | 手动触发对抗检查 |
| `/loop:retro` | 触发迭代回环 |

### `/loop:run` 参数

| 参数 | 作用 |
|------|------|
| `--next --auto` | **默认**：全自动长程，跑到项目完成（决策点自动选最佳，只有硬障碍才停） |
| `--next --interactive` | 保守模式：撞决策/安全门就停，等人 |
| `--phase N` | 跳转到指定 Phase（先过安全门） |
| `--from N` | 从 Phase N 续跑（中断恢复） |
| `--force` | 跳过安全门（**慎用**） |

**硬障碍定义**（--auto 唯一真停点）：编译失败且 3 轮自动修复无效 / 关键依赖缺失无法绕过 / 对抗门 escalate 超限 / 用户暂停。

### `/loop:adversarial` 参数

| 参数 | 作用 |
|------|------|
| `(无)` / `auto` | 对当前环节产出跑完整对抗检查 |
| `spec`/`execute`/`ship`... | 指定环节 |
| `--debate` | 强制记录两模型各自观点 |
| `--deterministic-only` | 只跑确定性门（不调多模型，快） |

---

## 四、完整的 7-Phase 闭环

### Phase 1 — 构想
- **工具**：`/office-hours`（6 问深挖产品构想）
- **对抗门**：无（无代码产物）
- **产物**：`.loop/ideation.md`

### Phase 2 — 设计（规格 + 三重审核）
- **规格**：`/opsx:propose` → **对抗门**：verify-change + 多模型审 specs
- **三重审核**：`/plan-ceo-review` + `/plan-eng-review` + `/plan-design-review` → **对抗门**：多模型审审核结论
- **产物**：`openspec/changes/` + `.loop/design-reviews.md`

### Phase 3 — 实施（讨论→规划→执行）
- `/gsd:new-project` → `/gsd-discuss-phase` → `/gsd-plan-phase` → `/gsd-execute-phase`
- **规划对抗门**：verify-module + 多模型审 PLAN.md
- **执行对抗门**：verify-security + verify-quality + verify-change + 多模型审 git diff
- ⚙️ Superpowers 在执行时自动触发 TDD/调试
- **产物**：`.planning/PLAN.md` + SUMMARY

### Phase 4 — 质量保证
- `/review` + `/cso` → **对抗门**：多模型对比 gstack 结论一致性
- `/qa`（真实浏览器）→ `/gsd-verify-work`（UAT）
- ⛔ QA 未通过不会进入发布（安全门 Gate 3）

### Phase 5 — 发布
- `/ship` → `/canary` → `/land-and-deploy`
- **发布前对抗门**：verify-security + verify-module + 多模型终审
- **产物**：`.loop/ship-log.md`

### Phase 6 — 迭代（宏观回环）
- `/loop:retro` 触发：`/gsd-complete-milestone` → `/retro` → `/gsd-extract-learnings` → `/gsd-audit-milestone` → 生成下一轮种子
- `iteration += 1`，回到 Phase 1（闭环）

### Phase 7 — 项目管理（横切，按需）
- `/gsd-manager`、`/gsd-health`、`/gsd-stats` 等，不强制经过

---

## 五、对抗性质量门（核心增强）

这是闭环产出质量的保障。每个有产出的环节产出后自动执行"检查→优化→重检"循环。

### 两层检查

**第一层：确定性质量门**（CCG verify-* 脚本，快、可靠、机器判定）

| 门 | 检查内容 | 判定标准 |
|----|---------|---------|
| verify-security | SQLi/注入/密钥/XSS 等 18 类漏洞 | 0 个 critical+high 才 pass |
| verify-quality | 圈复杂度/函数长度/嵌套 | 复杂度>10 或函数>50行 才 fail（脚本二次判定，**不信 exit code**） |
| verify-change | 变更影响/文档同步 | 信息性提示（不阻断） |
| verify-module | README/DESIGN 齐全 | 缺文档才 fail |

**第二层：多模型对抗审查**（codeagent-wrapper 并行调 codex+gemini）
- 绕过 CCG config 缺陷直连（脚本直接 `--backend codex` + `--backend gemini`）
- 两模型各自独立审查，输出评分（TOTAL SCORE/100）+ 建议（PASS/NEEDS_IMPROVEMENT）
- codex 视角偏后端安全，gemini 视角偏前端 a11y —— 视角互补捕捉盲点

### 检查→优化→重检流程

```
产出 → 对抗检查
         ├─ 全通过 → 放行进下一步
         ├─ 确定性门 fail / 多模型共识 fail → auto_optimize
         │     综合建议 → 自动修复 → 重检（最多 3 轮）
         │     通过 → 放行 ｜ 仍 fail → escalate（设 blocker 停问人）
         └─ 多模型分歧 → debate
               视角互补 → 合议 → auto_optimize
               结论矛盾 → 取保守 + 确定性门仲裁 → 生成讨论记录
```

### 安全门（为什么 --auto 不会跑飞）

闭环有 **4 道** hard-stop 安全门，`--auto` 命中任一即停：

| 门 | 触发条件 | 意义 |
|----|---------|------|
| Gate 1 | 当前阶段有未解决 blocker | 强制人工处理 |
| Gate 2 | 上一阶段产物缺失 | 防止跳步空跑 |
| Gate 3 | QA 未通过却想发布 | 不让带病上线 |
| **Gate 4** | **对抗检查未通过** | **不让未通过对抗审查的产物进入下游** |

这是特性——在需要人工判断的节点主动停下，不无脑跑完。

### 按环节的对抗门配置（v4.2 新增前端/桌面端检查）

| 环节 | 确定性门 | 多模型对抗 | 检查对象 |
|------|---------|-----------|---------|
| spec（规格） | verify-change + frontend(spec) | analyzer | openspec/changes/ |
| design（设计） | — | 审 design-reviews.md | 审核结论 |
| plan（规划） | verify-module + frontend(design-ui) | 审 PLAN.md | PLAN.md |
| execute（执行） | security+quality+change + build | reviewer 审 git diff | 代码变更 |
| review（审查） | security | 对比 gstack 结论 | 审查一致性 |
| ship（发布前） | security+module + frontend(ship) + build | 终审 | 全量 |

**v4.2 新增检查项说明**：
- `frontend(spec)`：spec 阶段检查是否含前端 UI spec（关键词：ui/page/component）
- `frontend(design-ui)`：plan 阶段检查是否含前端业务页面实现 plan（不只骨架）
- `frontend(ship)`：ship 阶段检查 docker-compose.yml 的 frontend 服务不被 profiles 隐藏
- `build`：plan/ship 环节执行构建命令（npm run build / tauri build / wails build / flutter build），确保前端代码可编译
- `detect_app_type`：自动检测应用类型（Electron/Tauri/Wails/Flutter/Web），选择对应构建命令

---

## 六、典型工作流

### 场景 A：新项目从零开始
```
/loop:init 我的SaaS应用
/loop:run --next --auto          # 自动循环，每环节带对抗门
/loop:status                     # 看进行到哪
（解决 blocker 后）
/loop:run --next --auto          # 继续
```

### 场景 B：手动重跑某环节的对抗检查
```
/loop:adversarial execute        # 对执行产物重跑对抗门
/loop:adversarial --debate       # 强制记录两模型观点分歧
```

### 场景 C：中断恢复
```
/loop:status                     # 看在哪
/loop:run --from 3               # 从 Phase 3 续跑
```

### 场景 D：一轮交付完成，启动下一轮
```
/loop:retro                      # 复盘 + 教训 + 下一轮种子
/loop:run --next --auto          # 确认后新一轮从构想开始
```

---

## 七、状态文件说明

### `.loop/STATE.yaml`（核心）
```yaml
version: 1
project: 我的项目名
current_phase: 3          # 当前 Phase（1-7）
current_step: execute     # 当前步骤
iteration: 1              # 第几轮宏观循环
phase_status:
  1: { status: done, artifacts: [.loop/ideation.md] }
  3: { status: active, step: execute, blockers: [] }
artifacts:
  ideate: .loop/ideation.md
  spec: openspec/changes/
  planning: .planning/
history:
  # - { iteration: 1, completed: 2026-06-24, next_seed: "..." }
```

### `.loop/adversarial/last-verdict.json`（Gate 4 读这个）
```json
{
  "passed": false,
  "gates": [
    {"gate": "security", "passed": true},
    {"gate": "dual-review", "passed": false, "consensus": false, "disagreements": 1}
  ]
}
```

> `.loop/` 与 GSD 的 `.planning/` **并存不冲突**。所有文件都可安全 git 提交，团队共享。

---

## 八、与各工具家族的关系

```
┌──────────────────────────────────────────────────────────┐
│            Loop Engineering（编排层）                      │
│   .loop/STATE.yaml 状态 + 11 路由 + 对抗门 + 循环          │
└────┬──────────┬──────────┬──────────┬──────────┬────────┘
     │          │          │          │          │
 ┌───▼───┐ ┌───▼────┐ ┌───▼───┐ ┌────▼────┐ ┌───▼────┐
 │gstack │ │OpenSpec│ │ GSD   │ │Super-   │ │  CCG   │
 │ 看    │ │ 写     │ │ 做    │ │powers   │ │对抗+路由│
 │审核QA │ │规格    │ │规划执行│ │ 守      │ │质量门  │
 │部署   │ │        │ │       │ │TDD调试  │ │多模型  │
 └───────┘ └───────┘ └───────┘ └─────────┘ └────────┘
```

- **gstack**（看）：审核/QA/安全/部署 → loop 路由调用
- **OpenSpec**（写）：规格定义 → loop 在 Phase 2 调用
- **GSD**（做）：规划/执行/验证 → loop 在 Phase 3-4 调用
- **Superpowers**（守）：TDD/调试 → 执行时自动触发，loop 不显式调用
- **CCG**（对抗+路由）：每环节对抗审查 + 按需多模型

---

## 九、常见问题

**Q: 对抗检查需要 codex/gemini 后端，怎么配？**
A: 质量门脚本直接调 codeagent-wrapper（`--backend codex` + `--backend gemini`），不读 CCG config。用 cc-switch 把底层切到 deepseek-v4/qwen3.7-plus 后自动生效。

**Q: `--auto` 跑到一半停了怎么办？**
A: 看停止原因。多数是撞了安全门（含对抗门 Gate 4）或需人工决策。解决后 `/loop:run --next --auto` 继续。

**Q: 多模型分歧（debate）怎么处理？**
A: 视角互补（各发现不同问题）→ 自动合议继续优化；结论矛盾 → 取保守 + 确定性门仲裁，生成 `.loop/adversarial/debates/` 供追溯。

**Q: 和 GSD 的 `/gsd-autonomous` 区别？**
A: GSD autonomous 只管 GSD 内部循环；Loop Engineering 是跨工具全闭环（含对抗质量门 + 宏观迭代回环）。

**Q: 会和现有 `/gsd-*` `/review` 冲突吗？**
A: 不会。你可继续单独用任何命令，loop 只在显式跑 `/loop:*` 时介入。

---

## 十、文件位置

| 类型 | 路径 |
|------|------|
| Skill | `~/.claude/skills/loop-engineering/SKILL.md` |
| 质量门引擎 | `~/.claude/skills/loop-engineering/scripts/loop-adversarial.sh` |
| Workflows | `~/.claude/get-shit-done/workflows/loop-{state,orchestrate,iterate,adversarial}.md` |
| 命令 | `~/.zcode/commands/loop/{run,status,init,retro,adversarial}.md` |
| 项目状态 | `<项目根>/.loop/` |

所有文件在**升级免疫路径**（gstack/GSD/CCG 升级不覆盖）。

---

## 十一、最佳实践

1. **先 `/loop:status` 再推进** —— 看清楚再动
2. **关键阶段用单步 `--next`，机械阶段用 `--auto`** —— 审核类人工把控，执行类可放手
3. **每轮务必 `/loop:retro`** —— 闭环价值在于教训积累
4. **blocker 及时清理，别用 `--force`** —— 安全门（含对抗门）是保护，不是阻碍
5. **`.loop/` 纳入版本控制** —— 团队共享进度
6. **关注 `.loop/adversarial/debates/`** —— 多模型分歧记录是质量改进的信号
