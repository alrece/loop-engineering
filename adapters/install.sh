#!/usr/bin/env bash
# Loop Engineering — Multi-Agent Installer (v4.4)
# Deploys loop-engineering to all detected AI agent CLIs (Cursor, Codex, Gemini, Codebuddy).
#
# Usage:
#   bash adapters/install.sh                  # install to all detected runtimes
#   bash adapters/install.sh cursor           # install to Cursor only
#   bash adapters/install.sh codex            # install to Codex only
#   bash adapters/install.sh gemini-codebuddy # install to Gemini+Codebuddy (shared) only
#
# Native Claude Code / ZCode deployment is NOT handled here — see INSTALL.md (root of repo).

set -euo pipefail

# Resolve repo root (parent of adapters/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; }

# --- Helpers ---

ensure_dir() { mkdir -p "$1"; }

copy_with_header() {
  local src="$1" dst="$2"
  info "  $src"
  info "  → $dst"
  cp "$src" "$dst"
}

# --- Per-runtime installers ---

install_cursor() {
  info "=== Cursor ==="
  local cursor_home="$HOME/.cursor"
  if [ ! -d "$cursor_home" ]; then
    warn "Cursor not detected ($cursor_home missing). Skipping."
    return 0
  fi

  local skill_dst="$cursor_home/skills/loop-engineering"
  local wf_dst="$cursor_home/get-shit-done/workflows"

  ensure_dir "$skill_dst"
  ensure_dir "$wf_dst"

  # SKILL.md (adapter version)
  copy_with_header "$SCRIPT_DIR/cursor/SKILL.md" "$skill_dst/SKILL.md"
  # AGENTS.md (shared, needed by @include)
  copy_with_header "$REPO_ROOT/AGENTS.md" "$skill_dst/AGENTS.md"

  # 6 workflow files (rewrite @include prefix from .claude → .cursor)
  info "  Workflows (rewriting @include prefix to .cursor):"
  for wf in loop-state.md loop-orchestrate.md loop-iterate.md loop-adversarial.md replicate-workflow.md loop-refine.md; do
    if [ -f "$REPO_ROOT/workflows/$wf" ]; then
      sed 's|\$HOME/\.claude/|$HOME/.cursor/|g' "$REPO_ROOT/workflows/$wf" > "$wf_dst/$wf"
      info "    ✓ $wf"
    fi
  done

  # Script
  if [ -d "$REPO_ROOT/scripts" ]; then
    ensure_dir "$skill_dst/scripts"
    cp "$REPO_ROOT/scripts/loop-adversarial.sh" "$skill_dst/scripts/loop-adversarial.sh"
    chmod +x "$skill_dst/scripts/loop-adversarial.sh"
    info "  ✓ scripts/loop-adversarial.sh (chmod +x)"
  fi

  ok "Cursor: loop-engineering deployed to $skill_dst"
}

install_codex() {
  info "=== Codex ==="
  local codex_home="$HOME/.codex"
  if [ ! -d "$codex_home" ]; then
    warn "Codex not detected ($codex_home missing). Skipping."
    return 0
  fi

  local skill_dst="$codex_home/skills/loop-engineering"
  local wf_dst="$codex_home/get-shit-done/workflows"

  ensure_dir "$skill_dst"
  ensure_dir "$wf_dst"

  # SKILL.md (adapter version)
  copy_with_header "$SCRIPT_DIR/codex/SKILL.md" "$skill_dst/SKILL.md"
  # AGENTS.md
  copy_with_header "$REPO_ROOT/AGENTS.md" "$skill_dst/AGENTS.md"

  # 6 workflow files (rewrite @include prefix .claude → .codex)
  info "  Workflows (rewriting @include prefix to .codex):"
  for wf in loop-state.md loop-orchestrate.md loop-iterate.md loop-adversarial.md replicate-workflow.md loop-refine.md; do
    if [ -f "$REPO_ROOT/workflows/$wf" ]; then
      sed -e 's|\$HOME/\.claude/|$HOME/.codex/|g' \
          "$REPO_ROOT/workflows/$wf" > "$wf_dst/$wf"
      info "    ✓ $wf"
    fi
  done

  # Script
  if [ -d "$REPO_ROOT/scripts" ]; then
    ensure_dir "$skill_dst/scripts"
    cp "$REPO_ROOT/scripts/loop-adversarial.sh" "$skill_dst/scripts/loop-adversarial.sh"
    chmod +x "$skill_dst/scripts/loop-adversarial.sh"
    info "  ✓ scripts/loop-adversarial.sh (chmod +x)"
  fi

  ok "Codex: loop-engineering deployed to $skill_dst"
}

install_gemini_codebuddy() {
  info "=== Gemini + Codebuddy (shared via ~/.agents/skills/) ==="
  local agents_skills="$HOME/.agents/skills"
  local gemini_skills="$HOME/.gemini/skills"
  local codebuddy_skills="$HOME/.codebuddy/skills"

  # Deploy to ~/.agents/skills/ (shared physical location)
  local skill_dst="$agents_skills/loop-engineering"
  ensure_dir "$skill_dst"

  copy_with_header "$SCRIPT_DIR/gemini-codebuddy/SKILL.md" "$skill_dst/SKILL.md"
  # AGENTS.md (for reference, even though gemini-codebuddy SKILL.md inlines the rules)
  copy_with_header "$REPO_ROOT/AGENTS.md" "$skill_dst/AGENTS.md"

  # Script
  if [ -d "$REPO_ROOT/scripts" ]; then
    ensure_dir "$skill_dst/scripts"
    cp "$REPO_ROOT/scripts/loop-adversarial.sh" "$skill_dst/scripts/loop-adversarial.sh"
    chmod +x "$skill_dst/scripts/loop-adversarial.sh"
    info "  ✓ scripts/loop-adversarial.sh (chmod +x)"
  fi

  ok "Shared: loop-engineering deployed to $skill_dst"

  # Symlink for Gemini CLI (if ~/.gemini/ exists)
  if [ -d "$HOME/.gemini" ]; then
    ensure_dir "$gemini_skills"
    if [ ! -e "$gemini_skills/loop-engineering" ]; then
      ln -sf "$skill_dst" "$gemini_skills/loop-engineering"
      ok "Gemini: symlinked $gemini_skills/loop-engineering → $skill_dst"
    else
      info "Gemini: symlink already exists at $gemini_skills/loop-engineering"
    fi
  else
    warn "Gemini CLI not detected (~/.gemini missing). Shared deployment still done; symlink skipped."
  fi

  # Symlink for Codebuddy (if ~/.codebuddy/ exists)
  if [ -d "$HOME/.codebuddy" ]; then
    ensure_dir "$codebuddy_skills"
    if [ ! -e "$codebuddy_skills/loop-engineering" ]; then
      ln -sf "$skill_dst" "$codebuddy_skills/loop-engineering"
      ok "Codebuddy: symlinked $codebuddy_skills/loop-engineering → $skill_dst"
    else
      info "Codebuddy: symlink already exists at $codebuddy_skills/loop-engineering"
    fi
  else
    warn "Codebuddy not detected (~/.codebuddy missing). Shared deployment still done; symlink skipped."
  fi
}

# --- Main ---

main() {
  echo ""
  echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║  Loop Engineering v4.4 — Multi-Agent Installer           ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  info "Repo root: $REPO_ROOT"
  info "Adapters:  $SCRIPT_DIR"
  echo ""

  local target="${1:-all}"

  case "$target" in
    all)
      install_cursor
      echo ""
      install_codex
      echo ""
      install_gemini_codebuddy
      ;;
    cursor)
      install_cursor
      ;;
    codex)
      install_codex
      ;;
    gemini-codebuddy|gemini|codebuddy)
      install_gemini_codebuddy
      ;;
    *)
      fail "Unknown target: $target"
      fail "Usage: bash adapters/install.sh [all|cursor|codex|gemini-codebuddy]"
      exit 1
      ;;
  esac

  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  ok "Deployment complete."
  echo ""
  info "Verification:"
  echo "  Cursor:       ls ~/.cursor/skills/loop-engineering/"
  echo "  Codex:        ls ~/.codex/skills/loop-engineering/"
  echo "  Gemini:       ls ~/.gemini/skills/loop-engineering/"
  echo "  Codebuddy:    ls ~/.codebuddy/skills/loop-engineering/"
  echo ""
  info "NOTE: Claude Code / ZCode native deployment uses the root SKILL.md — see INSTALL.md."
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
}

main "$@"
