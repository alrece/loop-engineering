[English](./README.md) | [简体中文](./README.zh-CN.md)

# Loop Engineering

**Version v4.3** · 2026-07 · [Changelog](#changelog) · [Installation Guide](INSTALL.md)

> **Fully autonomous long-horizon engineering loop**: Pitch an idea → rough plan → run the entire project automatically (decision points pick the best option automatically), and only call the user in for verification at the end.
>
> Cross-tool orchestration of gstack (review) / OpenSpec (spec) / GSD (build) / Superpowers (guard) / CCG (adversarial review + multi-model),
> with an adversarial quality gate embedded in every artifact-producing stage, and execute advancing plan-by-plan with checks.
> The conservative `--interactive` mode (stops on any decision) remains available.

---

## 1. What It Is

Loop Engineering is an **orchestration layer**. It does not reinvent the capabilities of existing tools; instead, it chains them into a repeatable pipeline following best practices, embedding an adversarial quality gate in every stage:

```
Ideation → Specification → Design(triple review) → Discussion → Planning → Execution → Review → QA → Acceptance → Ship → Retro → [next iteration]
  └─gstack   └─OpenSpec  └─gstack      └─GSD   └─GSD  └─GSD └─gstack└gstack└─GSD └─gstack
    ↓          ↓          ↓             ↓        ↓       ↓       ↓                 ↓
  [—]      [adversarial] [adversarial]  [—]   [adversarial] [adversarial] [adversarial]   [—]      [—]    ← CCG checks every stage
```

Each stage invokes **the strongest tool for that stage** (following the "single authoritative ruling per stage" principle). The primary tool is responsible for **producing output**; the CCG adversarial layer is responsible for **reviewing output**:

| Stage | Primary Tool (produces) | CCG Adversarial Gate (reviews output) |
|------|---------------|----------------------|
| Ideation | gstack `/office-hours` | — (no code, not checked) |
| Specification | OpenSpec `/opsx:propose` | verify-change + codex/gemini analyzer |
| Design | gstack triple review | codex/gemini review of review conclusions |
| Discussion/Planning/Execution | GSD `/gsd-*` | verify-module/security/quality + multi-model |
| Review/QA | gstack `/review` `/cso` `/qa` | multi-model consistency comparison with gstack conclusions |
| Acceptance | GSD `/gsd-verify-work` | — (UAT guaranteed by GSD) |
| Ship | gstack `/ship`→`/canary`→`/land-and-deploy` | verify-security + module + final review |
| Retro | gstack `/retro` + GSD learnings extraction | — (non-output, not checked) |

**Core philosophy**: Two layers of separated responsibility — the primary tool "does", the CCG adversarial layer "checks"; no duplication, no conflict.

---

## 2. Quick Start

### 1. Initialize (once per project)

```
/loop:init my-project-name
```

Creates the `.loop/` state directory:

```
.loop/
├── STATE.yaml            # 7-Phase state machine (single source of truth)
├── learnings.yaml        # Cross-iteration learnings accumulation
├── gaps.yaml             # Intent-vs-delivered gap log
├── timeline.jsonl        # Auditable loop trace
└── adversarial/          # Adversarial quality gate records
    ├── last-verdict.json #   Most recent check verdict (read by Gate 4)
    └── debates/          #   Adversarial discussion records on multi-model disagreement
```

### 2. View Current Status

```
/loop:status
```

Outputs the loop dashboard: current phase, iteration round, per-stage artifacts, blockers, **adversarial check status**, and next-step recommendations.

### 3. Advance the Loop

**Fully autonomous long-horizon (default, recommended)**:
```
/loop:run --next --auto
```
Runs the entire project automatically: decision points pick the best option (small decisions made autonomously, large decisions discussed across models), execute advances plan-by-plan with checks, and only stops on hard blockers. **Calls you in for verification only after the project is complete.**

**Conservative mode (optional)**:
```
/loop:run --next --interactive
```
Stops on any decision or safety gate, waiting for human confirmation (v1 behavior).

---

## 3. Six Commands at a Glance

| Command | Purpose |
|------|------|
| `/loop:init [project name]` | Initialize the `.loop/` state machine |
| `/loop:refine <prompt>` | **Prompt Refinement**: one-line requirement → follow-up questions → three variants (new in v4.3) |
| `/loop:status` | View the loop dashboard (read-only) |
| `/loop:run [--next] [--auto\|--interactive]` | Advance the loop (--auto full-autonomous by default) |
| `/loop:adversarial [step]` | Manually trigger an adversarial check |
| `/loop:retro` | Trigger an iteration loop |

### `/loop:run` Parameters

| Parameter | Effect |
|------|------|
| `--next --auto` | **Default**: fully autonomous long-horizon, runs to project completion (auto-selects best at decision points, stops only on hard blockers) |
| `--next --interactive` | Conservative mode: stops on any decision or safety gate, waits for human |
| `--phase N` | Jump to a specified Phase (passes the safety gate first) |
| `--from N` | Resume from Phase N (interrupt recovery) |
| `--force` | Skip the safety gate (**use with caution**) |

**Hard blocker definition** (the only true stop point for --auto): compilation failure with 3 rounds of auto-fix ineffective / missing critical dependency that cannot be bypassed / adversarial gate escalation beyond limit / user pause.

### `/loop:adversarial` Parameters

| Parameter | Effect |
|------|------|
| `(none)` / `auto` | Run a full adversarial check on the current stage's output |
| `spec`/`execute`/`ship`... | Specify the stage |
| `--debate` | Force recording each model's independent viewpoint |
| `--deterministic-only` | Run only deterministic gates (no multi-model, faster) |

### `/loop:refine` Parameters & Flow (new in v4.3)

| Usage | Description |
|------|------|
| `/loop:refine "one-line requirement"` | Refine a vague requirement into a professional prompt |

**Execution flow** (4 stages):

```
Original one-line requirement
    ↓
[1 Deep analysis]  Identify missing points across 8 dimensions (user/scenario/tech stack/scale/auth/MVP/existing code/acceptance)
    ↓
[2 Dynamic follow-up]  AskUserQuestion asks 3-6 questions at once (targeting uncovered dimensions)
    ↓
[3 Generate three variants]  Always produces output, covering the same requirement, differentiated only in form:
              · Standard: everyday use, clear hierarchy and explicit execution order
              · Compact: iterative dialogue, tight structure, fast dispatch
              · Advanced strong-constraint: AI Agent hardened (mandatory file reads + auth protection + existing-logic protection + mandatory quality gates)
    ↓
[4 User selection]  AskUserQuestion lets you pick one → written to .loop/refined-prompt.md
```

**When to use**: First-time new project (after init, before office-hours) / iterative new requirements / any time you want to turn a vague idea into clarity. Cross-cutting tool, independent of init, does not advance the loop.

---

## 4. The Complete 7-Phase Loop

### Phase 1 — Ideation
- **Tool**: `/office-hours` (6 questions to deeply explore the product vision)
- **Adversarial gate**: None (no code artifact)
- **Artifact**: `.loop/ideation.md`

### Phase 2 — Design (Specification + Triple Review)
- **Specification**: `/opsx:propose` → **Adversarial gate**: verify-change + multi-model spec review
- **Triple review**: `/plan-ceo-review` + `/plan-eng-review` + `/plan-design-review` → **Adversarial gate**: multi-model review of review conclusions
- **Artifact**: `openspec/changes/` + `.loop/design-reviews.md`

### Phase 3 — Implementation (Discussion→Planning→Execution)
- `/gsd:new-project` → `/gsd-discuss-phase` → `/gsd-plan-phase` → `/gsd-execute-phase`
- **Planning adversarial gate**: verify-module + multi-model review of PLAN.md
- **Execution adversarial gate**: verify-security + verify-quality + verify-change + multi-model review of git diff
- ⚙️ Superpowers auto-triggers TDD/debugging during execution
- **Artifact**: `.planning/PLAN.md` + SUMMARY

### Phase 4 — Quality Assurance
- `/review` + `/cso` → **Adversarial gate**: multi-model consistency comparison with gstack conclusions
- `/qa` (real browser) → `/gsd-verify-work` (UAT)
- ⛔ QA must pass before entering Ship (safety gate Gate 3)

### Phase 5 — Ship
- `/ship` → `/canary` → `/land-and-deploy`
- **Pre-ship adversarial gate**: verify-security + verify-module + multi-model final review
- **Artifact**: `.loop/ship-log.md`

### Phase 6 — Iteration (macro loop)
- `/loop:retro` triggers: `/gsd-complete-milestone` → `/retro` → `/gsd-extract-learnings` → `/gsd-audit-milestone` → generate next-round seed
- `iteration += 1`, return to Phase 1 (closed loop)

### Phase 7 — Project Management (cross-cutting, on demand)
- `/gsd-manager`, `/gsd-health`, `/gsd-stats`, etc.; not mandatory to pass through

---

## 5. Adversarial Quality Gate (Core Enhancement)

This is the guarantee for loop output quality. Every artifact-producing stage automatically runs a "check → optimize → re-check" loop after producing output.

### Two Layers of Checking

**Layer 1: Deterministic quality gates** (CCG verify-* scripts, fast, reliable, machine-judged)

| Gate | Checks | Pass criteria |
|----|---------|---------|
| verify-security | SQLi/injection/secrets/XSS and 18 vulnerability classes | Pass only with 0 critical+high |
| verify-quality | Cyclomatic complexity/function length/nesting | Fail when complexity>10 or function>50 lines (script re-judges, **does not trust exit code**) |
| verify-change | Change impact/doc sync | Informational (non-blocking) |
| verify-module | README/DESIGN present | Fail only when docs are missing |

**Layer 2: Multi-model adversarial review** (codeagent-wrapper calls codex+gemini in parallel)
- Bypasses CCG config deficiencies by connecting directly (script uses `--backend codex` + `--backend gemini`)
- Each model independently reviews and outputs a score (TOTAL SCORE/100) + recommendation (PASS/NEEDS_IMPROVEMENT)
- codex's perspective leans backend/security; gemini's leans frontend/a11y — complementary perspectives catch blind spots

### Check → Optimize → Re-check Flow

```
Output → Adversarial check
         ├─ All pass → release to next step
         ├─ Deterministic gate fail / multi-model consensus fail → auto_optimize
         │     consolidated recommendations → auto-fix → re-check (max 3 rounds)
         │     pass → release ｜ still fail → escalate (set blocker, stop and ask human)
         └─ Multi-model disagreement → debate
               complementary perspectives → consensus → auto_optimize
               contradictory conclusions → take conservative + deterministic gate arbitration → generate discussion record
```

### Safety Gates (Why --auto Doesn't Run Away)

The loop has **4** hard-stop safety gates; hitting any one stops `--auto`:

| Gate | Trigger condition | Purpose |
|----|---------|------|
| Gate 1 | Unresolved blocker in current stage | Force human handling |
| Gate 2 | Previous stage's artifact missing | Prevent skipping stages and running empty |
| Gate 3 | QA not passed but attempting to ship | Don't ship something broken |
| **Gate 4** | **Adversarial check not passed** | **Don't let artifacts that failed adversarial review reach downstream** |

This is a feature — it proactively stops at nodes requiring human judgment, rather than running to the end mindlessly.

### Per-Stage Adversarial Gate Configuration (v4.2 adds frontend/desktop checks)

| Stage | Deterministic gates | Multi-model adversarial | Check target |
|------|---------|-----------|---------|
| spec (specification) | verify-change + frontend(spec) | analyzer | openspec/changes/ |
| design (design) | — | review design-reviews.md | review conclusions |
| plan (planning) | verify-module + frontend(design-ui) | review PLAN.md | PLAN.md |
| execute (execution) | security+quality+change + build | reviewer on git diff | code changes |
| review (review) | security | compare with gstack conclusions | review consistency |
| ship (pre-ship) | security+module + frontend(ship) + build | final review | full scope |

**Notes on v4.2 new checks**:
- `frontend(spec)`: spec stage checks whether a frontend UI spec is included (keywords: ui/page/component)
- `frontend(design-ui)`: plan stage checks whether a frontend business-page implementation plan is included (not just scaffolding)
- `frontend(ship)`: ship stage checks that the frontend service in docker-compose.yml is not hidden by profiles
- `build`: plan/ship stages execute the build command (npm run build / tauri build / wails build / flutter build) to ensure frontend code compiles
- `detect_app_type`: auto-detects the app type (Electron/Tauri/Wails/Flutter/Web) and selects the corresponding build command

---

## 6. Typical Workflows

### Scenario A: New Project from Scratch
```
/loop:init my-saas-app
/loop:run --next --auto          # auto loop, each stage with adversarial gate
/loop:status                     # see progress
(after resolving blockers)
/loop:run --next --auto          # continue
```

### Scenario B: Manually Re-run an Adversarial Check on a Stage
```
/loop:adversarial execute        # re-run adversarial gate on execution output
/loop:adversarial --debate       # force recording both models' viewpoint disagreement
```

### Scenario C: Interrupt Recovery
```
/loop:status                     # see where you are
/loop:run --from 3               # resume from Phase 3
```

### Scenario D: One Delivery Complete, Start the Next Round
```
/loop:retro                      # retro + learnings + next-round seed
/loop:run --next --auto          # after confirmation, new round starts from Ideation
```

---

## 7. State File Reference

### `.loop/STATE.yaml` (core)
```yaml
version: 1
project: my-project-name
current_phase: 3          # current Phase (1-7)
current_step: execute     # current step
iteration: 1              # macro loop round number
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

### `.loop/adversarial/last-verdict.json` (read by Gate 4)
```json
{
  "passed": false,
  "gates": [
    {"gate": "security", "passed": true},
    {"gate": "dual-review", "passed": false, "consensus": false, "disagreements": 1}
  ]
}
```

> `.loop/` and GSD's `.planning/` **coexist without conflict**. All files can be safely git-committed and shared across the team.

---

## 8. Relationship with Each Tool Family

```
┌──────────────────────────────────────────────────────────┐
│            Loop Engineering (orchestration layer)         │
│   .loop/STATE.yaml state + 11 routes + adversarial + loop │
└────┬──────────┬──────────┬──────────┬──────────┬────────┘
     │          │          │          │          │
 ┌───▼───┐ ┌───▼────┐ ┌───▼───┐ ┌────▼────┐ ┌───▼────┐
 │gstack │ │OpenSpec│ │ GSD   │ │Super-   │ │  CCG   │
 │review │ │ spec   │ │build  │ │powers   │ │adversary│
 │QA     │ │        │ │plan   │ │ guard   │ │+routing│
 │deploy │ │        │ │execute│ │TDD/debug│ │quality │
 └───────┘ └───────┘ └───────┘ └─────────┘ └────────┘
```

- **gstack** (review): review/QA/security/deploy → invoked via loop routing
- **OpenSpec** (spec): specification definition → invoked by loop in Phase 2
- **GSD** (build): planning/execution/verification → invoked by loop in Phases 3-4
- **Superpowers** (guard): TDD/debugging → auto-triggered during execution, loop does not call it explicitly
- **CCG** (adversary + routing): per-stage adversarial review + multi-model on demand

---

## 9. FAQ

**Q: Adversarial checks need codex/gemini backends — how to configure?**
A: The quality gate scripts call codeagent-wrapper directly (`--backend codex` + `--backend gemini`) and do not read the CCG config. Use cc-switch to switch the underlying backend to deepseek-v4/qwen3.7-plus and it takes effect automatically.

**Q: What if `--auto` stops halfway?**
A: Check the stop reason. Most of the time it hit a safety gate (including adversarial Gate 4) or needs a human decision. After resolving, `/loop:run --next --auto` to continue.

**Q: How are multi-model disagreements (debates) handled?**
A: Complementary perspectives (each finds different issues) → auto-consensus and continue optimizing; contradictory conclusions → take the conservative option + deterministic gate arbitration, generating a record under `.loop/adversarial/debates/` for traceability.

**Q: How does this differ from GSD's `/gsd-autonomous`?**
A: GSD autonomous only manages the GSD internal loop; Loop Engineering is a cross-tool full loop (including adversarial quality gates + macro iteration loop).

**Q: Will it conflict with existing `/gsd-*` `/review`?**
A: No. You can continue to use any command standalone; loop only intervenes when you explicitly run `/loop:*`.

---

## 10. File Locations

| Type | Path |
|------|------|
| Skill | `~/.claude/skills/loop-engineering/SKILL.md` |
| Quality gate engine | `~/.claude/skills/loop-engineering/scripts/loop-adversarial.sh` |
| Workflows | `~/.claude/get-shit-done/workflows/loop-{state,orchestrate,iterate,adversarial}.md` |
| Commands | `~/.zcode/commands/loop/{run,status,init,retro,adversarial}.md` |
| Project state | `<project root>/.loop/` |

All files are on **upgrade-immune paths** (not overwritten by gstack/GSD/CCG upgrades).

---

## 11. Best Practices

1. **Run `/loop:status` before advancing** — see clearly before acting
2. **Use single-step `--next` for critical stages, `--auto` for mechanical ones** — human control for reviews, hands-off for execution
3. **Always run `/loop:retro` each round** — the loop's value lies in accumulating learnings
4. **Clear blockers promptly, don't use `--force`** — safety gates (including adversarial gates) are protection, not obstacles
5. **Put `.loop/` under version control** — share progress across the team
6. **Watch `.loop/adversarial/debates/`** — multi-model disagreement records are signals for quality improvement

---

## Changelog

### Current Version: v4.3 (2026-07)

**Core positioning**: Fully autonomous long-horizon engineering loop + adversarial quality gate + full frontend lifecycle coverage + professional prompt refinement.

| Capability dimension | Description |
|---------|------|
| Fully autonomous long-horizon loop | 12 routes + `--auto` default (auto-selects best at decision points) + execute advancing plan-by-plan with checks |
| Full frontend lifecycle coverage | Replication (Route 3.4) → design decisions (Route 3.5) → implementation+polish (Route 3.6) → real-browser testing |
| Tiered decision-making | Small decisions made autonomously by loop; large decisions discussed across models (codex+gemini) before selecting |
| Adversarial quality gate | Every artifact-producing stage runs an adversarial check (deterministic gates + multi-model + frontend checks) |
| **Professional prompt refinement** | `/loop:refine` one-line requirement → 8-dimension analysis → dynamic follow-up → three variants (new in v4.3) |

### Version History

| Version | Released | Core improvements | Trigger motivation |
|------|------|---------|---------|
| **v4.3** | 2026-07 | Professional prompt refinement (`/loop:refine`: follow-up + three-variant generation) | Vague requirements causing downstream drift |
| v4.2 | 2026-07 | Full design-capability integration + frontend/desktop quality gates | impeccable/taste/ui-ux-pro-max + missing frontend build verification |
| v4.1 | 2026-06 | Frontend UI replication (reference-repo 7-step reverse engineering) | Replication workflow requirement |
| v4 | 2026-06 | Frontend lifecycle completion (Route 3.4/3.5/3.6) | No UI after deployment |
| v3.1 | 2026-06 | Inline execution mechanism (run_full_loop single-session continuous) | Skill() unavailable in ZCode |
| v3 | 2026-06 | Skill() invocation attempt | SlashCommand cross-session breakage |
| v2 | 2026-05 | Full-autonomous philosophy (`--auto` default) + plan-by-plan execution | execute running to death in one shot |
| v1 | 2026-05 | Conservative mode (stops on any decision) | Initial design |

### Detailed Updates per Version

#### v4.3 (current, 2026-07) — Professional Prompt Refiner

**New capabilities**:
- ✨ `/loop:refine <text>` command: refines a user's one-line requirement into a professional prompt
- ✨ 8-dimension deep analysis (target user/core scenario/tech stack/scale-performance/auth-security/priority-MVP/existing-code constraints/acceptance criteria)
- ✨ Dynamic follow-up mechanism: generates 3-6 questions based on prompt precision, asks them in parallel via AskUserQuestion
- ✨ **Always generates three** prompt variants for the user to choose:
  - **Standard**: everyday use, clear hierarchy and explicit execution order
  - **Compact**: iterative dialogue, tight structure, fast dispatch
  - **Advanced strong-constraint**: AI Agent hardened (mandatory file-read checklist + auth-logic protection + existing-logic protection + mandatory quality-gate enforcement)
- ✨ `.loop/refined-prompt.md` artifact (contains original prompt/follow-up log/three full variants/user-selected version)

**Architecture design**:
- Standalone command (`/loop:refine`), fully separated from init/run responsibilities
- Cross-cutting tool: independent of init, does not advance the loop (does not change current_phase/step)
- The agent does not choose for the user — after generating three variants, it must use AskUserQuestion to let the user choose
- Applicable scenarios: first-time new project (after init, before office-hours) / iterative new requirements / any time

**New files**:
- `workflows/loop-refine.md` (core logic: 8 dimensions/8-step flow/three templates/four constraint clauses)
- `commands/loop/refine.md` (command entry)

**Modified files**:
- SKILL.md: argument-hint added `--refine <text>` + @include loop-refine.md + `<process>` new branch + capability description changed to "five capabilities"
- AGENTS.md: MUST rule 11 (refine three variants must let user choose) + section 1 added `/loop:refine` spec + self-check list added 2 items
- loop-state.md: STATE.yaml schema's artifacts added `refine: .loop/refined-prompt.md`

#### v4.2 (2026-07) — Frontend/Desktop Quality Gates + Full Design-Capability Integration

**New capabilities**:
- ✨ `detect_app_type`: auto-detects app type (Electron/Tauri/Wails/Flutter/Web), selects the corresponding build command
- ✨ `verify_frontend`: frontend checks for the spec / design-ui / ship stages
  - `frontend(spec)`: spec stage checks whether a frontend UI spec is included
  - `frontend(design-ui)`: plan stage checks whether a frontend business-page implementation plan is included (not just scaffolding)
  - `frontend(ship)`: ship stage checks that the frontend service in docker-compose.yml is not hidden by profiles
- ✨ `verify_build`: executes the build command matching the app type (npm/tauri/wails/flutter build) to ensure frontend code compiles
- ✨ Route 3.5 (teach-impeccable + ui-ux-pro-max + design-taste-frontend + /design-consultation)
- ✨ Route 3.6 (/design-shotgun + /design-html + impeccable 21 sub-skill quality polish)
- ✨ Route 5.5 (desktop full-stack deploy orchestration: remove profiles hiding + generate make deploy)

**Adversarial gate configuration updates**:
- gate_config table added `frontend(spec/design-ui/ship)` + `build` checks
- execute stage additionally runs `/design-review` at the plan level (visual QA)

**Documentation updates**:
- PRD.md supplemented frontend/desktop capability boundaries (must-do / must-not-do checklist)
- README.md added per-stage adversarial gate configuration table + this version and changelog section

#### v4.1 (2026-06) — Frontend UI Replication

- ✨ Route 3.4: reference-repo 7-step reverse engineering (structure scan → tech stack identification → component inventory → style extraction → interaction mapping → data flow → replication checklist)
- ✨ `replicate-workflow.md` workflow
- ✨ `--reference <url|repo>` parameter support (writes reference_target at init)

#### v4 (2026-06) — Frontend Lifecycle Completion

- ✨ Route 3.4/3.5/3.6 frontend three routes
- 🐛 Fixed "no UI after deployment" (frontend checks added to spec/plan/deploy stages)

#### v3.1 (2026-06) — Inline Execution Mechanism

- 🔧 **Core change**: deprecated SlashCommand self-invocation, switched to `run_full_loop`'s while-loop + inline execution
- Solves SlashCommand cross-session breakage, achieves running the full course in one invocation without interruption

#### v3 (2026-06) — Skill() Invocation Attempt (deprecated)

- ⚠ Superseded by v3.1's inline mechanism (ZCode has no Skill() tool)

#### v2 (2026-05) — Full-Autonomous Philosophy

- ✨ `--auto` becomes the default mode (stops only on hard blockers)
- ✨ Route 6 (execute) changed to plan-by-plan mode (gsd-executor single plan + plan-level adversarial gate)
- ✨ Tiered decision-making (small autonomous / large multi-model discussion) + decisions.jsonl logging

#### v1 (2026-05) — Initial Version

- 7-Phase loop skeleton (ideation→specification→design→implementation→QA→ship→iteration)
- `--interactive` conservative mode (stops on any decision)
- 4 safety gates + adversarial quality gate mechanism

### Upgrade Method

Loop Engineering's files are all on **upgrade-immune paths** (not overwritten by gstack/GSD/CCG upgrades). Upgrade methods:

```bash
# Method 1: reinstall (recommended, ensures all copies are consistent)
cd /path/to/loop-engineering
bash install.sh   # see INSTALL.md

# Method 2: manually sync to local skill directory
SRC=/path/to/loop-engineering
cp -r "$SRC"/{AGENTS.md,PRD.md,README.md,SKILL.md,INSTALL.md,scripts} ~/.zcode/skills/loop-engineering/
cp -r "$SRC"/{AGENTS.md,PRD.md,README.md,SKILL.md,INSTALL.md,scripts} ~/.claude/skills/loop-engineering/
cp "$SRC"/workflows/*.md ~/.claude/get-shit-done/workflows/
cp "$SRC"/commands/*.md ~/.zcode/commands/loop/
```

### Compatibility

- **STATE.yaml**: `version: 1` format unchanged since v1; existing projects upgrade smoothly
- **`.loop/` directory**: upgrades do not affect existing project state; safety gates verify artifact integrity
- **Dependency tools**: requires gstack / GSD / OpenSpec / Superpowers / CCG already installed (each upgrades independently)
- **Minimum environment**: bash 4+ / python3 (adversarial gate script dependencies)
