<purpose>
Front-end UI replication workflow. When the user provides a referenceable repo/project, it extracts design basis via a 7-step reverse-engineering flow,
providing a reference foundation for the subsequent Route 3.5 (design-consultation) and Route 3.6 (design-html).

<!-- 中文译注：前端 UI 复刻工作流——用户提供可参考仓库时，按 7 步逆向工程流程提取设计依据，为后续 Route 3.5（design-consultation）和 Route 3.6（design-html）提供参考基础。 -->

Trigger condition: STATE.yaml's reference_target field is non-empty (the user specified a reference project via --reference).
If there is no reference project, skip this flow and go directly to Route 3.5 greenfield design.
<!-- 中文译注：触发条件——STATE.yaml 的 reference_target 非空（用户通过 --reference 指定参考项目）；无参考项目则跳过本流程直接进 Route 3.5 greenfield 设计。 -->
</purpose>

<required_reading>
@$HOME/.claude/get-shit-done/workflows/loop-state.md
</required_reading>

<tool_mapping>
Tool mapping for the 7-step flow (exploration-confirmed, layered by availability):

| Step | Ready-made skill/tool | loop does it itself (basic tools) |
|------|-----------------------|-----------------------------------|
| 1 Tech stack | — | Read package.json/vite.config/tsconfig/tailwind.config |
| 2 Design tokens | `$D extract` (gpt-4o vision; outputs colors/typography/spacing/layout/mood) | supplement radius/shadows/breakpoints ($D doesn't output these; use $B css to grab or Read source CSS variables) |
| 3 Routing + pages + component tree | — | Glob src/router, src/views, src/components + Grep routing mappings |
| 4 Per-component record | — | Read each .vue/.tsx, extract props/state/emits/style → docs/components/ |
| 5 API + data structures | — | Glob src/api, src/store, *.proto/swagger + Read |
| 6 Static assets | `$B scrape` (batch-grab media+manifest from a live site) / `$B download` | for a cloned repo use Bash cp/curl |
| 7 Interaction/animation/validation | `$B snapshot -D` (behavior observation) / `$B forms` / `$B ux-audit` | Grep transition/@keyframes/validate/@click + Read source |

<!-- 中文译注：7 步流程工具映射（按可用性分层）——1 技术栈(loop 用 Read)；2 设计 token($D extract+补 radius/shadows/breakpoints)；3 路由+页面+组件树(Glob+Grep)；4 逐组件记录(Read .vue/.tsx 抽 props/state/emits/style)；5 API+数据结构(Glob src/api/store+Read)；6 静态资源($B scrape/download 或 Bash cp/curl)；7 交互/动画/校验($B snapshot/forms/ux-audit 或 Grep+Read)。 -->
</tool_mapping>

<process>

<step name="acquire_reference">
Obtain the reference project source code (a prerequisite for replication).

Determine the reference_target type:
- **git URL** (contains github.com / gitlab.com / .git suffix) → Bash `git clone --depth 1 <url> /tmp/loop-ref-<slug>`
- **local path** (an existing directory) → use directly, record the absolute path
- **http URL** (live site, no source) → cannot Read source; steps 1/3/4/5 degrade to runtime observation ($B)

Record to STATE.yaml: `reference_path: <path>`, `reference_type: git|local|url`

**Optimization (save tokens)**: if the reference repo's root has `AGENTS.md` / `CLAUDE.md` / `README.md`, **Read it first** — such collaboration docs usually already summarize the tech stack, directory structure, and dev conventions, and can be directly reused for steps 1/3, avoiding reading config files one by one. Cache the key info read into `.loop/replicate/00-reference-agents.md`; subsequent steps reference it.
<!-- 中文译注：acquire_reference——获取参考项目源码（复刻前提）；判断 reference_target 类型：git URL→git clone --depth 1，本地路径→直接用记绝对路径，http URL→无法 Read 源码步骤 1/3/4/5 降级为运行时观察；记 reference_path/reference_type；优化（省 token）——参考仓库根有 AGENTS.md/CLAUDE.md/README.md 则优先 Read（通常已总结技术栈/目录结构/开发约定），缓存到 .loop/replicate/00-reference-agents.md 供后续引用。 -->
</step>

<step name="step1_stack">
**Step 1: Identify the tech stack**

**If acquire_reference already cached 00-reference-agents.md, prefer extracting the tech stack from it** (saves tokens, avoids re-reading config). Then supplement-read as needed:
- `package.json` → framework (Vue/React/Svelte), dependencies, devDependencies, engines
- `vite.config.{ts,js}` / `webpack.config.js` / `next.config.js` → build tool + plugins
- `tsconfig.json` → TS config (target/paths/strict)
- `tailwind.config.{ts,js}` / `uno.config.ts` / `postcss.config.js` → styling approach
- `main.{ts,js}` / `app.tsx` → entry file

Output: `.loop/replicate/01-tech-stack.md` (tech-stack list + landing suggestions for this stack in the project)
<!-- 中文译注：步骤 1 识别技术栈——优先从 00-reference-agents.md 提取（省 token），按需补读 package.json/framework、vite.config/构建工具、tsconfig/TS 配置、tailwind.config/样式方案、main 入口；输出 .loop/replicate/01-tech-stack.md。 -->
</step>

<step name="step2_tokens">
**Step 2: Extract design tokens**

Two paths in parallel:
1. **$D extract** (if the reference site can be screenshotted): `$B screenshot <ref-url> -o /tmp/ref.png` → `$D extract --image /tmp/ref.png`
   outputs colors/typography/spacing/layout/mood → write to DESIGN.md as the base
2. **Supplement tokens $D doesn't output** (radius/shadows/breakpoints):
   - Read the reference project's CSS variable definitions (`:root` / `@layer base` / `tailwind.config`'s theme)
   - or `$B css <selector>` to grab border-radius / box-shadow / @media breakpoints

Complete token list (per user requirement): colors, fonts, spacing, radius, shadows, breakpoints, theme
Output: `DESIGN.md` (design-consultation format, with 7 token categories)
<!-- 中文译注：步骤 2 提取设计 token——两路并行：1.$D extract（参考站可截图）输出 colors/typography/spacing/layout/mood 写入 DESIGN.md 基础；2.补 $D 不输出的 token（radius/shadows/breakpoints），Read CSS 变量定义或 $B css 抓；完整 token 清单：颜色/字体/间距/圆角/阴影/断点/主题；输出 DESIGN.md（含 7 类 token）。 -->
</step>

<step name="step3_structure">
**Step 3: Map out the routing table + page structure + component tree**

Glob + Read the reference project source:
- `Glob "src/router/**"` → routing table (path ↔ component ↔ name mapping)
- `Glob "src/views/**/*.{vue,tsx,jsx}"` → page list
- `Glob "src/components/**/*.{vue,tsx,jsx}"` → component list
- Grep the routing config's `path:` / `component:` / `name:` → build the mapping table

**On-demand replication strategy** (mandatory for heavyweight templates like the 422 .vue case): do not replicate all pages of the reference project; instead:
1. Read the current project's ideation.md / OpenSpec specs to determine **which pages this project actually needs** (e.g. it needs login/dashboard/knowledge-base/chat/settings, not the reference's mall/workflow/monitoring business domains)
2. In the reference's component tree, **mark only the parts this project needs** (e.g. the template's Layout + login + Dashboard framework + generic table component)
3. Mark as "reuse" (direct copy/adapt) vs "reference" (learn the structure, write your own) vs "ignore" (this project won't use it)

Output: `.loop/replicate/03-structure.md` (routing table + page tree + component tree + **on-demand replication markers: which to reuse/reference/ignore**)
<!-- 中文译注：步骤 3 梳理路由表+页面结构+组件树——Glob+Read 参考项目源码建映射表；按需复刻策略（重量级模板必做）：不全量复刻参考所有页面，而是读本项目 ideation.md/OpenSpec specs 确定实际需要哪些页面，在参考组件树里只标记本项目需要的部分，标记为复用/参考/忽略；输出 .loop/replicate/03-structure.md。 -->
</step>

<step name="step4_components">
**Step 4: Per-component record** (the heaviest step, no automation)

**Only do this for components marked "reuse" or "reference" in step 3** (ignore the rest, to save tokens).

Iterate over the (filtered) component list, Read each component's source, and record:
- **Structure**: the DOM structure of template/JSX
- **props**: defineProps / PropTypes / interface Props
- **State**: ref / reactive / useState / data
- **Interaction**: @click / emits / onChange / event handlers
- **Style**: `<style>` / className / styled-components / CSS module

**Pay special attention to the reference template's core infrastructure components** (e.g. the generic-table system ArtSearchBar/ArtTableHeader/ArtTable/useTable, Layout, dynamic-route registration) — these are the template's essence and have the highest reuse value.

Output: `.loop/replicate/components/<name>.md` (one doc per component)

**Optimization** (save tokens): batch-process purely presentational components (record only structure + style); only detailedly record complex-interaction components (with full props/state/interaction signatures).
<!-- 中文译注：步骤 4 逐组件记录（最重的一步无自动化）——只对步骤 3 标记"复用"或"参考"的组件做（忽略的不记省 token）；遍历组件清单 Read 源码记录结构/props/状态/交互/样式；特别关注参考模板核心基础设施组件（ArtSearchBar/ArtTableHeader/ArtTable/useTable 通用表格体系/Layout/动态路由注册，复用价值最高）；输出 components/<name>.md（每个组件一份）；优化（省 token）——纯展示组件批量处理（只记结构+样式），只对复杂交互组件详细记录（含完整签名）。 -->
</step>

<step name="step5_api">
**Step 5: Organize API interfaces and data structures**

Glob + Read:
- `Glob "src/api/**"` / `Glob "src/services/**"` → interface definitions (request/response types)
- `Glob "src/store/**"` / `Glob "src/stores/**"` → Pinia/Vuex/Redux/Zustand state management
- `Glob "**/*.proto"` / `**/swagger.{json,yaml}"` / `**/openapi.{json,yaml}"` → interface contracts
- Read the axios wrapper / fetch interceptor (request/response interception logic)

Output: `.loop/replicate/05-api.md` (interface list + data structures + state-management logic)
<!-- 中文译注：步骤 5 整理 API 接口与数据结构——Glob src/api/services（接口定义）、src/store/stores（状态管理）、*.proto/swagger/openapi（接口契约）+Read axios 封装/fetch 拦截器；输出 .loop/replicate/05-api.md（接口清单+数据结构+状态管理逻辑）。 -->
</step>

<step name="step6_assets">
**Step 6: Collect static assets**

Based on reference_type:
- **git/local**: Bash `cp -r <ref>/public <dest>/public` + `cp -r <ref>/src/assets <dest>/src/assets`
- **url (live site)**: `$B scrape --dir public/assets` (batch-grab media + manifest.json)
  - auth-required site: first setup-browser-cookies / connect-chrome to use cdp mode

Asset types: images, icons (SVG/iconfont), fonts, logo
Output: copy to the project's public/ and src/assets/, record to `.loop/replicate/06-assets.md`
<!-- 中文译注：步骤 6 收集静态资源——根据 reference_type：git/local 用 Bash cp 复制 public/src/assets；url 用 $B scrape 批量抓媒体+manifest.json（需鉴权的站先 setup-browser-cookies/connect-chrome 走 cdp）；资源类型：图片/图标/字体/logo；复制到项目 public/和 src/assets/，记 .loop/replicate/06-assets.md。 -->
</step>

<step name="step7_interactions">
**Step 7: Annotate interactions/animations/form-validation**

Two paths in parallel:
1. **Read source**: Grep `transition|@keyframes|animation|validate|@click|useReducedMotion` → extract behavior definitions
2. **Runtime observation** (if the live site is accessible): `$B snapshot -D` (DOM diff before/after interaction) / `$B forms` (form fields + validation) / `$B ux-audit` (interaction-element annotation)

Annotation content: interactions (hover/click/focus behavior), animations (transition duration/curve/keyframes), form validation (fields/rules/error messages)

Output: `.loop/replicate/07-interactions.md`
<!-- 中文译注：步骤 7 标注交互/动画/表单校验——两路并行：1.读源码 Grep transition/@keyframes/animation/validate/@click 抽行为定义；2.运行时观察（live 站可访问）$B snapshot -D（交互前后 DOM 对比）/$B forms（表单字段+校验）/$B ux-audit（交互元素标注）；标注内容：交互（hover/click/focus）、动画（过渡时长/曲线/关键帧）、表单校验（字段/规则/错误提示）；输出 .loop/replicate/07-interactions.md。 -->
</step>

<step name="finalize">
Aggregate the 7-step artifacts and hand off to Route 3.5 (design-consultation).

Key handoff items:
- `DESIGN.md` (step-2 output, with complete design tokens) → design-consultation Phase 0 precheck will detect it
- the 7 docs under `.loop/replicate/` → as the reference basis for front-end implementation
- STATE.yaml: step → design-consult

design-consultation will fine-tune based on the replicated DESIGN.md (rather than designing from scratch); design-html generates Vue3 code based on the replicated component docs.
<!-- 中文译注：finalize——汇总 7 步产物交接给 Route 3.5（design-consultation）；交接物：DESIGN.md（步骤 2 产出含完整设计 token，design-consultation Phase 0 预检会检测它）、.loop/replicate/ 下 7 份文档（前端实现参考依据）、STATE.yaml step→design-consult；design-consultation 基于复刻的 DESIGN.md 微调（非从零设计），design-html 基于复刻组件文档生成 Vue3 代码。 -->
</step>

</process>

<success_criteria>
- [ ] All 7 steps executed, each producing its corresponding doc.
- [ ] DESIGN.md contains the complete 7 token categories (colors/fonts/spacing/radius/shadows/breakpoints/theme).
- [ ] The component tree is split clearly (routing ↔ page ↔ component mapping).
- [ ] Per-component docs contain structure/props/state/interaction/style.
- [ ] API docs contain request/response/state-management logic.
- [ ] Static assets collected into the project's public/assets.
- [ ] Interaction/animation/validation behaviors annotated.
- [ ] Correctly skips this flow when reference_target is empty.
- [ ] Under --auto mode, auto-determines the reference source; does not stop.
<!-- 中文译注：成功标准——7 步全执行每步产出对应文档；DESIGN.md 含完整 7 类 token（颜色/字体/间距/圆角/阴影/断点/主题）；组件树拆分清晰（路由↔页面↔组件映射）；逐组件文档含结构/props/状态/交互/样式；API 文档含请求/响应/状态管理逻辑；静态资源已收集到项目 public/assets；交互/动画/校验行为已标注；reference_target 为空时正确跳过本流程；--auto 模式下自动确定参考来源不停。 -->
</success_criteria>
