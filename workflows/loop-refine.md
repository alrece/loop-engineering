<purpose>
The prompt specialization/refinement optimizer of Loop Engineering (new in v4.3). After the user proposes a requirement in one sentence,
it transforms the vague requirement into a professional prompt with clear hierarchy, explicit execution order, and anti-Agent-overshoot guards,
via four phases: "deep analysis → dynamic follow-up questions → three-set generation → user selection".

<!-- 中文译注：提示词专业化优化器（v4.3 新增）——用户一句话提出需求后，通过"深度分析→动态追问→三套生成→用户选定"四阶段，把模糊需求转化为层级清晰、执行顺序明确、防 Agent 越界的专业提示词。 -->

Design philosophy: the user gives one sentence, the agent returns three sets. It does not make decisions for the user; it only structures the decisions for presentation.
<!-- 中文译注：设计哲学——用户给一句话 agent 还三套，不替用户做决定，只把决定结构化呈现。 -->
</purpose>

<required_reading>
@$HOME/.claude/skills/loop-engineering/AGENTS.md
@$HOME/.claude/get-shit-done/workflows/loop-state.md
</required_reading>

<principles>
1. **No guessing, always ask**: key dimensions that the original prompt is missing or ambiguous about MUST be confirmed with the user via AskUserQuestion; do not fabricate on your own.
   <!-- 中文译注：原则 1——不臆测、必追问：原始提示词缺失/模糊的关键维度必须通过 AskUserQuestion 向用户确认，不自行编造。 -->
2. **Always generate three sets**: no matter how clear the original prompt is, always produce "standard / compact / advanced strict" three sets for the user to choose.
   <!-- 中文译注：原则 2——总是生成三套：无论原始提示词多清晰，都产出标准/精简/高阶强约束三套供用户选。 -->
3. **Do not choose for the user**: after the three sets are generated, use AskUserQuestion to let the user choose; the agent MUST NOT decide the version on its own.
   <!-- 中文译注：原则 3——不替用户选：三套生成后用 AskUserQuestion 让用户选，agent 不得擅自定版。 -->
4. **Consistent content, divergent form**: the three sets cover the same requirement facts; only structure/detail-level/constraint-strength differ.
   <!-- 中文译注：原则 4——三套内容一致、形式分化：覆盖相同需求，仅结构/详略/约束强度不同。 -->
5. **Preserve the follow-up record**: the user's answers are written into the artifact, making it auditable and traceable for requirement evolution.
   <!-- 中文译注：原则 5——保留追问记录：用户答复写入产物，可审计、可追溯需求演化。 -->
</principles>

<dimensions>
When the agent does deep analysis, it identifies the missing/ambiguous points of the original prompt across the following 8 dimensions, and generates follow-up questions accordingly:

| # | Dimension | Judgment points (ask if missing/ambiguous) |
|---|-----------|--------------------------------------------|
| ① | Target users | "Who uses it" is not specified or is too broad (e.g. "everyone") |
| ② | Core use scenario | "In what context it solves what problem" is not described |
| ③ | Tech-stack preference | Language/framework not specified; or multiple reasonable choices exist |
| ④ | Scale / performance | Expected user volume, data volume, response latency not mentioned |
| ⑤ | Auth / security | Login method, permission tiers, data-sensitivity level not stated |
| ⑥ | Priority / MVP scope | "Must-do vs optional" not distinguished; first-version delivery boundary not defined |
| ⑦ | Existing-code constraints | Whether extending on an existing project, any unchangeable red lines, not stated |
| ⑧ | Acceptance criteria | No objective criteria defining "what counts as done/qualified" |

<!-- 中文译注：8 个分析维度——①目标用户（谁用）、②核心场景（什么情境解决什么问题）、③技术栈偏好（语言/框架）、④规模/性能（用户量/数据量/时延）、⑤鉴权/安全（登录/权限/敏感等级）、⑥优先级/MVP（必做 vs 可选，首版边界）、⑦既有代码约束（是否扩展、不可改红线）、⑧验收标准（做完什么样算合格的客观判据）；缺失/模糊即追问。 -->

**Follow-up count rule**: 3-6 questions, determined by the number of missing dimensions; the vaguer the prompt, the more questions, up to 6;
if the user already answered a dimension in the original prompt, do not ask about it again.
<!-- 中文译注：追问数量规则——3-6 个，按缺失维度数决定，越模糊问题越多最多 6 个；用户原始提示词已明确回答的维度不再追问。 -->
</dimensions>

<process>

<step name="receive">
Receive the original prompt (from `$ARGUMENTS` or passed in from the previous stage). If the prompt is empty, prompt the user:
`Please provide your requirement description. Example: /loop:refine "build a team-collaboration to-do app"`, and stop.
<!-- 中文译注：receive——接收原始提示词（$ARGUMENTS 或上一环节传入）；为空则提示用户提供需求描述并停止。 -->
</step>

<step name="analyze">
Deeply analyze the original prompt across the 8 dimensions of `<dimensions>`:
- Clearly specified: mark ✓ and excerpt the original-text evidence.
- Partially specified: mark △ and point out the ambiguity.
- Missing: mark ✗.

Output an internal judgment table (not shown directly to the user; used to generate questions in the next step).
<!-- 中文译注：analyze——按 8 维度深度分析：已明确标✓摘录原文证据、部分明确标△指出模糊点、缺失标✗；输出内部判定表（不直接展示，供生成问题用）。 -->
</step>

<step name="generate_questions">
Based on the analysis results, **dynamically generate** 3-6 follow-up questions, rules:
- Generate 1 question per missing (✗) or ambiguous (△) dimension.
- Phrase the question to fit that dimension; avoid being generic (example: "Who are the target users?" → "Are the core users individuals, small teams, or enterprises? What are their main responsibilities?").
- If the number of missing dimensions < 3, supplement with the most critical implicit-assumption questions to reach 3 (e.g. "Is this a new project or an extension on existing code?").
- No more than 6.
<!-- 中文译注：generate_questions——基于分析动态生成 3-6 个追问：每个缺失(✗)/模糊(△)维度生成 1 个；表述贴合维度避免泛泛；缺失维度<3 补关键隐性假设问题凑足 3 个；不超过 6 个。 -->
</step>

<step name="ask_user">
Use the **AskUserQuestion tool to ask all questions at once** (multiple questions in parallel, single interaction):
- Each question provides 2-4 candidate options + allows the user to pick "Other" to customize.
- Option design principles: cover common scenarios, mutually exclusive, actionable.
- header uses the dimension short name (≤12 chars, e.g. "Target users", "Tech stack").
<!-- 中文译注：ask_user——用 AskUserQuestion 一次性追问所有问题（多问题并行单次交互）；每问提供 2-4 候选选项+允许"其他"自定义；选项覆盖常见场景、互斥、可操作；header 用维度简称（≤12 字符）。 -->
</step>

<step name="synthesize">
Think deeply, synthesize "original prompt + follow-up answers", and **generate three sets of prompts simultaneously**.
The three sets MUST cover the same requirement facts; only structure/detail-level/constraint-strength differ (see `<variants>`).
<!-- 中文译注：synthesize——深度思考综合"原始提示词+追问答复"，同时生成三套；三套必须覆盖相同需求事实，仅结构/详略/约束强度不同（见 variants）。 -->
</step>

<step name="present">
**MUST first fully display all three prompts, then let the user choose — never let the user choose blind.**

Execution order (strict):
1. **Fully display three sets** (in the main conversation stream, as normal Markdown text the user can read and scroll):
   Render them sequentially with clear separators, each set including:
   - Set name + applicable scenario (1-2 sentences)
   - **Complete prompt full text** (rendered as a code block ```` ``` ```` or Markdown, the user must be able to read every line)
   - Key features of this set (1-3 bullet points)

   Template (executed in order):
   ```
   ────────────────────────────────────────────
   📋 Variant 1/3: Standard (daily use)
   Applicable scenario: {daily use, as project main requirement doc}

   Full prompt:
   ┌──────────────────────────────────────────┐
   │ {standard full text — every line shown}  │
   └──────────────────────────────────────────┘

   Key features: clear hierarchy, explicit execution order
   ────────────────────────────────────────────

   📋 Variant 2/3: Compact (iterative dialogue)
   Applicable scenario: {quick dispatch in multi-round iterative dialogue}

   Full prompt:
   ┌──────────────────────────────────────────┐
   │ {compact full text — every line shown}   │
   └──────────────────────────────────────────┘

   Key features: tight structure, fast dispatch
   ────────────────────────────────────────────

   📋 Variant 3/3: Advanced strict (AI Agent hardened)
   Applicable scenario: {AI Agent execution, needs file-read + anti-overshoot}

   Full prompt:
   ┌──────────────────────────────────────────┐
   │ {advanced full text — every line shown}  │
   └──────────────────────────────────────────┘

   Key features: mandatory file reads, auth protection, quality gates enforced
   ────────────────────────────────────────────
   ```

2. **Then ask the user to choose**: only after the three sets are fully displayed above, use **AskUserQuestion to let the user choose one set** (options: Standard / Compact / Advanced strict).
   - Each option's `description` field SHOULD include a 1-sentence recap of that set's applicable scenario (for the user to confirm their choice), but the full content already displayed above is the primary reference.
   - The agent MUST NOT choose for the user, and MUST NOT default to the standard version.
   - The agent MUST NOT skip step 1 (full display) and jump directly to AskUserQuestion.

<!-- 中文译注：present——【必须先完整展示三套、再让用户选，绝不让用户盲选】。执行顺序严格：(1) 在主对话流里逐套完整展示（用 Markdown 代码块/框把每套完整提示词逐行渲染出来，用户能滚动阅读每一行；每套含适用场景+完整提示词全文+关键特征，用分隔线隔开，编号 1/3 2/3 3/3）；(2) 三套都完整展示完毕后，再用 AskUserQuestion 让用户选一套（选项 description 含该套适用场景一句话回顾，但主要参考是上方已展示的完整内容）。agent 不得替用户选、不得默认标准版、不得跳过步骤 1 直接弹选择框。 -->
</step>

<step name="persist">
After the user selects:
1. Write to `.loop/refined-prompt.md` (format in `<output>`) — contains the original prompt, follow-up record, the three full prompts, and the user-selected version.
2. Update `.loop/STATE.yaml`: if the `artifacts.refine` field exists, point it to the artifact path.
3. Append to `.loop/timeline.jsonl`: `{"ts","phase","step":"refine","event":"complete"}`.
<!-- 中文译注：persist——用户选定后写入 .loop/refined-prompt.md（含原始提示词/追问记录/三套全文/选定版本）；更新 STATE.yaml 的 artifacts.refine 指向产物路径；追加 timeline.jsonl。 -->
</step>

<step name="handoff">
Suggest the next step to the user:
```
✓ Prompt refined and saved to .loop/refined-prompt.md ({selected version} version)

Suggested next steps:
  → /office-hours (carry the refined prompt into ideation deep-dive)
  → or /loop:run --next --auto (auto-advance the closed loop)
```
Do NOT auto-invoke; let the user decide.
<!-- 中文译注：handoff——提示下一步（/office-hours 带优化后提示词进入构想，或 /loop:run --next --auto 自动推进闭环）；不自动调用由用户决定。 -->
</step>

</process>

<variants>
The three prompt templates. When generating, fill per the structure below; **the requirement facts across the three sets MUST be consistent**.

<!-- 中文译注：三套提示词模板，生成时按下方结构填充，三套的需求事实必须一致。模板内容译为英文版，{占位符} 改为 {placeholder} 英文。 -->

────────────────────────────────────────
### Variant 1: Standard (daily use)
────────────────────────────────────────
Clear structural hierarchy, explicit execution order; suitable as the project's main requirement document.

```
# {project/requirement name}

## Project Goal
{one-sentence goal + what problem it solves}

## Target Users & Scenarios
- Target users: {role + responsibilities}
- Core scenario: {what is done in what context}
- Secondary scenarios: {if any}

## Core Requirements
### Functional Requirements
1. {requirement} (priority: P0/P1/P2)
2. ...

### Non-functional Requirements
- Performance: {user volume / data volume / response latency}
- Security: {auth method + permission tiers}
- Compatibility: {if any}

## Tech Stack
- Language/framework: {explicitly specified}
- Data storage: {if any}
- Deployment: {if any}

## Execution Order
1. {do this first}
2. {then this}
3. ...

## Acceptance Criteria
- [ ] {objectively judgeable criterion 1}
- [ ] {objectively judgeable criterion 2}
- [ ] ...

## Scope Boundaries (not doing)
- {explicitly excluded items}
```

────────────────────────────────────────
### Variant 2: Compact (iterative dialogue, quick dispatch)
────────────────────────────────────────
Tight structure; suitable for quickly dispatching instructions in multi-round iterative dialogue.

```
[{project/requirement name}]
Goal: {one sentence} | Users: {role} | Scenario: {one sentence}

Requirements:
  1. {P0 requirement}
  2. {P0 requirement}
  3. {P1 requirement}

Constraints: tech stack={X} | auth={Y} | scale={Z}
Not doing: {excluded items}
Acceptance: {1-2 core objective criteria}
```

────────────────────────────────────────
### Variant 3: Advanced strict (AI Agent hardened protection)
────────────────────────────────────────
Adapted for AI Agent execution; hardened with mandatory file reads, auth protection, existing-logic protection, and enforced quality gates.
See `<strict_clauses>` for detailed clause wording.

```
# {project/requirement name} (advanced strict version)

## 🔒 Mandatory file-read list (agent must read; skipping → stop)
- {must-read file 1} (read purpose)
- {must-read file 2} (read purpose)
- README.md (project conventions)
- AGENTS.md (behavior spec)
- {OpenSpec specs / core module paths}

## 🚫 Red-line clauses (violation → stop)
### Auth-logic protection
{see strict_clauses.auth}

### Existing-logic protection
{see strict_clauses.legacy}

## Project Goal
{one-sentence goal}

## Core Requirements (P0 must-do)
1. {requirement}
2. {requirement}

## Execution Constraints
### Enforced quality gates
{see strict_clauses.quality}

### Change-scope limits
- Allowed to modify: {module/file whitelist}
- Forbidden to modify: {module/file blacklist}

## Acceptance Criteria
- [ ] {objective criterion}

## Scope Boundaries (not doing)
- {excluded items}
```
</variants>

<strict_clauses>
Detailed wording for the four clause categories of the advanced strict version. When generating, fill the `{placeholder}` based on the specific project.

<!-- 中文译注：高阶强约束版四类条款详细写法，生成时根据具体项目填充 {placeholder}。条款译为英文版。 -->

### 1. Auth-logic protection (auth)
```
- MUST NOT skip, bypass, or disable any auth middleware, permission check, or session-validation logic
- MUST NOT delete or downgrade existing auth/permission/guard-related code, unless explicitly authorized by this prompt
- New endpoints MUST inherit existing auth base classes/decorators; MUST NOT write bare unauthenticated endpoints
- Changes involving user identity (registration/login/password-change/account-deletion) MUST have complete audit logs
- Sensitive operations (delete/export/permission-change) MUST require secondary confirmation + permission re-check
```
<!-- 中文译注：鉴权逻辑保护——不得跳过/绕过/禁用任何鉴权中间件、权限校验、会话验证；不得删除或降级现有 auth/permission/guard 代码（除非明确授权）；新增接口必须继承现有鉴权基类/装饰器不裸写无鉴权端点；用户身份变更必须有完整审计日志；敏感操作必须二次确认+权限复核。 -->

### 2. Existing-logic protection (legacy)
```
- Before modifying any existing function/module, MUST first read its complete implementation + related comments/docs, and understand the original design intent
- MUST NOT refactor, rename, or adjust the signature of existing public interfaces on your own, unless explicitly required by this prompt
- Existing test cases MUST keep passing; if tests need changing, the reasons MUST be listed in the PR description
- Behavior changes MUST be explicitly marked (mark "behavior change" in the diff); MUST NOT silently alter existing behavior
- Database schema changes MUST go through migrations; MUST NOT directly alter the database
```
<!-- 中文译注：原有逻辑保护——改既有函数/模块前必须先读完完整实现+相关注释/文档理解原设计意图；不得擅自重构/改名/调既有公共接口签名（除非明确要求）；既有测试必须保持通过，改测试必须在 PR 说明列理由；行为变更必须显式标注不得静默改变；数据库 schema 变更必须通过 migration 不得直接改库。 -->

### 3. Enforced quality gates (quality)
```
- After each plan completes, MUST run adversarial_gate; MUST NOT skip
- verify-security MUST have 0 critical+high to pass; MUST NOT bypass with --force
- Artifacts MUST conform to spec; spec changes MUST go through the OpenSpec change process
- Before commit, MUST run the full test suite; MUST NOT commit if tests fail
- When the adversarial gate escalates, MUST stop and ask a human; MUST NOT self-downgrade
```
<!-- 中文译注：质量门强制执行——每个 plan 完成后必须跑 adversarial_gate 不得跳过；verify-security 必须 0 个 critical+high 才放行不得用 --force 绕过；产物必须符合 spec，spec 变更必须走 OpenSpec 变更流程；提交前必须跑完整测试套件测试不过不得提交；对抗门 escalate 时必须停下问人不得自行降级。 -->

### 4. Mandatory file-read list (readlist)
The agent generates this based on the project's actual situation, including at least:
- Project-description type: README.md, AGENTS.md, CONTRIBUTING.md (if any)
- Architecture type: DESIGN.md, docs/architecture.md (if any)
- Spec type: openspec/changes/, openspec/specs/ (if using OpenSpec)
- Core modules: source-file paths directly related to this requirement (listed after the agent scans)
- Config type: package.json/pyproject.toml/go.mod, etc. (to confirm tech stack and dependencies)
After each item, note the read purpose so the agent knows why to read it.
<!-- 中文译注：强制文件读取清单——agent 按项目实际生成，至少含项目说明类(README/AGENTS/CONTRIBUTING)、架构类(DESIGN/architecture)、规格类(openspec/changes/specs)、核心模块(与需求直接相关的源文件)、配置类(package.json 等)；每项后注明读取目的。 -->
</strict_clauses>

<output>
`.loop/refined-prompt.md` output format:

```markdown
# Refined Prompt

> Generated at: {ISO8601}
> Generated by: /loop:refine (v4.3)

## Original Prompt
{the user's one-sentence input}

## Follow-up Record
| Dimension | Question | User answer |
|-----------|----------|-------------|
| {dimension} | {question} | {answer} |
| ... | ... | ... |

## Standard version ({✓ selected / not selected})
{standard full text}

## Compact version ({✓ selected / not selected})
{compact full text}

## Advanced strict version ({✓ selected / not selected})
{advanced full text}

---
## Selected version
**{standard/compact/advanced strict} version** (user selected at {ISO8601})
```
<!-- 中文译注：.loop/refined-prompt.md 输出格式——含生成时间/工具、原始提示词、追问记录表、三套全文（各标注是否选中）、选定版本。输出格式代码块译为英文版。 -->
</output>

<state_integration>
Integration with the Loop Engineering state machine:
- refine is an **independent stage**; it does not require `.loop/` to be init'd (without STATE.yaml, only generate refined-prompt.md in the cwd)
- If `.loop/STATE.yaml` exists: update `artifacts.refine` to point to the artifact path, append to timeline
- refine output can be read by `/office-hours` (Phase 1) as the deep-dive starting point
- refine does not change current_phase/step (it is a cross-cutting tool; it does not advance the closed loop)
<!-- 中文译注：与状态机集成——refine 是独立环节不强制 .loop/ 已 init（无 STATE.yaml 时仅在 cwd 生成 refined-prompt.md）；STATE.yaml 存在则更新 artifacts.refine+追加 timeline；产出可被 /office-hours（Phase 1）读取作深挖起点；refine 不改 current_phase/step（横切工具不推进闭环）。 -->
</state_integration>

<auto_mode>
**--auto mode behavior**: refine is an interactive tool; under --auto it still retains the two AskUserQuestion interactions (follow-up + version selection),
because these two interactions are refine's core value. But the agent does not stop at other points — after the follow-up and selection it goes directly to handoff,
without stopping to ask "whether to call office-hours" (only suggests; the user decides).

**--interactive mode behavior**: stops at each step; continues only after confirmation.
<!-- 中文译注：--auto 行为——refine 是交互式工具，--auto 下仍保留两次 AskUserQuestion（追问+选版），因为这是 refine 核心价值；但 agent 不在其他环节停，追问和选版后直接进 handoff，不再因"是否调 office-hours"停问（仅提示由用户自主决定）；--interactive 每步都停确认后再继续。 -->
</auto_mode>
