# Dotfiles Workspace

Global preferences (language, commits, pnpm, subagent orchestration) live in `~/.claude/CLAUDE.md`.
This file covers dotfiles-specific context only.

## Environment

- Shell: ZSH with Oh-My-Zsh and Powerlevel10k
- Editor: Neovim (LazyVim)
- Node management: FNM
- See `zsh/.zsh_git` for the full conventional commit function with emoji prefixes

## Machine-Specific Overrides

Organization-specific agents, commands, and settings should be configured in:
- Project-level `.claude/` directories (per-repo)
- `~/.claude/settings.json` (manually managed per machine, not overwritten by dotfiles)
- `~/.zshrc_local` (machine-specific shell config, not tracked)
