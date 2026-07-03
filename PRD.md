# Loop Engineering — Product Requirements Document (PRD)

> Version: 1.2 (with Prompt Refinement v4.3)
> Status: Implemented
> Related docs: README.md (user guide), AGENTS.md (AI agent spec)

---

## 1. Product Positioning (产品定位)

**In one sentence**: Loop Engineering is a cross-tool orchestration layer that wires five tool families — gstack / OpenSpec / GSD / Superpowers / CCG — into a quality-assured, auto-looping engineering closed loop.

> **中文译注**：Loop Engineering 是一个跨工具编排层，把 gstack / OpenSpec / GSD / Superpowers / CCG 五大工具家族编排成带质量保障的、可自动循环的工程闭环。

**Core problem it solves**:
Each of these tools is powerful in its own right but they operate **independently** — gstack excels at review but doesn't execute, GSD excels at execution but doesn't cover ideation, OpenSpec writes specs but doesn't review them, CCG has adversarial-check capability but doesn't participate in flow orchestration. Users must manually switch between tools, manually decide which to invoke, and manually ensure quality — high cognitive load and easy to miss steps.

> **中文译注**：这些工具各自强大但各自为政——用户要手动在工具间切换、手动判断该用谁、手动保证质量，认知负担重且容易遗漏环节。

Loop Engineering strings them together along the "review / build / write / guard / adversarial" functional slices into an **automatically looping pipeline**, embedding a quality gate at each stage, so the user only needs `/loop:run --next --auto` to run the complete loop from ideation through release to retrospective.

---

## 2. Target Users & Scenarios (目标用户与场景)

**Target users**: Developers/teams using ZCode (OpenCode kernel) + the above tool families.

**Core scenarios**:
1. Starting a new project from scratch (ideation → delivery full flow)
2. "Which tool to use" decisions during multi-tool collaboration
3. Ensuring output quality at each stage (adversarial checks)
4. Cross-session / cross-milestone iterative closed loop
5. Interrupt recovery and progress dashboard

---

## 3. Core Capabilities (Implemented) (核心能力)

### Capability 1: Fully Autonomous Long-Horizon Closed Loop (v2 core) (能力 1：全自动长程闭环)
**Design philosophy**: Propose an idea → rough plan → run the entire project automatically (auto-selecting the best option at each decision point), only calling the user for verification at the end.
- `--auto` (default): fully autonomous, stops only on hard blockers (compilation failure after 3 ineffective rounds / missing dependencies / escalate exceeded / user pause)
- `--interactive` (optional): conservative mode, stops at every decision point (v1 behavior)
- 11 routes adjudicate the strongest tool per stage; execute runs plan-by-plan

| Route | Stage | Primary tool |
|-------|-------|--------------|
| 1 | Ideation | `/office-hours` |
| 2 | Spec | `/opsx:propose` |
| 3 | Design | Triple review (--auto auto-adjudicates disagreements, no stop) |
| 4-6 | Discuss/Plan/Execute | `/gsd-discuss/plan` + **plan-by-plan execution (gsd-executor)** |
| 7-9 | Review/QA/Acceptance | `/review`+`/cso` / `/qa` / `/gsd-verify-work` |
| 10 | Ship | `/ship`→`/canary`→`/land-and-deploy` |
| 11 | Iterate | `/gsd-complete-milestone` + retro (--auto auto-advances to next round) |

### Capability 2: Tiered Decision-Making (v2) (能力 2：分层决策)
- **Small decisions** (naming/params/implementation details/non-critical libs) → loop auto-selects best based on spec/context
- **Large decisions** (architecture/scope/critical dependencies/data models) → multi-model (codex+gemini analyzer) discussion before selecting
- All auto-decisions recorded to `.loop/decisions.jsonl` for user review at final verification

### Capability 3: State Machine / Dashboard (能力 3：状态机/看板)
- `.loop/STATE.yaml` cross-tool tracking + 5 safety gates (Gate 5 validates consistency with GSD state)
- `/loop:status` outputs the closed-loop dashboard
- 4 safety gates (Gate 1-4) prevent step-skipping / shipping-while-broken

### Capability 3: Iteration Loop (macro closed loop) (能力 3：迭代回环)
`/loop:retro` triggers: retro → lessons extraction → milestone audit → gap analysis → next-round seed. iteration +1, returns to ideation, forming a spiral iteration.

### Capability 4: Adversarial Quality Gate (v1.1 core enhancement) (能力 4：对抗性质量门)
After each stage produces output, executes "check → suggest → auto-optimize → re-check → advance only on pass":
- **Layer 1 Deterministic quality gate**: CCG verify-security/quality/change/module (machine-judged)
- **Layer 2 Multi-model adversarial review**: codeagent-wrapper parallel-invokes codex+gemini (bypasses config defect to connect directly, complementary perspectives)
- Auto-optimize + re-check (up to 3 rounds); on exceed, escalate and stop for user
- Multi-model disagreements generate adversarial discussion records

### Capability 5: Prompt Professionalization (v4.3) (能力 5：提示词专业化优化)
`/loop:refine` transforms a user's one-sentence requirement into a professional prompt, preventing vague requirements from causing downstream spec/plan/execute drift:
- **8-dimension deep analysis**: target users / core scenarios / tech stack / scale-performance / auth-security / priority-MVP / existing-code-constraints / acceptance-criteria
- **Dynamic follow-up questions**: generates 3-6 questions based on prompt precision, asks all in parallel via AskUserQuestion (no guessing missing dimensions)
- **Always generates three variants** for user to choose (agent does not choose for the user):
  - Standard (daily use, clear hierarchy, explicit execution order)
  - Compact (iterative dialogue, tight structure, fast dispatch)
  - High-constraint (AI Agent hardened: mandatory file-read list + auth-logic protection + existing-logic protection + quality-gate enforcement)
- **Cross-cutting tool**: independent of init, does not advance the loop (no change to current_phase/step), usable anytime
- Output `.loop/refined-prompt.md` can be read by `/office-hours` (Phase 1) as a starting point

> **中文译注**：能力 5 是 v4.3 新增的提示词优化器——把用户的一句话需求，通过 8 维度分析 → 动态追问 → 生成三套（标准/精简/高阶强约束）供用户选。横切工具，不依赖 init、不推进闭环。

---

## 4. Functional Requirements Detail (功能需求详述)

### FR-1: State Machine (loop-state.md)
- **FR-1.1** Read/write `.loop/STATE.yaml`, containing 7-Phase state, iteration, artifacts, history
- **FR-1.2** 4 safety gates: blocker check, artifact completeness, QA pass, adversarial check pass
- **FR-1.3** `--force` skips safety gates (with warning)
- **FR-1.4** timeline.jsonl audit log

### FR-2: Orchestration Routing (loop-orchestrate.md)
- **FR-2.1** 11 routes match by current_phase + current_step
- **FR-2.2** Conflict policy: unique adjudication per stage (planning uses gstack+OpenSpec, execution uses GSD, review uses gstack, ship uses gstack)
- **FR-2.3** `--auto` SlashCommand self-invocation loop, re-reads STATE.yaml each time

### FR-3: Adversarial Quality Gate (loop-adversarial.md + loop-adversarial.sh)
- **FR-3.1** Per-stage check-item config (see table below)
- **FR-3.2** Deterministic gate verdict: security/module trusts exit code; quality/change parsed from JSON by script
- **FR-3.3** Multi-model adversarial: parallel codex+gemini, bypasses config direct-connect, output isolation
- **FR-3.4** auto_optimize: consolidate suggestions → auto-fix → re-check, up to 3 rounds
- **FR-3.5** debate: on multi-model disagreement, generate discussion record; complementary perspectives form consensus, contradictory conclusions take conservative
- **FR-3.6** escalate: on exceed, set blocker and stop for user

**Per-stage check-item config**:

| Stage | Deterministic gate | Multi-model adversarial | Check target |
|-------|-------------------|------------------------|--------------|
| spec | verify-change | analyzer | openspec/changes/ |
| design | — | review design-reviews.md | review conclusions |
| plan | verify-module | review PLAN.md | PLAN.md |
| execute | security+quality+change | reviewer reviews git diff | code changes |
| review | security | compare with gstack conclusions | review consistency |
| ship | security+module | final review | full scope |

### FR-4: Iteration Loop (loop-iterate.md)
- **FR-4.1** `/gsd-complete-milestone` → `/retro` → `/gsd-extract-learnings` → `/gsd-audit-milestone`
- **FR-4.2** learnings.yaml + gaps.yaml append (no overwrite of history)
- **FR-4.3** Generate next-round seed, iteration +1, phase reset
- **FR-4.4** Does not auto-start next round by default (requires user confirmation)

### FR-5: Command Entry Points
- `/loop:init` / `/loop:status` / `/loop:run` / `/loop:adversarial` / `/loop:retro`

---

## 5. Non-Functional Requirements (非功能需求)

- **NFR-1 Upgrade immunity**: All files live in paths not managed by gstack/GSD/CCG, so upgrades don't overwrite them
- **NFR-2 No touching CCG**: Quality gate only invokes run_skill.js + codeagent-wrapper, never modifies config/prompts/commands
- **NFR-3 Model-switch compatible**: Script only calls `--backend codex/gemini`, regardless of underlying routing (cc-switch to deepseek-v4/qwen3.7-plus auto-compatible)
- **NFR-4 GSD style**: SKILL.md minimal, logic externalized to workflows, `@` include + `<step>` structure
- **NFR-5 Interruptible recovery**: State persisted to `.loop/`, supports cross-session resume

---

## 6. Success Criteria (成功标准)

- [x] 11 routes correctly adjudicate tools per stage
- [x] `--auto` chains forward and stops on blockers
- [x] 4 safety gates (including Gate 4 adversarial gate) take effect
- [x] Stages with output auto-run adversarial checks after producing
- [x] Adversarial check failure triggers auto-optimize + re-check (≤3 rounds)
- [x] Multi-model disagreements generate discussion records
- [x] `/loop:retro` completes the macro loop (lessons → seed → next round)
- [x] `/loop:status` dashboard accurately reflects state
- [x] All files on upgrade-immune paths

---

## 7. Boundaries (What It Does NOT Do) (边界)

- **Does NOT re-implement** any existing capability of gstack/GSD/OpenSpec/Superpowers
- **Does NOT replace** GSD's `.planning/`; it orchestrates on top
- **Does NOT touch** CCG config.toml / prompts / command files
- **Does NOT handle** same-source agents (user solves via cc-switch)
- **Does NOT re-implement** gstack /review or /cso (CCG adversarial layer is an independent multi-model perspective, complementary not conflicting)
- **Does NOT bundle** TDD/debugging (Superpowers guards automatically)

### v4.2 New Capability Boundaries (Frontend/Desktop Support) (v4.2 新增能力边界)

- **MUST do**:
  - Full frontend lifecycle coverage (reference → replicate → design → implement → test → deploy)
  - Desktop tech-stack auto-detection (Electron/Tauri/Wails/Flutter/Web)
  - Build verification gate ensuring frontend code compiles (npm run build / tauri build / wails build / flutter build)
  - Deploy config check ensuring frontend service not hidden by profiles
  - Vue3 business-page generation (design-html) + impeccable quality polish (21 sub-skills)
  - QA stage real-browser automation (Playwright testing real Vue3 SPA)

- **Does NOT**:
  - Generate desktop native code (Electron/tauri.conf.json config files still maintained by user)
  - Execute full Electron/tauri build (only runs `npm run build` + debug mode; production build still requires user to manually `tauri build`)
  - Replace Electron/Flutter official CLI (only invokes their build commands, not re-implementing)

> **中文译注**：v4.2 新增了前端/桌面端能力边界——必做项包括前端全生命周期覆盖、桌面端技术栈检测、构建验证门、Vue3 业务页面生成 + impeccable 品质打磨；不做项包括不生成桌面端原生配置、不执行完整生产构建、不替代官方 CLI。

---

## 8. Dependencies (依赖)

| Dependency | Purpose | Status |
|------------|---------|--------|
| gstack suite | Ideation/review/QA/security/deploy/retro | ✅ Ready |
| OpenSpec CLI + /opsx | Spec definition | ✅ Ready |
| GSD suite | Plan/execute/verify/milestone | ✅ Ready |
| Superpowers | TDD/debug auto-trigger | ✅ Ready |
| CCG verify-* | Deterministic quality gate | ✅ Ready |
| codeagent-wrapper + codex/gemini backends | Multi-model adversarial | ✅ Ready (better after cc-switch to true heterogeneous) |

---

## 9. Future Directions (演进方向)

- Support custom per-stage check-item config (let users tune which gates run at each stage)
- Adversarial-check history trend analysis (frequency of same-type issues across loops)
- Deeper two-way state sync with GSD `.planning/`
- Support teams partially skipping adversarial gates (trust mode)
