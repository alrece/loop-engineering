# Loop Engineering — Multi-Agent Adapters

> [English](./README.md) | [简体中文](../../README.zh-CN.md#multi-agent-support)

Loop Engineering is natively built for **Claude Code / ZCode**. To run on other AI agent CLIs, this directory provides **adapter-wrapped SKILL.md** versions plus a one-shot installer.

<!-- 中文译注：Loop Engineering 原生为 Claude Code / ZCode 构建。要在其他 AI agent CLI 上运行，本目录提供适配包装的 SKILL.md 版本 + 一键安装脚本。 -->

## Adapter inventory

| Adapter | Target agents | Deploy path | Capability level |
|---------|--------------|-------------|-----------------|
| `gemini-codebuddy/` | Gemini CLI, Codebuddy (shared via `~/.agents/skills/`) | `~/.agents/skills/loop-engineering/` | **Degraded** (inline workflows, text-mode Q&A) |
| `cursor/` | Cursor | `~/.cursor/skills/loop-engineering/` + `~/.cursor/get-shit-done/workflows/` | **Mostly full** (conversational prompting replaces AskUserQuestion) |
| `codex/` | OpenAI Codex CLI | `~/.codex/skills/loop-engineering/` + `~/.codex/get-shit-done/workflows/` | **Mostly full** (`request_user_input` replaces AskUserQuestion) |

> Native Claude Code / ZCode users do NOT need these adapters — the root `SKILL.md` is the canonical version.

<!-- 中文译注：adapter 清单——gemini-codebuddy（共享，降级版）、cursor（基本完整）、codex（基本完整）。原生 Claude Code/ZCode 用户不需要这些 adapter，根目录 SKILL.md 是权威版本。 -->

## Capability comparison

| Capability | Claude Code / ZCode (native) | Cursor | Codex | Gemini / Codebuddy |
|------------|------------------------------|--------|-------|--------------------|
| `AskUserQuestion` follow-up | ✅ Native | ⚠ Conversational numbered list | ⚠ `request_user_input` | ⚠ Plain-text prompt |
| 3-prompt display + selection | ✅ Native | ⚠ Numbered list selection | ⚠ `request_user_input` single-select | ⚠ Plain-text + manual input |
| `SlashCommand` self-loop | ✅ Native | ⚠ Inline execution | ⚠ inline / `spawn_agent` | ⚠ Inline execution |
| `@include` workflows | ✅ Native | ✅ `.cursor` path | ✅ `.codex` path | ❌ Inlined (no `@include`) |
| Adversarial gate script | ✅ Native | ✅ `Shell` | ✅ `run_shell_command` | ✅ `Bash` |
| Multi-model adversarial | ✅ codex+gemini | ⚠ Degraded (single-model) | ⚠ Degraded (codex itself) | ⚠ Degraded (single-model) |
| Plan-by-plan execution | ✅ Native | ✅ Inline | ⚠ `spawn_agent` (when permitted) | ⚠ Inline |

<!-- 中文译注：能力对照表——原生端功能最完整；cursor/codex 基本完整但交互降级；gemini/codebuddy 降级版（无 @include，纯文本交互，多模型降级为单模型）。 -->

## Install

```bash
# One-shot install to all detected agent runtimes
bash adapters/install.sh

# Or install to a specific runtime only
bash adapters/install.sh cursor
bash adapters/install.sh codex
bash adapters/install.sh gemini-codebuddy
```

<!-- 中文译注：安装——一键安装到所有检测到的 agent 端，或指定单一端安装。 -->

## Architecture

```
loop-engineering/                  # canonical source (Claude Code / ZCode native)
├── SKILL.md                       # ← authoritative, do NOT add adapters here
├── AGENTS.md
├── workflows/
└── adapters/                      # v4.4 multi-agent adapters
    ├── README.md                  # this file
    ├── install.sh                 # one-shot installer
    ├── gemini-codebuddy/SKILL.md  # shared by gemini + codebuddy (inlined workflows)
    ├── cursor/SKILL.md            # cursor adapter (<cursor_skill_adapter>)
    └── codex/SKILL.md             # codex adapter (<codex_skill_adapter>)
```

Each adapter is a **self-contained SKILL.md** derived from the canonical version with runtime-specific frontmatter, adapter block, tool mappings, and include paths. They are NOT symlinks — they are independently maintained copies so each can evolve with its runtime.

<!-- 中文译注：每个 adapter 是从权威版本派生的自包含 SKILL.md，含运行时专属的 frontmatter、adapter 块、工具映射、include 路径。不是符号链接，而是独立维护的副本，以便各端随运行时演进。 -->

## Why not one universal SKILL.md?

Because each runtime has **incompatible** mechanisms:
- **Frontmatter**: Claude has `argument-hint` + `allowed-tools` (YAML list); Cursor only accepts `name`+`description`; Codex requires `name` quoted + `metadata.short-description`; Codebuddy needs `allowed-tools` as comma-separated string.
- **Tools**: Claude `AskUserQuestion` ↔ Cursor conversational text ↔ Codex `request_user_input` ↔ Gemini/Codebuddy none.
- **Includes**: Claude/Cursor/Codex support `@file` includes; Gemini/Codebuddy don't.
- **Looping**: Claude `SlashCommand` self-call ↔ others inline-only.

A single file cannot satisfy all. We choose **clarity over DRY** — one adapter per runtime, each readable on its own.

<!-- 中文译注：为什么不一份通用 SKILL.md？因为各运行时机制不兼容——frontmatter 格式不同、工具名不同、include 支持不同、循环机制不同。一份文件无法满足所有。我们选择清晰优于 DRY——每个运行时一份 adapter，各自可独立阅读。 -->
