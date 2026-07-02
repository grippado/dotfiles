#!/usr/bin/env bash
# terminal.sh — ecossistema de terminal (tmux + sesh) do cangaço.
# Standalone e idempotente: pode rodar sozinho ou ser chamado pelo install.sh.
#
#   ./installers/terminal.sh          # instala ferramentas + religa symlinks
#
set -euo pipefail

# Localiza a raiz do repo (funciona com qualquer nome de diretório).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
TERM_DIR="$REPO/terminal"

log() { printf '==> %s\n' "$*"; }

link() { # link <src> <dst>
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak.$(date +%Y%m%d%H%M%S)"
    log "backup de $dst"
  fi
  ln -sf "$src" "$dst"
  log "linked $dst -> $src"
}

# ── Ferramentas (brew) ───────────────────────────────────────
# Nota: starship NÃO é instalado aqui de propósito — o shell usa Powerlevel10k.
if command -v brew >/dev/null 2>&1; then
  for f in tmux sesh tmuxp mprocs gum zoxide; do
    if brew list --formula "$f" >/dev/null 2>&1; then
      log "$f já instalado"
    else
      log "instalando $f..."
      brew install "$f"
    fi
  done
else
  log "brew ausente — pulando instalação de ferramentas"
fi

# ── TPM (tmux plugin manager) ────────────────────────────────
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  log "clonando TPM..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
else
  log "TPM já presente"
fi

# ── Symlinks de config ───────────────────────────────────────
link "$TERM_DIR/tmux/tmux.conf"   "$HOME/.tmux.conf"
link "$TERM_DIR/sesh/sesh.toml"   "$HOME/.config/sesh/sesh.toml"

# ── agent-dashboard (painel dos harnesses; build from source) ─
if ! command -v agent-dashboard >/dev/null 2>&1; then
  if command -v go >/dev/null 2>&1; then
    AD_DIR="$HOME/.local/share/agent-dashboard"
    [ -d "$AD_DIR/.git" ] || git clone --depth 1 https://github.com/bjornjee/agent-dashboard "$AD_DIR"
    ( cd "$AD_DIR" && ./install.sh --build )
    log "agent-dashboard buildado"
  else
    log "go ausente — pulando agent-dashboard (instale com: brew install go)"
  fi
else
  log "agent-dashboard já instalado"
fi

log "pronto. Abra o tmux e rode 'prefix + I' para instalar os plugins."
