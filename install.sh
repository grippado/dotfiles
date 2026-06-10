#!/usr/bin/env bash
# dotfiles-ai installer — symlinks Claude Code config from this repo into ~/.claude/
# Idempotent. Backs up existing files before replacing. Safe to re-run.
#
# Usage:
#   ./install.sh --machine personal [--dry-run]
#   ./install.sh --machine arco     [--dry-run]
#   ./install.sh --machine vps      [--dry-run]

set -euo pipefail

MACHINE=""
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --machine) MACHINE="$2"; shift 2 ;;
    --machine=*) MACHINE="${1#*=}"; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help)
      sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -n "$MACHINE" ] || MACHINE="${DOTFILES_AI_MACHINE:-}"
case "$MACHINE" in
  personal|arco|vps) ;;
  *) echo "ERROR: --machine must be 'personal', 'arco' or 'vps' (got: '$MACHINE')" >&2; exit 1 ;;
esac

REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
TS=$(date +%Y%m%d-%H%M%S)
BACKUP="$CLAUDE_DIR/backups/dotfiles-ai-$TS"

run() { if [ "$DRY" -eq 1 ]; then echo "  [dry] $*"; else eval "$@"; fi; }

echo "── dotfiles-ai install ──"
echo "repo:    $REPO"
echo "machine: $MACHINE"
echo "target:  $CLAUDE_DIR"
echo "backup:  $BACKUP"
[ "$DRY" -eq 1 ] && echo "MODE:    DRY-RUN (no changes)"
echo

run "mkdir -p \"$CLAUDE_DIR/commands\" \"$CLAUDE_DIR/agents\" \"$CLAUDE_DIR/bin\" \"$BACKUP\""

backup_if_real() {
  local p="$1"
  if [ -e "$p" ] && [ ! -L "$p" ]; then
    local rel="${p#$CLAUDE_DIR/}"
    run "mkdir -p \"$BACKUP/$(dirname "$rel")\""
    run "cp -R \"$p\" \"$BACKUP/$rel\""
  fi
}

link() {
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "  = $dst (already linked)"
    return
  fi
  backup_if_real "$dst"
  if [ -L "$dst" ] || [ -e "$dst" ]; then
    run "rm -rf \"$dst\""
  fi
  run "ln -s \"$src\" \"$dst\""
  echo "  → $dst → $src"
}

echo "[top-level docs]"
link "$REPO/claude/CLAUDE.md"                  "$CLAUDE_DIR/CLAUDE.md"
link "$REPO/claude/ARCHITECTURE.md"            "$CLAUDE_DIR/ARCHITECTURE.md"
# statusline ativo e bin/ccstatusline (linkado via [bin/] abaixo). As versoes
# legadas v2/v3 nao existem mais na fonte (so v4, tambem inativa) — nao linkar.

echo
echo "[bin/ — file-by-file (todo script novo entra automaticamente)]"
for src in "$REPO/claude/bin"/*; do
  [ -f "$src" ] || continue
  base=$(basename "$src")
  link "$src" "$CLAUDE_DIR/bin/$base"
done

echo
echo "[REGISTRY.json — machine-specific]"
link "$REPO/machines/$MACHINE/REGISTRY.json" "$CLAUDE_DIR/REGISTRY.json"

echo
echo "[ccstatusline — machine-specific statusline config]"
# Destino fica em ~/.config/ccstatusline/ (fora de $CLAUDE_DIR), entao a funcao
# link() generica nao serve (o backup dela assume path sob $CLAUDE_DIR).
CCS_SRC="$REPO/machines/$MACHINE/ccstatusline.json"
CCS_DST="$HOME/.config/ccstatusline/settings.json"
if [ ! -f "$CCS_SRC" ]; then
  echo "  ! $CCS_SRC missing — skipping (statusline keeps its current local config)"
elif [ -L "$CCS_DST" ] && [ "$(readlink "$CCS_DST")" = "$CCS_SRC" ]; then
  echo "  = $CCS_DST (already linked)"
else
  run "mkdir -p \"$(dirname "$CCS_DST")\""
  if [ -e "$CCS_DST" ] && [ ! -L "$CCS_DST" ]; then
    run "mkdir -p \"$BACKUP/ccstatusline\""
    run "cp \"$CCS_DST\" \"$BACKUP/ccstatusline/settings.json\""
  fi
  if [ -e "$CCS_DST" ] || [ -L "$CCS_DST" ]; then run "rm -rf \"$CCS_DST\""; fi
  run "ln -s \"$CCS_SRC\" \"$CCS_DST\""
  echo "  → $CCS_DST → $CCS_SRC"
fi

echo
echo "[commands/ — file-by-file (preserves Atlas-managed scoped symlinks)]"
for src in "$REPO/claude/commands"/*.md; do
  [ -f "$src" ] || continue
  base=$(basename "$src")
  link "$src" "$CLAUDE_DIR/commands/$base"
done

echo
echo "[agents/ — file-by-file]"
for src in "$REPO/claude/agents"/*.md; do
  [ -f "$src" ] || continue
  base=$(basename "$src")
  link "$src" "$CLAUDE_DIR/agents/$base"
done

echo
echo "[settings.json — merged base + overlay]"
if [ "$DRY" -eq 1 ]; then
  echo "  [dry] would run scripts/merge-settings.sh $MACHINE"
else
  "$REPO/scripts/merge-settings.sh" "$MACHINE"
fi

echo
echo "[contexts/ — workspace-level .claude symlinks]"
for ctx_dir in "$REPO/contexts"/*/; do
  [ -d "$ctx_dir" ] || continue
  ctx_name=$(basename "$ctx_dir")
  case "$ctx_name" in
    personal) workspace="$HOME/www/personal" ;;
    arco)     workspace="$HOME/www/isaac" ;;
    *)        echo "  ! unknown context: $ctx_name — skipping"; continue ;;
  esac
  if [ ! -d "$workspace" ]; then
    echo "  ! workspace missing: $workspace — skipping context $ctx_name"
    continue
  fi
  link "$ctx_dir.claude" "$workspace/.claude"
done

echo
echo "[atlas-sync — scoped command symlinks from REGISTRY]"
echo "  IMPORTANT: atlas-sync expands \$HOME at runtime, so it must run on the"
echo "  *physical* machine you're configuring (not via a remote/SMB mount —"
echo "  that bakes the wrong \$HOME into the symlinks)."
if [ "$DRY" -eq 1 ]; then
  echo "  [dry] would run $CLAUDE_DIR/bin/atlas-sync"
elif [ -x "$CLAUDE_DIR/bin/atlas-sync" ]; then
  "$CLAUDE_DIR/bin/atlas-sync"
else
  echo "  ! atlas-sync not found at $CLAUDE_DIR/bin/atlas-sync — skipping"
fi

echo
echo "[fnm-sync-globals — keep npm globals consistent across node versions]"
if [ "$DRY" -eq 1 ]; then
  echo "  [dry] would run scripts/fnm-sync-globals.sh sync --quiet"
elif command -v fnm >/dev/null 2>&1; then
  "$REPO/scripts/fnm-sync-globals.sh" sync --quiet || echo "  ! sync had failures (run 'scripts/fnm-sync-globals.sh sync' for details)"
else
  echo "  ! fnm not in PATH — skipping"
fi

echo
echo "── done ──"
echo "Next steps:"
echo "  1. Add to ~/.zshrc_local (and source it from ~/.zshrc):"
echo "       export DOTFILES_AI_MACHINE=$MACHINE"
echo "       source \"$REPO/machines/\$DOTFILES_AI_MACHINE/env.sh\""
echo "  2. exec zsh"
echo "  3. Run: $REPO/scripts/doctor.sh"
