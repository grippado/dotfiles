#!/usr/bin/env bash
# Sanity check the dotfiles-ai install on the current machine.
# Usage: scripts/doctor.sh

set -u
PASS=0; FAIL=0; WARN=0
ok()   { echo "  ✓ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
warn() { echo "  ! $1"; WARN=$((WARN+1)); }

REPO="$(cd "$(dirname "$0")/.." && pwd)"
MACHINE="${DOTFILES_AI_MACHINE:-}"

echo "── dotfiles-ai doctor ──"
echo "repo:    $REPO"
echo "machine: ${MACHINE:-<unset>}"
echo

echo "[env]"
[ -n "$MACHINE" ] && ok "DOTFILES_AI_MACHINE=$MACHINE" || fail "DOTFILES_AI_MACHINE not set"
[ -n "${NOTES_VAULT:-}" ] && ok "NOTES_VAULT=$NOTES_VAULT" || fail "NOTES_VAULT not set (source machines/$MACHINE/env.sh)"
[ -n "${NOTES_VAULT:-}" ] && [ -d "$NOTES_VAULT" ] && ok "NOTES_VAULT directory exists" || warn "NOTES_VAULT path does not exist"

echo
echo "[binaries]"
for bin in git gh jq; do
  command -v "$bin" >/dev/null && ok "$bin installed" || fail "$bin missing"
done

echo
echo "[claude symlinks]"
for f in CLAUDE.md ARCHITECTURE.md statusline-command-v2.sh REGISTRY.json bin/atlas-sync bin/atlas-snapshot bin/ccstatusline; do
  target="$HOME/.claude/$f"
  if [ -L "$target" ]; then
    real=$(readlink "$target")
    [ -e "$target" ] && ok "$f → $real" || fail "$f → $real (broken)"
  elif [ -e "$target" ]; then
    warn "$f exists but is not a symlink (install pending?)"
  else
    fail "$f missing"
  fi
done

echo
echo "[settings.json]"
SETTINGS="$HOME/.claude/settings.json"
[ -f "$SETTINGS" ] && ok "settings.json present" || fail "settings.json missing (run scripts/merge-settings.sh)"

echo
echo "[ai-memory-sync]"
AMS="$HOME/.ai-memory-sync"
[ -d "$AMS" ] && ok "$AMS exists" || warn "$AMS missing (clone git@github.com:grippado/ai-memory-sync.git)"
[ -x "$AMS/hooks/claude-stop.sh" ] && ok "claude-stop.sh executable" || warn "claude-stop.sh missing or not executable"
[ -x "$AMS/hooks/claude-session-start.sh" ] && ok "claude-session-start.sh executable" || warn "claude-session-start.sh missing or not executable"

echo
echo "[REGISTRY scopes]"
REG="$REPO/machines/$MACHINE/REGISTRY.json"
if [ -f "$REG" ] && command -v jq >/dev/null; then
  jq -r '.scopes | to_entries[] | "\(.key)\t\(.value.path)"' "$REG" | while IFS=$'\t' read -r scope path; do
    expanded="${path/#\~/$HOME}"
    [ -d "$expanded" ] && ok "scope $scope → $path" || warn "scope $scope → $path (path missing)"
  done
else
  fail "cannot read $REG"
fi

echo
echo "[fnm globals]"
if command -v fnm >/dev/null 2>&1; then
  if "$REPO/scripts/fnm-sync-globals.sh" check --quiet 2>/dev/null; then
    ok "all registered npm globals present in all fnm versions"
  else
    DRIFT=$("$REPO/scripts/fnm-sync-globals.sh" check 2>&1 | grep -c "drift:" || true)
    warn "$DRIFT drift(s) — run 'scripts/fnm-sync-globals.sh sync' to fix"
  fi
else
  warn "fnm not in PATH — skipping globals check"
fi

echo
echo "── $PASS passed, $FAIL failed, $WARN warnings ──"
[ "$FAIL" -eq 0 ] || exit 1
