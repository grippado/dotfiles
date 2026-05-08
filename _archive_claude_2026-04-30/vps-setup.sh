#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# FlagBridge VPS Setup — Ubuntu 22.04 (Hostinger)
#
# Prepares the VPS as a remote Claude Code dev environment.
# Run AFTER: SSH key added to GitHub, and dotfiles cloned.
#
# Usage:
#   ssh hq
#   git clone git@github.com:grippado/dotfiles.git ~/.dotfiles
#   chmod +x ~/.dotfiles/claude/vps-setup.sh
#   ~/.dotfiles/claude/vps-setup.sh
# ──────────────────────────────────────────────────────────────

echo '
╔══════════════════════════════════════════════════════════╗
║        FlagBridge VPS Setup — Remote Dev Environment     ║
╚══════════════════════════════════════════════════════════╝
'

DFL="${HOME}/.dotfiles"
WORKSPACE="${HOME}/www/flagbridge"

# ── 1. System packages ──────────────────────────────────────
echo ">>> [1/7] Installing system packages..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
  build-essential git curl wget unzip tmux jq \
  ca-certificates gnupg lsb-release \
  zsh ripgrep fd-find

# ── 2. FNM + Node.js ───────────────────────────────────────
echo ">>> [2/7] Installing FNM + Node.js..."
if ! command -v fnm &>/dev/null; then
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
  export PATH="${HOME}/.local/share/fnm:${PATH}"
  eval "$(fnm env)"
fi
fnm install --lts
fnm default lts-latest

# ── 3. pnpm ─────────────────────────────────────────────────
echo ">>> [3/7] Installing pnpm..."
if ! command -v pnpm &>/dev/null; then
  corepack enable
  corepack prepare pnpm@latest --activate 2>/dev/null || npm install -g pnpm
fi

# ── 4. Go ───────────────────────────────────────────────────
echo ">>> [4/7] Installing Go..."
GO_VERSION="1.24.2"
if ! command -v go &>/dev/null || [[ "$(go version)" != *"${GO_VERSION}"* ]]; then
  wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz
  rm /tmp/go.tar.gz
  export PATH="/usr/local/go/bin:${HOME}/go/bin:${PATH}"
fi

# ── 5. Claude Code ──────────────────────────────────────────
echo ">>> [5/7] Installing Claude Code..."
if ! command -v claude &>/dev/null; then
  npm install -g @anthropic-ai/claude-code
fi
echo "Claude Code version: $(claude --version 2>/dev/null || echo 'install pending')"

# ── 6. Dotfiles bootstrap ──────────────────────────────────
echo ">>> [6/7] Running dotfiles install..."
if [ -f "${DFL}/install.sh" ]; then
  # Run only Claude Code config part (full dotfiles install handles the rest)
  source "${DFL}/claude/install.sh"
else
  echo "WARNING: dotfiles not found at ${DFL}. Clone first:"
  echo "  git clone git@github.com:grippado/dotfiles.git ~/.dotfiles"
fi

# ── 7. Clone FlagBridge repos ──────────────────────────────
echo ">>> [7/7] Cloning FlagBridge repositories..."
mkdir -p "${WORKSPACE}"

REPOS=(
  "flagbridge/flagbridge"
  "flagbridge/admin"
  "flagbridge/landing"
  "flagbridge/docs"
  "flagbridge/sdk-node"
  "flagbridge/sdk-react"
  "flagbridge/sdk-go"
  "flagbridge/sdk-python"
  "flagbridge/openfeature-provider"
  "flagbridge/plugin-sdk"
  "flagbridge/cli"
  "flagbridge/create-plugin"
  "flagbridge/helm-charts"
  "flagbridge/db"
  "flagbridge/flagbridge-pro"
  "flagbridge/files"
  "flagbridge/.github"
)

for repo in "${REPOS[@]}"; do
  dir="${WORKSPACE}/$(basename "${repo}")"
  if [ -d "${dir}/.git" ]; then
    echo "  Already cloned: $(basename "${repo}")"
  else
    echo "  Cloning: ${repo}..."
    git clone "git@github.com:${repo}.git" "${dir}" 2>/dev/null || \
      echo "  SKIP: ${repo} (not found or no access)"
  fi
done

# ── Copy workspace-level files ─────────────────────────────
# These will be synced from local machine via sync-to-vps.sh:
# - CLAUDE.md, CONTEXT.md, CONTROL.md
# - .claude/ directory (project commands, settings)
# - docker-compose.yml, flagbridge.code-workspace

# ── tmux config ────────────────────────────────────────────
if [ ! -f "${HOME}/.tmux.conf" ]; then
  cat > "${HOME}/.tmux.conf" << 'TMUX'
# FlagBridge tmux config
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
set -g mouse on
set -g history-limit 50000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -s escape-time 0

# Status bar
set -g status-style 'bg=#1a1a2e fg=#e0e0e0'
set -g status-left '#[fg=#00d4ff,bold] #S '
set -g status-right '#[fg=#888888] %H:%M '

# Easy splits
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
TMUX
  echo "Created ~/.tmux.conf"
fi

# ── .zshrc_local for VPS paths ─────────────────────────────
if [ ! -f "${HOME}/.zshrc_local" ]; then
  cat > "${HOME}/.zshrc_local" << 'ZSHLOCAL'
# VPS-specific paths
export PATH="/usr/local/go/bin:${HOME}/go/bin:${PATH}"
export GOPATH="${HOME}/go"

# FNM
eval "$(fnm env)"

# FlagBridge workspace alias
alias fb="cd ~/www/flagbridge"
alias fbc="cd ~/www/flagbridge && claude"

# tmux auto-attach
if command -v tmux &>/dev/null && [ -z "$TMUX" ]; then
  tmux new-session -A -s flagbridge
fi
ZSHLOCAL
  echo "Created ~/.zshrc_local with VPS paths"
fi

echo '
╔══════════════════════════════════════════════════════════╗
║                  VPS Setup Complete!                      ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  Next steps (manual):                                    ║
║                                                          ║
║  1. From LOCAL machine, run:                             ║
║     ~/.dotfiles/claude/sync-to-vps.sh                    ║
║     (syncs Claude Code configs, memory, project files)   ║
║                                                          ║
║  2. Login to Claude Code:                                ║
║     claude auth login                                    ║
║                                                          ║
║  3. Configure MCP servers:                               ║
║     claude mcp add figma-remote-mcp \                    ║
║       --transport http \                                 ║
║       --url https://mcp.figma.com/mcp                    ║
║                                                          ║
║     cd ~/www/flagbridge                         ║
║     claude mcp add clickup \                             ║
║       --transport http \                                 ║
║       --url https://mcp.clickup.com/mcp \                ║
║       -s project                                         ║
║                                                          ║
║  4. Start working:                                       ║
║     tmux new -s flagbridge                               ║
║     cd ~/www/flagbridge && claude                ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
'
