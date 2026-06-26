#!/usr/bin/env bash
# Personal machine env vars for Claude Code workflows.
# Source from ~/.zshrc_local (or equivalent):
#   export DOTFILES_AI_MACHINE=personal
#   source "$HOME/.dotfiles-ai/machines/$DOTFILES_AI_MACHINE/env.sh"

export NOTES_VAULT="$HOME/.notes"

# Plano da conta Claude nesta máquina.
# enterprise → conta corporativa sem janelas 5h/7d.
# pro        → conta com janelas 5h/7d (default).
export DOTFILES_AI_PLAN=pro

# Optional: notification daemon (Superset). Leave unset if not used.
# export SUPERSET_HOME_DIR="$HOME/www/personal/superset"
