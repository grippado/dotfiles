#!/usr/bin/env bash
# VPS machine env vars for Claude Code workflows.
# Headless 24/7 service node (hq.gripp.link), Ubuntu 24.
# Source from ~/.bashrc / ~/.zshrc on the VPS:
#   export DOTFILES_AI_MACHINE=vps
#   source "$HOME/cangaco/.ai/machines/$DOTFILES_AI_MACHINE/env.sh"
#
# On the VPS: $HOME=/home/grippado

export NOTES_VAULT="$HOME/.notes"

# Plano da conta Claude nesta máquina.
# enterprise → conta corporativa sem janelas 5h/7d.
# pro        → conta com janelas 5h/7d (default).
export DOTFILES_AI_PLAN=pro
