#!/usr/bin/env bash
# Arco machine env vars for Claude Code workflows.
# Source from ~/.zshrc (or ~/.zshrc_local):
#   export DOTFILES_AI_MACHINE=arco
#   source "$HOME/cangaco/.ai/machines/$DOTFILES_AI_MACHINE/env.sh"
#
# On the Arco machine: $HOME=/Users/gabriel.gripp

export NOTES_VAULT="$HOME/.notes"

# Plano da conta Claude nesta máquina.
# enterprise → conta corporativa sem janelas 5h/7d (statusline esconde esses campos).
# pro        → conta com janelas 5h/7d (default; statusline mostra ambas).
export DOTFILES_AI_PLAN=enterprise
