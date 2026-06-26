#!/usr/bin/env bash
# Merge claude/settings.base.json + machines/<machine>/settings.overlay.json
# into ~/.claude/settings.json. Overlay deep-merges over base; overlay keys win.
#
# Usage: scripts/merge-settings.sh <machine>   (e.g. personal | arco)
#        scripts/merge-settings.sh             (uses $DOTFILES_AI_MACHINE)

set -euo pipefail

MACHINE="${1:-${DOTFILES_AI_MACHINE:-}}"
if [ -z "$MACHINE" ]; then
  echo "ERROR: pass machine as arg or set \$DOTFILES_AI_MACHINE (personal|arco)" >&2
  exit 1
fi

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$REPO/claude/settings.base.json"
OVERLAY="$REPO/machines/$MACHINE/settings.overlay.json"
DEST="$HOME/.claude/settings.json"

[ -f "$BASE" ] || { echo "ERROR: missing $BASE" >&2; exit 1; }
[ -f "$OVERLAY" ] || { echo "ERROR: missing $OVERLAY" >&2; exit 1; }
command -v jq >/dev/null || { echo "ERROR: jq not installed (brew install jq)" >&2; exit 1; }

mkdir -p "$HOME/.claude"

# Backup current settings.json (if any)
if [ -f "$DEST" ] && [ ! -L "$DEST" ]; then
  TS=$(date +%Y%m%d-%H%M%S)
  BAK_DIR="$HOME/.claude/backups/dotfiles-ai-$TS"
  mkdir -p "$BAK_DIR"
  cp "$DEST" "$BAK_DIR/settings.json"
  echo "→ backup: $BAK_DIR/settings.json"
fi

# Deep merge: overlay over base (jq's `*` deep-merges objects, replaces arrays/scalars).
# Strip _doc keys from final output.
jq -s '
  .[0] * .[1]
  | walk(if type == "object" then with_entries(select(.key != "_doc")) else . end)
' "$BASE" "$OVERLAY" > "$DEST"

echo "✓ wrote $DEST (machine=$MACHINE)"
