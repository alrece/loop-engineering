<purpose>
前端 UI 复刻工作流。当用户提供可参考的仓库/项目时，按 7 步逆向工程流程提取设计依据，
为后续 Route 3.5（design-consultation）和 Route 3.6（design-html）提供参考基础。

触发条件：STATE.yaml 的 reference_target 字段非空（用户通过 --reference 指定参考项目）。
若无参考项目，跳过本流程，直接进 Route 3.5 greenfield 设计。
</purpose>

<required_reading>
@$HOME/.claude/get-shit-done/workflows/loop-state.md
</required_reading>

<tool_mapping>
7 步流程的工具映射（探索确认，按可用性分层）：

| 步骤 | 现成 skill/工具 | loop 自己做（基础工具） |
|------|----------------|----------------------|
| 1 技术栈 | — | Read package.json/vite.config/tsconfig/tailwind.config |
| 2 设计 token | `$D extract`（gpt-4o vision，输出 colors/typography/spacing/layout/mood） | 补 radius/shadows/breakpoints（$D 不输出，用 $B css 抓或 Read 源码 CSS 变量） |
| 3 路由+页面+组件树 | — | Glob src/router, src/views, src/components + Grep 路由映射 |
| 4 逐组件记录 | — | 逐个 Read .vue/.tsx，抽 props/state/emits/style → docs/components/ |
| 5 API+数据结构 | — | Glob src/api, src/store, *.proto/swagger + Read |
| 6 静态资源 | `$B scrape`（live 站批量抓媒体+manifest） / `$B download` | 已 clone 的 repo 用 Bash cp/curl |
| 7 交互/动画/校验 | `$B snapshot -D`（行为观察）/ `$B forms` / `$B ux-audit` | Grep transition/@keyframes/validate/@click + Read 源码 |
</tool_mapping>

<process>

<step name="acquire_reference">
获取参考项目源码（复刻的前提）。

判断 reference_target 类型：
- **git URL**（含 github.com / gitlab.com / .git 后缀）→ Bash `git clone --depth 1 <url> /tmp/loop-ref-<slug>`
- **本地路径**（已存在的目录）→ 直接用，记录绝对路径
- **http URL**（线上站，无源码）→ 无法 Read 源码，步骤 1/3/4/5 降级为运行时观察（$B）

记录到 STATE.yaml：`reference_path: <路径>`、`reference_type: git|local|url`

**优化（省 token）**：若参考仓库根目录有 `AGENTS.md` / `CLAUDE.md` / `README.md`，**优先 Read 它**——这类协作文档通常已总结技术栈、目录结构、开发约定，可直接复用到步骤 1/3，避免逐个读配置文件。把读到的关键信息缓存到 `.loop/replicate/00-reference-agents.md`，后续步骤引用它。
</step>

<step name="step1_stack">
**步骤 1：识别技术栈**

**若 acquire_reference 已缓存 00-reference-agents.md，优先从中提取技术栈**（省 token，避免重复读配置）。然后按需补读：
- `package.json` → framework（Vue/React/Svelte）、dependencies、devDependencies、engines
- `vite.config.{ts,js}` / `webpack.config.js` / `next.config.js` → 构建工具 + 插件
- `tsconfig.json` → TS 配置（target/paths/strict）
- `tailwind.config.{ts,js}` / `uno.config.ts` / `postcss.config.js` → 样式方案
- `main.{ts,js}` / `app.tsx` → 入口文件

输出：`.loop/replicate/01-tech-stack.md`（技术栈清单 + 该栈在 zllmwiki 项目的落地建议）
</step>

<step name="step2_tokens">
**步骤 2：提取设计 token**

两路并行：
1. **$D extract**（若参考站可截图）：`$B screenshot <ref-url> -o /tmp/ref.png` → `$D extract --image /tmp/ref.png`
   输出 colors/typography/spacing/layout/mood → 写入 DESIGN.md 基础
2. **补 $D 不输出的 token**（radius/shadows/breakpoints）：
   - Read 参考项目的 CSS 变量定义（`:root` / `@layer base` / `tailwind.config` 的 theme）
   - 或 `$B css <selector>` 抓 border-radius / box-shadow / @media 断点

完整 token 清单（用户要求）：颜色、字体、间距、圆角、阴影、断点、主题
输出：`DESIGN.md`（design-consultation 格式，含 7 类 token）
</step>

<step name="step3_structure">
**步骤 3：梳理路由表 + 页面结构 + 组件树**

Glob + Read 参考项目源码：
- `Glob "src/router/**"` → 路由表（path ↔ component ↔ name 映射）
- `Glob "src/views/**/*.{vue,tsx,jsx}"` → 页面清单
- `Glob "src/components/**/*.{vue,tsx,jsx}"` → 组件清单
- Grep 路由配置的 `path:` / `component:` / `name:` → 建立映射表

**按需复刻策略**（重量级模板如 422 .vue 时必做）：不全量复刻参考项目所有页面，而是：
1. Read 当前项目的 ideation.md / OpenSpec specs，确定**本项目实际需要哪些页面**（如 zllmwiki 需要登录/dashboard/知识库/chat/设置，不需要参考项目的商城/工作流/监控等业务域）
2. 在参考项目的组件树里**只标记本项目需要的部分**（如 art-design-pro 的 Layout + 登录 + Dashboard 框架 + 通用表格组件 ArtTable）
3. 标记为"复用"（直接拷贝/改造）vs "参考"（学习结构自己写）vs "忽略"（本项目用不到）

输出：`.loop/replicate/03-structure.md`（路由表 + 页面树 + 组件树 + **按需复刻标记：哪些复用/参考/忽略**）
</step>

<step name="step4_components">
**步骤 4：逐组件记录**（最重的一步，无自动化）

**只对步骤 3 标记为"复用"或"参考"的组件做**（忽略的不记，省 token）。

遍历（已筛选的）组件清单，逐个 Read 组件源码，记录：
- **结构**：template/JSX 的 DOM 结构
- **props**：defineProps / PropTypes / interface Props
- **状态**：ref / reactive / useState / data
- **交互**：@click / emits / onChange / 事件处理器
- **样式**：`<style>` / className / styled-components / CSS module

**特别关注参考模板的核心基础设施组件**（如 art-design-pro 的 ArtSearchBar/ArtTableHeader/ArtTable/useTable 通用表格体系、Layout、动态路由注册）——这些是模板的精华，复用价值最高。

输出：`.loop/replicate/components/<name>.md`（每个组件一份文档）

**优化**（省 token）：对纯展示组件批量处理（只记结构+样式），只对复杂交互组件详细记录（含 props/state/交互完整签名）。
</step>

<step name="step5_api">
**步骤 5：整理 API 接口与数据结构**

Glob + Read：
- `Glob "src/api/**"` / `Glob "src/services/**"` → 接口定义（请求/响应类型）
- `Glob "src/store/**"` / `Glob "src/stores/**"` → Pinia/Vuex/Redux/Zustand 状态管理
- `Glob "**/*.proto"` / `**/swagger.{json,yaml}"` / `**/openapi.{json,yaml}"` → 接口契约
- Read axios 封装 / fetch 拦截器（请求/响应拦截逻辑）

输出：`.loop/replicate/05-api.md`（接口清单 + 数据结构 + 状态管理逻辑）
</step>

<step name="step6_assets">
**步骤 6：收集静态资源**

根据 reference_type：
- **git/local**：Bash `cp -r <ref>/public <dest>/public` + `cp -r <ref>/src/assets <dest>/src/assets`
- **url（live 站）**：`$B scrape --dir public/assets`（批量抓媒体 + manifest.json）
  - 需鉴权的站：先 setup-browser-cookies / connect-chrome 走 cdp 模式

资源类型：图片、图标（SVG/iconfont）、字体、logo
输出：复制到项目的 public/ 和 src/assets/，记录到 `.loop/replicate/06-assets.md`
</step>

<step name="step7_interactions">
**步骤 7：标注交互/动画/表单校验**

两路并行：
1. **读源码**：Grep `transition|@keyframes|animation|validate|@click|useReducedMotion` → 抽行为定义
2. **运行时观察**（若 live 站可访问）：`$B snapshot -D`（交互前后 DOM 对比）/ `$B forms`（表单字段+校验）/ `$B ux-audit`（交互元素标注）

标注内容：交互（hover/click/focus 行为）、动画（过渡时长/曲线/关键帧）、表单校验（字段/规则/错误提示）

输出：`.loop/replicate/07-interactions.md`
</step>

<step name="finalize">
汇总 7 步产物，交接给 Route 3.5（design-consultation）。

关键交接物：
- `DESIGN.md`（步骤 2 产出，含完整设计 token）→ design-consultation Phase 0 预检会检测它
- `.loop/replicate/` 下 7 份文档 → 作为前端实现的参考依据
- STATE.yaml：step → design-consult

design-consultation 会基于复刻的 DESIGN.md 微调（而非从零设计），design-html 基于复刻的组件文档生成 Vue3 代码。
</step>

</process>

<success_criteria>
- [ ] 7 步全部执行，每步产出对应文档
- [ ] DESIGN.md 含完整 7 类 token（颜色/字体/间距/圆角/阴影/断点/主题）
- [ ] 组件树拆分清晰（路由↔页面↔组件映射）
- [ ] 逐组件文档含结构/props/状态/交互/样式
- [ ] API 文档含请求/响应/状态管理逻辑
- [ ] 静态资源已收集到项目 public/assets
- [ ] 交互/动画/校验行为已标注
- [ ] reference_target 为空时正确跳过本流程
- [ ] --auto 模式下自动确定参考来源，不停
</success_criteria>
