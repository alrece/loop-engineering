# Loop Engineering — 安装说明

> 本目录是 loop engineering 工程的完整源码副本（脱离 `~/.claude` 环境的独立仓库）。
> 包含：skill 核心、workflow、命令、对抗检查脚本、工程记忆（监控日志+改进素材）。

---

## 目录结构

```
loop-engineering/
├── SKILL.md                      # skill 入口（极简骨架，@ include 4 个 workflow）
├── AGENTS.md                     # AI agent 行为规范（铁律 MUST/MUST NOT + 自检清单）
├── README.md                     # 人类使用说明（命令速查 + 7-Phase 闭环）
├── PRD.md                        # 产品需求文档（能力边界 + 成功标准）
├── INSTALL.md                    # 本文件（安装说明）
├── scripts/
│   └── loop-adversarial.sh       # 对抗检查引擎（确定性质量门 + 多模型对抗 + decide-large）
├── workflows/                    # 逻辑外置的 workflow（被 SKILL.md @ include）
│   ├── loop-state.md             # 状态机 + 5 道安全门（Gate 1-5）
│   ├── loop-orchestrate.md       # 编排核心（14 路由 + run_full_loop + decide_best）
│   ├── loop-iterate.md           # 迭代回环（retro → 教训 → 审计 → 下一轮种子）
│   ├── loop-adversarial.md       # 对抗质量门（检查→优化→重检循环）
│   └── replicate-workflow.md     # 前端 UI 复刻（7 步逆向工程）
├── commands/                     # slash 命令入口
│   ├── run.md                    # /loop:run [--next --auto|--interactive|--force]
│   ├── status.md                 # /loop:status（只读看板）
│   ├── init.md                   # /loop:init [项目名] [--reference <url|repo>]
│   ├── retro.md                  # /loop:retro（迭代回环）
│   └── adversarial.md            # /loop:adversarial [step]（手动对抗检查）
└── monitoring/                   # 工程记忆（zllmwiki 实测收集的改进素材）
    ├── improvement-materials.md  # 10 条改进素材（边跑边修的完整记录）
    ├── scan-20260625.log         # 监控扫描日志
    └── scan-20260626.log
```

---

## 安装到 ZCode（让 /loop:* 命令生效）

### 1. skill + scripts
```bash
# 复制 skill 目录到 ZCode 的 skill 存储
cp -r loop-engineering ~/.claude/skills/loop-engineering
# 建符号链接让 ZCode 发现
ln -sf ~/.claude/skills/loop-engineering ~/.zcode/skills/loop-engineering
```

### 2. workflow
```bash
# 复制到 GSD 的 workflow 目录（SKILL.md 用 @ include 引用它们）
cp loop-engineering/workflows/*.md ~/.claude/get-shit-done/workflows/
```

### 3. 命令
```bash
# 复制到 ZCode 的命令目录
mkdir -p ~/.zcode/commands/loop
cp loop-engineering/commands/*.md ~/.zcode/commands/loop/
```

### 4. 脚本可执行权限
```bash
chmod +x ~/.claude/skills/loop-engineering/scripts/loop-adversarial.sh
```

### 5. 重启 ZCode 会话，验证
```bash
/loop:status   # 应输出闭环看板
```

---

## 依赖（必须已装）

loop 是编排层，不重造能力，依赖以下工具家族已安装：

| 依赖 | 用途 |
|------|------|
| **gstack** | 看（office-hours / plan-*-review / review / cso / qa / ship / design-* / browse） |
| **GSD** | 做（gsd-new-project / discuss / plan / execute / verify / complete-milestone） |
| **OpenSpec** + /opsx | 写（规格定义） |
| **Superpowers** | 守（TDD / 调试自动触发） |
| **CCG** | 对抗（verify-security/quality/change/module + codeagent-wrapper 多模型 + impeccable 设计打磨） |
| **设计能力全家桶** | ui-ux-pro-max（设计决策）+ design-taste-frontend（防套路）+ impeccable（品质打磨） |

---

## 版本演进（v1 → v4.2）

| 版本 | 核心改进 | 触发素材 |
|------|---------|---------|
| v1 | 保守模式（撞决策就停） | 初始设计 |
| v2 | 全自动哲学（--auto 默认） + 逐 plan 执行 | 素材 #4（execute 卡死） |
| v3 | Skill() 调用 | 素材 #8（SlashCommand 断链） |
| v3.1 | inline 执行（最终机制） | 素材 #9（Skill() ZCode 不可用） |
| v4 | 前端生命周期补全 | 素材 #10（部署后无界面） |
| v4.1 | 前端 UI 复刻（7 步） | 复刻流程需求 |
| v4.2 | 设计能力全家桶接入 | impeccable/taste/ui-ux-pro-max |

---

## 工程记忆的价值

`monitoring/improvement-materials.md` 记录了 10 条从 zllmwiki 真实项目实测收集的改进素材，每条含：发现时间、严重度、实测影响、根因、修复方案、修复状态。这是 loop engineering 持续改进的事实依据，为后续项目打基础。
