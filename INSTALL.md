> [English](./INSTALL.md) | [简体中文](./README.zh-CN.md#installation)

# Loop Engineering — Installation Guide

> This directory is a complete source copy of the loop engineering project (a standalone repository independent of the `~/.claude` environment).
> It includes: skill core, workflows, commands, adversarial-check scripts, and engineering memory (monitoring logs + improvement materials).

---

## Directory Structure

```
loop-engineering/
├── SKILL.md                      # skill entry (minimal skeleton, @ includes 4 workflows)
├── AGENTS.md                     # AI agent behavior spec (iron rules MUST/MUST NOT + self-check list)
├── README.md                     # human usage guide (command reference + 7-Phase loop)
├── PRD.md                        # product requirements doc (capability boundaries + success criteria)
├── INSTALL.md                    # this file (installation guide)
├── scripts/
│   └── loop-adversarial.sh       # adversarial-check engine (deterministic quality gates + multi-model adversarial + decide-large)
├── workflows/                    # externally-located logic workflows (@ included by SKILL.md)
│   ├── loop-state.md             # state machine + 5 safety gates (Gate 1-5)
│   ├── loop-orchestrate.md       # orchestration core (14 routes + run_full_loop + decide_best)
│   ├── loop-iterate.md           # iteration loop (retro → learnings → audit → next-round seed)
│   ├── loop-adversarial.md       # adversarial quality gate (check → optimize → re-check loop)
│   └── replicate-workflow.md     # frontend UI replication (7-step reverse engineering)
├── commands/                     # slash command entries
│   ├── run.md                    # /loop:run [--next --auto|--interactive|--force]
│   ├── status.md                 # /loop:status (read-only dashboard)
│   ├── init.md                   # /loop:init [project name] [--reference <url|repo>]
│   ├── retro.md                  # /loop:retro (iteration loop)
│   └── adversarial.md            # /loop:adversarial [step] (manual adversarial check)
└── monitoring/                   # engineering memory (improvement materials gathered from real zllmwiki runs)
    ├── improvement-materials.md  # 10 improvement materials (full record of fix-while-running)
    ├── scan-20260625.log         # monitoring scan log
    └── scan-20260626.log
```

---

## Install to ZCode (to enable /loop:* commands)

### 1. skill + scripts
```bash
# Copy the skill directory to ZCode's skill store
cp -r loop-engineering ~/.claude/skills/loop-engineering
# Create a symlink so ZCode discovers it
ln -sf ~/.claude/skills/loop-engineering ~/.zcode/skills/loop-engineering
```

> **中文译注**：把 skill 目录复制到 ZCode 的技能存储位置，并建立符号链接让 ZCode 能发现它。脚本随 skill 一起被复制过去。

### 2. workflow
```bash
# Copy to GSD's workflow directory (SKILL.md @ includes them)
cp loop-engineering/workflows/*.md ~/.claude/get-shit-done/workflows/
```

> **中文译注**：把 workflow 文件复制到 GSD 的工作流目录。SKILL.md 通过 `@ include` 引用它们，放错位置会导致 skill 找不到逻辑。

### 3. commands
```bash
# Copy to ZCode's command directory
mkdir -p ~/.zcode/commands/loop
cp loop-engineering/commands/*.md ~/.zcode/commands/loop/
```

> **中文译注**：把 slash 命令文件放到 ZCode 的命令目录下。`mkdir -p` 会自动创建不存在的父目录。

### 4. script executable permission
```bash
chmod +x ~/.claude/skills/loop-engineering/scripts/loop-adversarial.sh
```

> **中文译注**：给对抗检查引擎脚本加可执行权限，否则脚本无法被调用。

### 5. restart ZCode session and verify
```bash
/loop:status   # should output the loop dashboard
```

> **中文译注**：重启 ZCode 会话后，运行 `/loop:status` 验证安装。如果看到闭环看板输出，说明安装成功。

---

## Dependencies (must be pre-installed)

loop is an orchestration layer; it does not reinvent capabilities and depends on the following tool families already being installed:

| Dependency | Purpose |
|------|------|
| **gstack** | review (office-hours / plan-*-review / review / cso / qa / ship / design-* / browse) |
| **GSD** | build (gsd-new-project / discuss / plan / execute / verify / complete-milestone) |
| **OpenSpec** + /opsx | spec (specification definition) |
| **Superpowers** | guard (TDD / debugging auto-trigger) |
| **CCG** | adversarial (verify-security/quality/change/module + codeagent-wrapper multi-model + impeccable design polish) |
| **Design capability suite** | ui-ux-pro-max (design decisions) + design-taste-frontend (anti-cliché) + impeccable (quality polish) |

---

## Version History (v1 → v4.2)

| Version | Core improvements | Trigger material |
|------|---------|---------|
| v1 | Conservative mode (stops on any decision) | Initial design |
| v2 | Full-autonomous philosophy (--auto default) + plan-by-plan execution | Material #4 (execute deadlock) |
| v3 | Skill() invocation | Material #8 (SlashCommand breakage) |
| v3.1 | inline execution (final mechanism) | Material #9 (Skill() unavailable in ZCode) |
| v4 | Frontend lifecycle completion | Material #10 (no UI after deployment) |
| v4.1 | Frontend UI replication (7 steps) | Replication workflow requirement |
| v4.2 | Full design-capability integration | impeccable/taste/ui-ux-pro-max |

---

## Value of Engineering Memory

`monitoring/improvement-materials.md` records 10 improvement materials gathered from real zllmwiki project runs. Each entry includes: discovery time, severity, observed impact, root cause, fix plan, and fix status. This is the factual basis for loop engineering's continuous improvement and lays the groundwork for subsequent projects.
