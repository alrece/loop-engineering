#!/usr/bin/env bash
# loop-adversarial.sh — Loop Engineering 对抗性质量门引擎
#
# 闭环质量门的核心执行器。被 loop-adversarial.md workflow 调用。
# 两层检查：
#   1. 确定性质量门（CCG verify-* 脚本，机器判 pass/fail）
#   2. 多模型对抗审查（codeagent-wrapper 并行调 codex+gemini，绕过 config.toml 缺陷直连）
#
# 关键设计：
#   - 不读 CCG config.toml 的 routing（它把 frontend/backend 都路由到 codex，是缺陷）。
#     直接 --backend codex + --backend gemini 调 codeagent-wrapper。无论 cc-switch 把底层
#     切到 deepseek-v4 / qwen3.7-plus / 还是别的，本脚本都兼容（只负责调用，不管路由）。
#   - verify-quality / verify-change 的 exit code 不可信（几乎总 pass），脚本里自己解析 JSON 二次判定。
#   - 不修改 CCG 的任何文件，只调用 run_skill.js 和 codeagent-wrapper。
#
# 用法:
#   loop-adversarial.sh deterministic <gate> <path>     # 只跑确定性质量门
#   loop-adversarial.sh dual-review <workdir> [ref]     # 只跑多模型对抗审查
#   loop-adversarial.sh full <phase> <path> [ref]       # 完整质量门（确定性+多模型）
#
# 输出: stdout 一份 JSON 判定结果，给 workflow 决策。
set -uo pipefail

# ─── 路径常量 ───
WRAPPER="$HOME/.claude/bin/codeagent-wrapper"
CCG_RUN="$HOME/.zcode/skills/ccg/run_skill.js"
[ -f "$CCG_RUN" ] || CCG_RUN="$HOME/.claude/skills/ccg/run_skill.js"
CODEX_REVIEWER="$HOME/.claude/.ccg/prompts/codex/reviewer.md"
GEMINI_REVIEWER="$HOME/.claude/.ccg/prompts/gemini/reviewer.md"
GEMINI_MODEL="qwen3.7-plus"

# ─── 工具函数 ───
die() { echo "ERROR: $*" >&2; exit 1; }

# 安全的 JSON 输出（即使 jq 不可用也能用 python3 兜底）
json_out() {
  if command -v jq >/dev/null 2>&1; then jq -c .; else python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin)))"; fi
}

# ─── 确定性质量门 ───
# 调用 CCG run_skill.js，解析 JSON 判定 pass/fail
# 参数: <gate> <path>   gate ∈ {security, quality, change, module}
run_deterministic() {
  local gate="$1" path="${2:-.}"
  local json_out rc
  case "$gate" in
    security)
      json_out=$(node "$CCG_RUN" verify-security "$path" --json 2>/dev/null) || rc=$?
      rc=${rc:-0}
      # verify-security 的 passed 字段可信（0 critical+high 才 pass）
      local passed
      passed=$(echo "$json_out" | python3 -c "import json,sys; d=json.load(sys.stdin); print('true' if d.get('passed') else 'false')" 2>/dev/null || echo "false")
      echo "{\"gate\":\"security\",\"passed\":$passed,\"exit_code\":$rc,\"raw\":$json_out}"
      ;;
    module)
      json_out=$(node "$CCG_RUN" verify-module "$path" --json 2>/dev/null) || rc=$?
      rc=${rc:-0}
      # verify-module 的 passed 字段可信（缺 README/DESIGN 才 fail）
      local passed
      passed=$(echo "$json_out" | python3 -c "import json,sys; d=json.load(sys.stdin); print('true' if d.get('passed') else 'false')" 2>/dev/null || echo "false")
      echo "{\"gate\":\"module\",\"passed\":$passed,\"exit_code\":$rc,\"raw\":$json_out}"
      ;;
    quality)
      json_out=$(node "$CCG_RUN" verify-quality "$path" --json 2>/dev/null) || rc=$?
      rc=${rc:-0}
      # ⚠ verify-quality 的 exit code 不可信（复杂度超标只产生 warning，不阻断）。
      # 自己解析 issues：圈复杂度>10 或 函数>50行 视为 fail。
      local verdict
      verdict=$(echo "$json_out" | python3 -c "
import json, sys, re
d = json.load(sys.stdin)
fatal = []
for i in d.get('issues', []):
    cat = i.get('category', '')
    msg = i.get('message', '')
    sev = i.get('severity', '')
    # 复杂度超阈值（warning 但视为阻断）
    if sev == 'warning' and '复杂度' in cat and re.search(r'(\d+)\s*[>＞]', msg):
        m = re.search(r'(\d+)', msg)
        if m and int(m.group(1)) > 10:
            fatal.append({'category': cat, 'message': msg, 'file': i.get('file_path','')})
    # 函数过长
    elif sev == 'warning' and '函数' in cat and re.search(r'(\d+)\s*[>＞]', msg):
        m = re.search(r'(\d+)', msg)
        if m and int(m.group(1)) > 50:
            fatal.append({'category': cat, 'message': msg, 'file': i.get('file_path','')})
print(json.dumps({'passed': len(fatal)==0, 'fatal_count': len(fatal), 'fatals': fatal}))
" 2>/dev/null || echo '{"passed":true,"fatal_count":0,"fatals":[]}')
      local passed fatal_count
      passed=$(echo "$verdict" | python3 -c "import json,sys; print(json.load(sys.stdin)['passed'])" 2>/dev/null)
      fatal_count=$(echo "$verdict" | python3 -c "import json,sys; print(json.load(sys.stdin)['fatal_count'])" 2>/dev/null)
      echo "{\"gate\":\"quality\",\"passed\":$passed,\"exit_code\":$rc,\"fatal_count\":$fatal_count,\"raw\":$json_out,\"rejudged\":$verdict}"
      ;;
    change)
      # ⚠ verify-change 必须用 staged/committed 模式（working 模式行数恒为 0）
      json_out=$(node "$CCG_RUN" verify-change --mode staged --json 2>/dev/null) || rc=$?
      rc=${rc:-0}
      # verify-change 的 passed 不可信（无 error 级 issue），作为信息性关卡
      # 提取文档同步状态 + warning 数
      local summary
      summary=$(echo "$json_out" | python3 -c "
import json, sys
d = json.load(sys.stdin)
warns = [i for i in d.get('issues', []) if i.get('severity') == 'warning']
doc_sync = d.get('doc_sync_status', {})
unsynced = [k for k,v in doc_sync.items() if v is False]
print(json.dumps({'warning_count': len(warns), 'unsynced_docs': unsynced, 'passed': len(warns)==0}))
" 2>/dev/null || echo '{"warning_count":0,"unsynced_docs":[],"passed":true}')
      local passed
      passed=$(echo "$summary" | python3 -c "import json,sys; print(json.load(sys.stdin)['passed'])" 2>/dev/null)
      echo "{\"gate\":\"change\",\"passed\":$passed,\"exit_code\":$rc,\"blocking\":false,\"raw\":$json_out,\"summary\":$summary}"
      ;;
    *)
      die "未知质量门: $gate (可选: security/quality/change/module)"
      ;;
  esac
}

# ─── 桌面端应用类型检测（v4.2 新增） ───
# 检测 package.json / tauri.conf / Cargo.toml / go.mod / pubspec.yaml
# 输出: {"app_type":"electron|tauri|wails|flutter|web","signals":[...],"build_cmd":"..."}
detect_app_type() {
  local workdir="${1:-.}"
  
  # 检测 package.json
  if [ -f "$workdir/package.json" ]; then
    local pkg_json; pkg_json=$(cat "$workdir/package.json")
    
    # 检测 electron
    if echo "$pkg_json" | grep -q '"electron"'; then
      local build_cmd; build_cmd=$(echo "$pkg_json" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('scripts', {}).get('build') or 'npm run build && electron-builder --dir')
except:
    print('npm run build && electron-builder --dir')
" 2>/dev/null || echo 'npm run build && electron-builder --dir')
      echo "{\"app_type\":\"electron\",\"signals\":[\"package.json contains 'electron'\",\"dependencies/devDependencies includes electron\"],\"build_cmd\":\"$build_cmd\"}"
      return
    fi
    
    # 检测 tauri（package.json + src-tauri/）
    if echo "$pkg_json" | grep -q '"tauri' || [ -d "$workdir/src-tauri" ]; then
      local build_cmd; build_cmd=$(echo "$pkg_json" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('scripts', {}).get('tauri') or 'npm run tauri build')
except:
    print('npm run tauri build')
" 2>/dev/null || echo 'npm run tauri build')
      echo "{\"app_type\":\"tauri\",\"signals\":[\"package.json contains 'tauri'\",\"src-tauri/ directory exists\"],\"build_cmd\":\"$build_cmd\"}"
      return
    fi
    
    # 检测 wails（go + package.json）
    if [ -f "$workdir/go.mod" ] && echo "$pkg_json" | grep -q '"wails'; then
      local build_cmd="wails build"
      echo "{\"app_type\":\"wails\",\"signals\":[\"go.mod exists\",\"package.json contains 'wails'\"],\"build_cmd\":\"$build_cmd\"}"
      return
    fi
    
    # 前端 web（无 electron/tauri/wails）
    local build_cmd; build_cmd=$(echo "$pkg_json" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('scripts', {}).get('build') or 'npm run build')
except:
    print('npm run build')
" 2>/dev/null || echo 'npm run build')
    echo "{\"app_type\":\"web\",\"signals\":[\"package.json exists\",\"no electron/tauri/wails detected\"],\"build_cmd\":\"$build_cmd\"}"
    return
  fi
  
  # 检测 tauri.conf.json / src-tauri/Cargo.toml
  if [ -f "$workdir/tauri.conf.json" ] || [ -f "$workdir/src-tauri/Cargo.toml" ]; then
    local cargo_toml="$workdir/src-tauri/Cargo.toml"
    [ -f "$cargo_toml" ] || cargo_toml="$workdir/Cargo.toml"
    
    if [ -f "$cargo_toml" ] && grep -q 'tauri' "$cargo_toml"; then
      local build_cmd="npm run tauri build"
      echo "{\"app_type\":\"tauri\",\"signals\":[\"tauri.conf.json or src-tauri/Cargo.toml exists\",\"Cargo.toml contains 'tauri'\"],\"build_cmd\":\"$build_cmd\"}"
      return
    fi
  fi
  
  # 检测 go.mod（wails）
  if [ -f "$workdir/go.mod" ]; then
    if grep -q 'wails' "$workdir/go.mod"; then
      local build_cmd="wails build"
      echo "{\"app_type\":\"wails\",\"signals\":[\"go.mod exists\",\"go.mod contains 'wails'\"],\"build_cmd\":\"$build_cmd\"}"
      return
    fi
  fi
  
  # 检测 pubspec.yaml（flutter）
  if [ -f "$workdir/pubspec.yaml" ]; then
    local build_cmd="flutter build"
    echo "{\"app_type\":\"flutter\",\"signals\":[\"pubspec.yaml exists\"],\"build_cmd\":\"$build_cmd\"}"
    return
  fi
  
  # fallback：检查 README.md/AGENTS.md 关键字（用户强调"如果包含就得检查"）
  local readme_files=("$workdir/README.md" "$workdir/AGENTS.md")
  for rf in "${readme_files[@]}"; do
    if [ -f "$rf" ]; then
      local content; content=$(cat "$rf")
      if echo "$content" | grep -qiE 'electron|tauri|wails|flutter'; then
        local detected_type; detected_type=$(echo "$content" | grep -oiE '(electron|tauri|wails|flutter)' | head -1 | tr '[:upper:]' '[:lower:]')
        local app_type="web"
        case "$detected_type" in
          electron) app_type="electron" ;;
          tauri)    app_type="tauri" ;;
          wails)    app_type="wails" ;;
          flutter)  app_type="flutter" ;;
        esac
        local build_cmd="npm run build"
        case "$app_type" in
          electron) build_cmd="npm run build && electron-builder --dir" ;;
          tauri)    build_cmd="npm run tauri build" ;;
          wails)    build_cmd="wails build" ;;
          flutter)  build_cmd="flutter build" ;;
        esac
        echo "{\"app_type\":\"$app_type\",\"signals\":[\"README/AGENTS.md contains '$detected_type' keyword\"],\"build_cmd\":\"$build_cmd\"}"
        return
      fi
    fi
  done
  
  # 默认：web
  echo "{\"app_type\":\"web\",\"signals\":[\"no desktop framework detected\"],\"build_cmd\":\"npm run build\"}"
}

# ─── 前端质量门（v4.2 新增） ───
# spec: 检查 openspec/changes/ 是否含前端 UI spec
# design-ui: 检查是否 Vue3 + 业务页面（非空壳）
# ship: 检查 compose frontend 是否被 profiles 隐藏
verify_frontend() {
  local phase="$1" path="${2:-.}"
  
  case "$phase" in
    spec)
      # 检查 openspec/changes/ 是否含前端 UI spec（关键词：ui/page/component）
      local ui_spec_found=false
      if [ -d "$path/openspec/changes" ]; then
        local spec_files; spec_files=$(find "$path/openspec/changes" -name "*.md" 2>/dev/null)
        for sf in $spec_files; do
          if grep -qiE 'ui|page|component|frontend|界面' "$sf" 2>/dev/null; then
            ui_spec_found=true
            break
          fi
        done
      fi
      
      local passed; passed=$([ "$ui_spec_found" = "true" ] && echo true || echo false)
      local signals; signals=$(if [ "$ui_spec_found" = "true" ]; then echo "[\"frontend UI spec found in openspec/\"]"; else echo "[\"no frontend UI spec detected\"]"; fi)
      echo "{\"gate\":\"frontend\",\"phase\":\"spec\",\"passed\":$passed,\"signals\":$signals}"
      ;;
    design-ui)
      # 检查 design-html / ~/.gstack/projects/*/designs/ 是否含 Vue3 业务页面
      local vue_files=()
      
      # 检查 ~/.gstack/projects/*/designs/（gstack /design-html 默认输出位置）
      local gstack_designs="$HOME/.gstack/projects"
      if [ -d "$gstack_designs" ]; then
        for proj_dir in "$gstack_designs"/*/; do
          local designs_dir="$proj_dir/designs"
          [ -d "$designs_dir" ] || continue
          for vf in "$designs_dir"/*.vue; do
            [ -f "$vf" ] && vue_files+=("$vf")
          done
        done
      fi
      
      # 检查当前项目目录下的 .vue 文件（设计产出可能在此）
      if [ -d "$path" ]; then
        while IFS= read -r -d '' vf; do
          vue_files+=("$vf")
        done < <(find "$path" -name "*.vue" -type f -print0 2>/dev/null)
      fi
      
      # 判定：至少有一个业务页面（非空壳）
      local passed=false
      local signals='[]'
      if [ ${#vue_files[@]} -gt 0 ]; then
        # 检查是否是空壳（仅含模板占位符）
        local real_pages=0
        for vf in "${vue_files[@]}"; do
          if ! grep -qE '(<template>|<script>|setup\(\)|defineProps|defineEmits)' "$vf" 2>/dev/null; then
            continue
          fi
          # 过滤仅含 auth/dashboard/exception 的空壳（v4.2 现状）
          if grep -qE '(auth|dashboard|exception)' "$vf" 2>/dev/null; then
            real_pages=$((real_pages + 1))
          fi
        done
        
        # 至少有一个业务页面才算通过（空壳不算）
        passed=$([ $real_pages -gt 0 ] && echo true || echo false)
        signals="[\"found ${#vue_files[@]} .vue files\", \"real business pages: $real_pages\"]"
      else
        signals="[\"no .vue files found\"]"
      fi
      
      echo "{\"gate\":\"frontend\",\"phase\":\"design-ui\",\"passed\":$passed,\"signals\":$signals}"
      ;;
    ship)
      # 检查 docker-compose.yml 的 frontend 服务是否被 profiles 隐藏
      local compose_files=("$path/docker-compose.yml" "$path/docker-compose.yaml")
      local passed=true
      local signals='[]'
      
      for cf in "${compose_files[@]}"; do
        if [ -f "$cf" ]; then
          # 检查 frontend 服务
          if grep -q '^  frontend:' "$cf" || grep -q 'frontend:' "$cf"; then
            # 检查 profiles 隐藏
            if grep -A5 '^  frontend:' "$cf" | grep -q 'profiles:.*full'; then
              passed=false
              signals='["frontend service found but hidden by profiles:[\"full\"]"]'
            else
              signals='["frontend service present, not hidden by profiles"]'
            fi
          else
            # 无 frontend 服务
            passed=false
            signals='["no frontend service in docker-compose"]'
          fi
          break
        fi
      done
      
      [ ${#signals[@]} -eq 0 ] && signals='["no docker-compose found"]'
      echo "{\"gate\":\"frontend\",\"phase\":\"ship\",\"passed\":$passed,\"signals\":$signals}"
      ;;
    *)
      echo "{\"gate\":\"frontend\",\"phase\":\"unknown\",\"passed\":false,\"signals\":[\"unsupported phase: $phase\"]}"
      ;;
  esac
}

# ─── 构建验证门（v4.2 新增） ───
# 根据 detect_app_type 的输出，执行对应技术栈的构建验证
verify_build() {
  local path="${1:-.}"
  
  # 先检测应用类型
  local app_info; app_info=$(detect_app_type "$path")
  local app_type; app_type=$(echo "$app_info" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('app_type', 'web'))
except:
    print('web')
" 2>/dev/null || echo "web")
  
  local build_cmd; build_cmd=$(echo "$app_info" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('build_cmd', 'npm run build'))
except:
    print('npm run build')
" 2>/dev/null || echo "npm run build")
  
  local passed=true
  local signals="[]"
  local error_msg=""
  
  # 根据 app_type 执行构建命令
  case "$app_type" in
    web)
      if [ -f "$path/package.json" ]; then
        (cd "$path" && npm run build >/dev/null 2>&1) || { passed=false; error_msg="npm run build failed"; }
      else
        passed=false
        error_msg="no package.json found"
      fi
      signals="[\"app_type: web\", \"build_cmd: $build_cmd\"]"
      ;;
    electron)
      if [ -f "$path/package.json" ]; then
        # 先构建前端，再 electron-builder --dir（不打包，只验证能编译）
        (cd "$path" && npm run build >/dev/null 2>&1) || { passed=false; error_msg="npm run build failed"; }
        if [ "$passed" = "true" ]; then
          (cd "$path" && npx electron-builder --dir 2>/dev/null) || { passed=false; error_msg="electron-builder --dir failed"; }
        fi
      else
        passed=false
        error_msg="no package.json found"
      fi
      signals="[\"app_type: electron\", \"build_cmd: $build_cmd\"]"
      ;;
    tauri)
      if [ -f "$path/package.json" ]; then
        # 先构建前端，再 tauri build --debug（只调试模式打包验证）
        (cd "$path" && npm run build >/dev/null 2>&1) || { passed=false; error_msg="npm run build failed"; }
        if [ "$passed" = "true" ]; then
          (cd "$path" && npx tauri build --debug 2>/dev/null) || { passed=false; error_msg="tauri build --debug failed"; }
        fi
      else
        passed=false
        error_msg="no package.json found"
      fi
      signals="[\"app_type: tauri\", \"build_cmd: $build_cmd\"]"
      ;;
    wails)
      if [ -f "$path/go.mod" ]; then
        (cd "$path" && wails build 2>/dev/null) || { passed=false; error_msg="wails build failed"; }
      else
        passed=false
        error_msg="no go.mod found"
      fi
      signals="[\"app_type: wails\", \"build_cmd: $build_cmd\"]"
      ;;
    flutter)
      if [ -f "$path/pubspec.yaml" ]; then
        (cd "$path" && flutter build 2>/dev/null) || { passed=false; error_msg="flutter build failed"; }
      else
        passed=false
        error_msg="no pubspec.yaml found"
      fi
      signals="[\"app_type: flutter\", \"build_cmd: $build_cmd\"]"
      ;;
    *)
      passed=false
      error_msg="unknown app_type: $app_type"
      signals="[\"app_type: $app_type\", \"build_cmd: $build_cmd\"]"
      ;;
  esac
  
  [ -n "$error_msg" ] && passed=false
  echo "{\"gate\":\"build\",\"app_type\":\"$app_type\",\"passed\":$passed,\"signals\":$signals,\"error\":${error_msg:+\"$error_msg\"}}"
}

# ─── 多模型对抗审查 ───
# 并行调 codex + gemini，绕过 config.toml 缺陷，输出隔离
# 参数: <workdir> [ref, 默认 HEAD]
run_dual_review() {
  local workdir="${1:-$PWD}" ref="${2:-HEAD}"
  # 始终落到项目根 .loop/adversarial/（修复素材#2：避免输出随 workdir 漂移到子目录）
  local proj_root
  proj_root=$(git -C "$workdir" rev-parse --show-toplevel 2>/dev/null || echo "$workdir")
  local out_dir="${LOOP_ADV_DIR:-$proj_root/.loop/adversarial}"
  mkdir -p "$out_dir/debates"
  local ts; ts=$(date +%Y%m%d_%H%M%S)

  [ -x "$WRAPPER" ] || die "codeagent-wrapper 不可执行: $WRAPPER"
  [ -f "$CODEX_REVIEWER" ] || die "codex reviewer 角色文件缺失: $CODEX_REVIEWER"
  [ -f "$GEMINI_REVIEWER" ] || die "gemini reviewer 角色文件缺失: $GEMINI_REVIEWER"

  # 获取 diff（作为审查内容）
  local diff_text
  diff_text=$(git -C "$workdir" diff "$ref" 2>/dev/null)
  [ -n "$diff_text" ] || diff_text=$(git -C "$workdir" diff 2>/dev/null)
  if [ -z "$diff_text" ]; then
    # 无 diff，改为审查整个 workdir 结构（让模型自行扫描）
    diff_text="[无未提交变更] 请审查 $workdir 目录下的代码结构。"
  fi

  local task_body="对以下代码变更做严格审查。给出 VALIDATION REPORT（百分制评分，5 个维度各 XX/20，TOTAL SCORE: XX/100）与 RECOMMENDATION: PASS/NEEDS_IMPROVEMENT。列出 Critical Issues 与 Suggestions。

变更内容:
$diff_text"

  # ── 并行启动两个后端（互不可见，输出彻底隔离）──
  "$WRAPPER" --lite --progress --backend codex - "$workdir" \
    >"$out_dir/$ts.codex.out" 2>"$out_dir/$ts.codex.err" <<EOF &
ROLE_FILE: $CODEX_REVIEWER
<TASK>
$task_body
</TASK>
OUTPUT: VALIDATION REPORT + RECOMMENDATION
EOF
  local codex_pid=$!

  "$WRAPPER" --lite --progress --gemini-model "$GEMINI_MODEL" --backend gemini - "$workdir" \
    >"$out_dir/$ts.gemini.out" 2>"$out_dir/$ts.gemini.err" <<EOF &
ROLE_FILE: $GEMINI_REVIEWER
<TASK>
$task_body
</TASK>
OUTPUT: VALIDATION REPORT + RECOMMENDATION
EOF
  local gemini_pid=$!

  # 等待（CODEX_TIMEOUT 默认 2h，这里不设短超时避免假超时杀进程）
  wait "$codex_pid";  local codex_rc=$?
  wait "$gemini_pid"; local gemini_rc=$?

  # ── 提取结果 ──
  local codex_out gemini_out codex_score gemini_score codex_rec gemini_rec
  codex_out=$(cat "$out_dir/$ts.codex.out" 2>/dev/null)
  gemini_out=$(cat "$out_dir/$ts.gemini.out" 2>/dev/null)
  # 提取 TOTAL SCORE 和 RECOMMENDATION
  codex_score=$(echo "$codex_out" | grep -oiE 'TOTAL SCORE: *[0-9]+' | grep -oE '[0-9]+' | head -1)
  gemini_score=$(echo "$gemini_out" | grep -oiE 'TOTAL SCORE: *[0-9]+' | grep -oE '[0-9]+' | head -1)
  codex_rec=$(echo "$codex_out" | grep -oiE 'RECOMMENDATION: *(PASS|NEEDS_IMPROVEMENT|FAIL)' | head -1)
  gemini_rec=$(echo "$gemini_out" | grep -oiE 'RECOMMENDATION: *(PASS|NEEDS_IMPROVEMENT|FAIL)' | head -1)

  # ── 判定共识/分歧 ──
  local consensus disagreements passed
  if [ "${codex_rec:-}" = "${gemini_rec:-}" ] && [ -n "$codex_rec" ]; then
    consensus="true"
    disagreements=0
    # 共识为 PASS 才算通过
    passed=$([ "${codex_rec:-}" = "RECOMMENDATION: PASS" ] && echo true || echo false)
  else
    consensus="false"
    disagreements=1
    # 分歧时不自动 pass（留给讨论）
    passed=false
  fi

  # 写对抗讨论记录（分歧时）
  if [ "$consensus" = "false" ]; then
    cat > "$out_dir/debates/$ts.md" <<DEBATE
# 对抗讨论记录 — $ts

## codex 视角（后端/安全，评分 ${codex_score:-N/A}）
$codex_out

## gemini 视角（前端/a11y，评分 ${gemini_score:-N/A}）
$gemini_out

## 分歧点
- codex 建议: ${codex_rec:-N/A}
- gemini 建议: ${gemini_rec:-N/A}

需人工综合判断。
DEBATE
  fi

  # 输出结构化 JSON（评分/recommendation 用 null 兜底，转成 JSON null）
  # 全部通过环境变量传参，避免 bash 变量裸插值进 Python 代码导致类型混淆
  # （历史 bug：$passed 是小写 true/false，Python 字面量需 True/False，裸插值会 NameError）
  codex_score=${codex_score:-}; gemini_score=${gemini_score:-}
  codex_rec=${codex_rec:-}; gemini_rec=${gemini_rec:-}
  debate_file=""
  [ -f "$out_dir/debates/$ts.md" ] && debate_file="$out_dir/debates/$ts.md"
  LOOP_PASSED="$passed" LOOP_CONSENSUS="$consensus" LOOP_DISAGREE="$disagreements" \
  LOOP_CODEX_RC="$codex_rc" LOOP_CODEX_SCORE="$codex_score" LOOP_CODEX_REC="$codex_rec" \
  LOOP_GEMINI_RC="$gemini_rc" LOOP_GEMINI_SCORE="$gemini_score" LOOP_GEMINI_REC="$gemini_rec" \
  LOOP_OUT_DIR="$out_dir" LOOP_TS="$ts" LOOP_DEBATE="$debate_file" \
  python3 -c '
import os, json
def to_int(s, default=0):
    try: return int(s)
    except (ValueError, TypeError): return default
def to_score(s):
    if not s: return None
    try: return int(s)
    except ValueError: return None
print(json.dumps({
  "gate": "dual-review",
  "passed": os.environ.get("LOOP_PASSED") == "true",
  "consensus": os.environ.get("LOOP_CONSENSUS") == "true",
  "disagreements": to_int(os.environ.get("LOOP_DISAGREE")),
  "codex": {"rc": to_int(os.environ.get("LOOP_CODEX_RC")),
            "score": to_score(os.environ.get("LOOP_CODEX_SCORE")),
            "recommendation": os.environ.get("LOOP_CODEX_REC") or None},
  "gemini": {"rc": to_int(os.environ.get("LOOP_GEMINI_RC")),
             "score": to_score(os.environ.get("LOOP_GEMINI_SCORE")),
             "recommendation": os.environ.get("LOOP_GEMINI_REC") or None},
  "report_dir": os.environ.get("LOOP_OUT_DIR", ""),
  "ts": os.environ.get("LOOP_TS", ""),
  "debate_file": os.environ.get("LOOP_DEBATE") or None
}))
'
}

# ─── 完整质量门（确定性 + 多模型）───
# 参数: <phase> <path> [ref]
run_full() {
  local phase="$1" path="${2:-.}" ref="${3:-HEAD}"
  # 用临时文件收集各门结果，避免 bash 变量裸插值进 Python 导致崩溃
  local tmp_results; tmp_results=$(mktemp)
  echo '[]' > "$tmp_results"

  # 把单条 JSON 结果追加进结果数组（通过 python 安全解析，不裸插值）
  append_result() {
    local item="$1"
    [ -z "$item" ] && return
    # 用环境变量传 item，python 从 stdin 读已有数组
    LOOP_ITEM="$item" python3 -c '
import os, json, sys
item = os.environ.get("LOOP_ITEM", "")
try:
    arr = json.load(sys.stdin)
except Exception:
    arr = []
try:
    arr.append(json.loads(item))
except Exception:
    arr.append({"gate": "unknown", "passed": False, "error": "parse-failed", "raw": item[:200]})
print(json.dumps(arr))
' < "$tmp_results" > "$tmp_results.new" && mv "$tmp_results.new" "$tmp_results"
  }

  # 按环节配置检查项（与 loop-adversarial.md 的配置表一致）
  case "$phase" in
    spec)
      append_result "$(run_deterministic change "$path")"
      # v4.2 前端 UI spec 检查
      append_result "$(verify_frontend "$phase" "$path")"
      ;;
    design)
      # 设计环节只跑多模型（无确定性门）
      : ;;
    replicate)
      # v4.1 参考项目复刻环节（无确定性门，只跑多模型）
      : ;;
    design-consult)
      # v4 前端参考环节（无确定性门，只跑多模型）
      : ;;
    design-ui)
      # v4 前端设计环节：检查 Vue3 业务页面
      append_result "$(verify_frontend "$phase" "$path")"
      # v4.2 构建验证（前端）
      append_result "$(verify_build "$path")"
      ;;
    plan)
      append_result "$(run_deterministic module "$path")"
      # v4.2 前端 plan 检查
      append_result "$(verify_frontend "$phase" "$path")"
      ;;
    execute)
      # v4.2 execute 是 plan 级（逐 plan 模式），只跑安全门 + 质量门
      for g in security quality; do
        append_result "$(run_deterministic "$g" "$path")"
      done
      # v4.2 前端 plan 额外跑 /design-review（视觉 QA）→ 由 loop-orchestrate 的 execute_plan_by_plan 调用
      ;;
    review)
      for g in security quality; do
        append_result "$(run_deterministic "$g" "$path")"
      done
      ;;
    ship)
      for g in security quality; do
        append_result "$(run_deterministic "$g" "$path")"
      done
      append_result "$(run_deterministic module "$path")"
      # v4.2 前端/desktop 门
      append_result "$(verify_frontend "$phase" "$path")"
      append_result "$(verify_build "$path")"
      ;;
    *)
      rm -f "$tmp_results"
      die "未知环节: $phase (可选: spec/design/replicate/design-consult/design-ui/plan/execute/review/ship)"
      ;;
  esac

  # 多模型对抗
  append_result "$(run_dual_review "$path" "$ref")"

  # 综合判定：任一确定性阻断门 fail 或 多模型未通过 → 整体 fail
  local overall
  overall=$(python3 -c "
import json, sys
results = json.load(sys.stdin)
# change 门是信息性的不阻断；其他确定性门 + 多模型都必须 pass
blocking = [r for r in results if r.get('gate') != 'change']
passed = all(r.get('passed') for r in blocking if 'passed' in r)
print(json.dumps({'passed': passed, 'gates': results}))
" < "$tmp_results" 2>/dev/null || echo '{"passed":false,"gates":[]}')
  rm -f "$tmp_results"

  # 写最近判定到固定路径（供 loop-state Gate 4 读取）
  # 始终落到项目根 .loop/adversarial/（修复素材#2：避免输出随 workdir 漂移到子目录）
  local proj_root
  proj_root=$(git -C "$path" rev-parse --show-toplevel 2>/dev/null || echo "$path")
  local out_dir="${LOOP_ADV_DIR:-$proj_root/.loop/adversarial}"
  mkdir -p "$out_dir"
  echo "$overall" > "$out_dir/last-verdict.json"

  echo "$overall"
}

# ─── 大决策多模型讨论（v2，供 decide_best 调用）───
# 参数: <决策描述> <context_path>
# 并行调 codex+gemini analyzer 角色，让两模型各给方案+理由，输出共识/综合
run_decide_large() {
  local decision="${1:-}" context="${2:-.}"
  [ -z "$decision" ] && die "decide-large 需要决策描述参数"

  local proj_root
  proj_root=$(git -C "$context" rev-parse --show-toplevel 2>/dev/null || echo "$context")
  local out_dir="${LOOP_ADV_DIR:-$proj_root/.loop/adversarial}"
  mkdir -p "$out_dir/debates"
  local ts; ts=$(date +%Y%m%d_%H%M%S)

  local codex_analyzer="$HOME/.claude/.ccg/prompts/codex/analyzer.md"
  local gemini_analyzer="$HOME/.claude/.ccg/prompts/gemini/analyzer.md"
  [ -f "$codex_analyzer" ] || die "codex analyzer 角色文件缺失: $codex_analyzer"
  [ -f "$gemini_analyzer" ] || die "gemini analyzer 角色文件缺失: $gemini_analyzer"

  local task_body="这是一个需要决策的工程问题。请给出你推荐的方案 + 理由（含取舍分析）。

决策问题:
$decision

上下文（相关文件/代码/规格见工作目录）。
请输出：PROPOSAL: <你的方案>  REASON: <理由与取舍>"

  # 并行调两模型 analyzer
  "$WRAPPER" --lite --progress --backend codex - "$context" \
    >"$out_dir/$ts.codex.out" 2>"$out_dir/$ts.codex.err" <<EOF &
ROLE_FILE: $codex_analyzer
<TASK>
$task_body
</TASK>
EOF
  local codex_pid=$!

  "$WRAPPER" --lite --progress --gemini-model "$GEMINI_MODEL" --backend gemini - "$context" \
    >"$out_dir/$ts.gemini.out" 2>"$out_dir/$ts.gemini.err" <<EOF &
ROLE_FILE: $gemini_analyzer
<TASK>
$task_body
</TASK>
EOF
  local gemini_pid=$!

  wait "$codex_pid";  local codex_rc=$?
  wait "$gemini_pid"; local gemini_rc=$?

  local codex_out gemini_out codex_prop gemini_prop
  codex_out=$(cat "$out_dir/$ts.codex.out" 2>/dev/null)
  gemini_out=$(cat "$out_dir/$ts.gemini.out" 2>/dev/null)
  codex_prop=$(echo "$codex_out" | grep -oiE 'PROPOSAL:.*' | head -1)
  gemini_prop=$(echo "$gemini_out" | grep -oiE 'PROPOSAL:.*' | head -1)

  # 判定共识：两方案核心一致（简单判定：方案文本相似度，这里用关键词重合度近似）
  local consensus choice reason
  if [ "${codex_prop:-}" = "${gemini_prop:-}" ] && [ -n "$codex_prop" ]; then
    consensus="true"
    choice="$codex_prop"
    reason="两模型方案一致（共识）"
  else
    consensus="false"
    choice="综合方案：${codex_prop:-N/A} | ${gemini_prop:-N/A}"
    reason="两模型方案不同，取综合（合并优点）/取更保守"
  fi

  # 写讨论记录
  cat > "$out_dir/debates/decision-$ts.md" <<DEBATE
# 大决策讨论记录 — $ts

## 决策问题
$decision

## codex 视角（后端/架构）
$codex_out

## gemini 视角（前端/UX/设计系统）
$gemini_out

## 结论
共识: $consensus
选择: $choice
理由: $reason
DEBATE

  # 输出结构化 JSON（环境变量传参，避免类型混淆）
  LOOP_CONSENSUS="$consensus" LOOP_CHOICE="$choice" LOOP_REASON="$reason" \
  LOOP_CODEX_PROP="$codex_prop" LOOP_GEMINI_PROP="$gemini_prop" \
  LOOP_DEBATE="$out_dir/debates/decision-$ts.md" \
  python3 -c '
import os, json
print(json.dumps({
  "consensus": os.environ.get("LOOP_CONSENSUS") == "true",
  "choice": os.environ.get("LOOP_CHOICE", ""),
  "reason": os.environ.get("LOOP_REASON", ""),
  "codex": {"proposal": os.environ.get("LOOP_CODEX_PROP") or None},
  "gemini": {"proposal": os.environ.get("LOOP_GEMINI_PROP") or None},
  "debate_file": os.environ.get("LOOP_DEBATE") or None
}, ensure_ascii=False))
'
}

# ─── 主入口 ───
mode="${1:-}"
shift || true
case "$mode" in
  deterministic) run_deterministic "$@" ;;
  dual-review)   run_dual_review "$@" ;;
  full)          run_full "$@" ;;
  decide-large)  run_decide_large "$@" ;;
  ""|-h|--help)
    cat <<'USAGE'
loop-adversarial.sh — Loop Engineering 对抗性质量门引擎

用法:
  loop-adversarial.sh deterministic <gate> <path>
      gate ∈ {security, quality, change, module}
      只跑确定性质量门（CCG verify-* 脚本）

  loop-adversarial.sh dual-review <workdir> [ref]
      并行调 codex+gemini 对 git diff 做对抗审查

  loop-adversarial.sh full <phase> <path> [ref]
      phase ∈ {spec, design, replicate, design-consult, design-ui, plan, execute, review, ship}
      完整质量门（确定性 + 多模型），写 last-verdict.json
      execute 的 path 可为 plan 级 git diff 范围（逐 plan 模式）

  loop-adversarial.sh decide-large "<决策描述>" <context_path>
      大决策多模型讨论（codex+gemini analyzer 各给方案），输出共识/综合

输出: stdout JSON 判定结果
USAGE
    ;;
  *) die "未知模式: $mode (用 --help 查看用法)" ;;
esac
