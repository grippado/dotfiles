#!/usr/bin/env bash
# VPS machine env vars for Claude Code workflows.
# Headless 24/7 service node (hq.gripp.link), Ubuntu 24 — sourced in the VPS's
# own shell (the VPS does not mount any other machine's home).
# Source from ~/.bashrc / ~/.zshrc on the VPS:
#   export DOTFILES_AI_MACHINE=vps
#   source "$HOME/cangaco/.ai/machines/$DOTFILES_AI_MACHINE/env.sh"

export NOTES_VAULT="$HOME/.notes"

# Plano da conta Claude nesta máquina.
# enterprise → conta corporativa sem janelas 5h/7d.
# pro        → conta com janelas 5h/7d (default).
export DOTFILES_AI_PLAN=pro
