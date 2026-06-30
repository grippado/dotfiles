#!/usr/bin/env bash
# Validates documentation consistency across the cangaço repo.
# Usage: scripts/docs-check.sh [--verbose]
#
# Canonical $HOME per machine:
#   personal → /Users/grippado
#   arco     → /Users/gabriel.gripp
#   vps      → /home/grippado
#
# Checks for stale dotfiles-ai refs, wrong home paths, agent counts, and broken links.

set -uo pipefail

VERBOSE=0
[ "${1:-}" = "--verbose" ] && VERBOSE=1

REPO="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0
WARN=0
CHECKED=0

fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  ! $1"; WARN=$((WARN + 1)); }
ok()   { [ "$VERBOSE" -eq 1 ] && echo "  ✓ $1"; }
info() { echo "${1-}"; }

# Allowlist: files that may reference legacy /Volumes/ for harvesting only
is_legacy_harvest_file() {
  case "$1" in
    */ide-adapters/cursor.sh) return 0 ;;
  esac
  return 1
}

check_line_home_paths() {
  local rel="$1" lineno="$2" content="$3"

  if echo "$content" | grep -q '/Volumes/'; then
    if is_legacy_harvest_file "$rel"; then
      ok "$rel:$lineno /Volumes/ in legacy harvest regex (allowed)"
    else
      fail "$rel:$lineno banned path: /Volumes/ (use canonical \$HOME)"
    fi
  fi

  if echo "$content" | grep -qE '/root ou similar|/root`|\$HOME.*/root'; then
    fail "$rel:$lineno wrong VPS home: use /home/grippado (not /root)"
  fi

  if echo "$content" | grep -q '/Users/grippado/www/isaac'; then
    fail "$rel:$lineno wrong workspace: /Users/grippado/www/isaac (Arco → /Users/gabriel.gripp/www/isaac)"
  fi

  if echo "$content" | grep -q '/Users/gabriel.gripp/www/personal'; then
    fail "$rel:$lineno wrong workspace: /Users/gabriel.gripp/www/personal (Personal → /Users/grippado/www/personal)"
  fi

  local user
  while IFS= read -r user; do
    [ -z "$user" ] && continue
    case "$user" in
      grippado|gabriel.gripp) ;;
      *) fail "$rel:$lineno unknown macOS home: /Users/$user (allowed: grippado, gabriel.gripp)" ;;
    esac
  done < <(echo "$content" | grep -oE '/Users/[a-zA-Z0-9._-]+' | sed 's|^/Users/||' | sort -u)

  while IFS= read -r user; do
    [ -z "$user" ] && continue
    case "$user" in
      grippado) ;;
      *) fail "$rel:$lineno unknown Linux home: /home/$user (allowed: grippado)" ;;
    esac
  done < <(echo "$content" | grep -oE '/home/[a-zA-Z0-9._-]+' | sed 's|^/home/||' | sort -u)
}

check_line_doc_patterns() {
  local rel="$1" lineno="$2" content="$3"

  if echo "$content" | grep -q 'dotfiles-ai'; then
    if echo "$content" | grep -qE '~/.notes/1-contexts/dotfiles-ai|1-contexts/dotfiles-ai/runbooks'; then
      ok "$rel:$lineno vault runbook reference (allowed)"
    else
      fail "$rel:$lineno stale reference: dotfiles-ai"
      [ "$VERBOSE" -eq 1 ] && echo "      $content"
    fi
  fi

  if echo "$content" | grep -qE '23 agents|23 agent'; then
    fail "$rel:$lineno wrong agent count: use 21 agents (globals only)"
  fi

  check_line_home_paths "$rel" "$lineno" "$content"
}

scan_file_docs() {
  local f="$1"
  local rel="${f#$REPO/}"
  CHECKED=$((CHECKED + 1))
  while IFS= read -r line; do
    local lineno="${line%%:*}"
    local content="${line#*:}"
    check_line_doc_patterns "$rel" "$lineno" "$content"
  done < <(grep -n '.' "$f" 2>/dev/null || true)
}

scan_file_configs() {
  local f="$1"
  local rel="${f#$REPO/}"
  CHECKED=$((CHECKED + 1))
  while IFS= read -r line; do
    local lineno="${line%%:*}"
    local content="${line#*:}"
    check_line_home_paths "$rel" "$lineno" "$content"
  done < <(grep -n '.' "$f" 2>/dev/null || true)
}

# Collect doc files
mapfile -t DOC_FILES < <(
  find "$REPO" -type f \( \
    -name 'README.md' -o \
    -name 'ARCHITECTURE.md' -o \
    -name 'CHEATSHEET.md' \
  \) \
    ! -path '*/_archive*/*' \
    ! -path '*/.git/*' \
    | sort
)

# Machine + context configs (canonical home paths)
mapfile -t CONFIG_FILES < <(
  find "$REPO/.ai/machines" "$REPO/.ai/contexts" -type f \
    ! -path '*/.git/*' 2>/dev/null | sort
)

info "── docs-check ──"
info "repo:  $REPO"
info "canonical homes: /Users/grippado | /Users/gabriel.gripp | /home/grippado"
info "files: ${#DOC_FILES[@]} docs + ${#CONFIG_FILES[@]} configs"
echo

info "[banned patterns — docs]"
for f in "${DOC_FILES[@]}"; do
  scan_file_docs "$f"
done

echo
info "[canonical homes — machine/context configs]"
for f in "${CONFIG_FILES[@]}"; do
  scan_file_configs "$f"
done

if [ "$FAIL" -eq 0 ]; then
  ok "no banned patterns"
fi

echo
info "[relative markdown links]"

check_link() {
  local doc="$1" link="$2"
  local doc_dir target

  [[ "$link" =~ ^https?:// ]] && return 0
  [[ "$link" =~ ^mailto: ]] && return 0
  [[ "$link" =~ ^# ]] && return 0

  link="${link%%#*}"
  [ -z "$link" ] && return 0

  doc_dir="$(dirname "$doc")"
  target="$(cd "$doc_dir" && realpath -m "$link" 2>/dev/null)" || {
    fail "${doc#$REPO/}: broken link → $link"
    return
  }

  if [ ! -e "$target" ]; then
    fail "${doc#$REPO/}: broken link → $link (resolved: $target)"
  else
    ok "${doc#$REPO/}: $link"
  fi
}

for f in "${DOC_FILES[@]}"; do
  while IFS= read -r link; do
    [ -n "$link" ] && check_link "$f" "$link"
  done < <(grep -oE '\]\([^)]+\)' "$f" 2>/dev/null | sed 's/^](//;s/)$//' || true)
done

echo
info "[agent count sanity]"

GLOBAL_AGENTS=$(find "$REPO/.ai/claude/agents" -maxdepth 1 -name '*.md' ! -name 'README.md' 2>/dev/null | wc -l | tr -d ' ')
COMMANDS=$(find "$REPO/.ai/claude/commands" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')

info "  global agents on disk: $GLOBAL_AGENTS (expected 21)"
info "  global commands on disk: $COMMANDS (expected 18)"

[ "$GLOBAL_AGENTS" -eq 21 ] || fail "agent count mismatch: found $GLOBAL_AGENTS, docs say 21"
[ "$COMMANDS" -eq 18 ] || fail "command count mismatch: found $COMMANDS, docs say 18"

echo
info "── summary ──"
info "  files checked: $CHECKED"
info "  failures:      $FAIL"
info "  warnings:      $WARN"

if [ "$FAIL" -gt 0 ]; then
  echo
  echo "docs-check FAILED ($FAIL issue(s))"
  exit 1
fi

echo
echo "docs-check OK"
exit 0
