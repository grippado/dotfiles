#!/usr/bin/env bash
# Arco machine env vars for Claude Code workflows.
# Source from ~/.zshrc (or ~/.zshrc_local):
#   export DOTFILES_AI_MACHINE=arco
#   source "$HOME/www/personal/dotfiles-ai/machines/$DOTFILES_AI_MACHINE/env.sh"
#
# Uses $HOME so it works from both:
#   - the Arco machine itself ($HOME=/Users/gabriel.gripp)
#   - the personal machine via SMB mount of Arco's home ($HOME=/Volumes/gabriel.gripp)

export NOTES_VAULT="$HOME/www/personal/notes"
