#!/usr/bin/env bash
# Validates documentation consistency across the cangaço repo.
# Usage: scripts/docs-check.sh [--verbose]
#
# Checks sub-docs (READMEs, ARCHITECTURE.md, CHEATSHEET.md) for:
#   - stale "dotfiles-ai" references (except vault runbook paths)
#   - wrong Arco paths (/Volumes/gabriel.gripp)
#   - wrong agent count ("23 agents")
#   - broken relative markdown links

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

# Collect doc files (sub-docs only — root README included as canonical reference)
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

info "── docs-check ──"
info "repo:  $REPO"
info "files: ${#DOC_FILES[@]}"
echo

# --- Pattern checks ---

info "[banned patterns]"

for f in "${DOC_FILES[@]}"; do
  rel="${f#$REPO/}"
  CHECKED=$((CHECKED + 1))

  # dotfiles-ai — allow vault runbook paths only
  while IFS= read -r line; do
    lineno="${line%%:*}"
    content="${line#*:}"
    if echo "$content" | grep -qE '~/.notes/1-contexts/dotfiles-ai|1-contexts/dotfiles-ai/runbooks'; then
      ok "$rel:$lineno vault runbook reference (allowed)"
      continue
    fi
    fail "$rel:$lineno stale reference: dotfiles-ai"
    [ "$VERBOSE" -eq 1 ] && echo "      $content"
  done < <(grep -n 'dotfiles-ai' "$f" 2>/dev/null || true)

  # Wrong Arco SMB path in docs
  while IFS= read -r line; do
    lineno="${line%%:*}"
    fail "$rel:$lineno wrong Arco path: /Volumes/gabriel.gripp (use /Users/gabriel.gripp)"
  done < <(grep -n '/Volumes/gabriel\.gripp' "$f" 2>/dev/null || true)

  # Wrong agent count
  while IFS= read -r line; do
    lineno="${line%%:*}"
    fail "$rel:$lineno wrong agent count: use 21 agents (globals only)"
  done < <(grep -nE '23 agents|23 agent' "$f" 2>/dev/null || true)
done

if [ "$FAIL" -eq 0 ]; then
  ok "no banned patterns found"
fi

echo
info "[relative markdown links]"

check_link() {
  local doc="$1" link="$2"
  local doc_dir base target

  # skip external links
  [[ "$link" =~ ^https?:// ]] && return 0
  [[ "$link" =~ ^mailto: ]] && return 0
  # skip anchors-only
  [[ "$link" =~ ^# ]] && return 0

  # strip anchor
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
