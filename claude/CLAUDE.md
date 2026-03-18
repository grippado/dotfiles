# Grippado Global Workspace

This is the global Claude Code configuration shared across all machines via dotfiles.

## Preferences

- Language: Brazilian Portuguese for communication when context is clear, English for code and technical terms
- Commit style: Conventional Commits with emoji prefixes (see zsh/.zsh_git for the full commit function)
- Shell: ZSH with Oh-My-Zsh and Powerlevel10k
- Editor: Neovim (LazyVim)
- Node management: FNM
- Package managers: pnpm (preferred), yarn, npm

## Workflow

- Always use conventional commits
- Prefer pnpm over yarn/npm for new projects
- Use direnv for environment management
- Use FZF-based tooling when available

## Machine-Specific Overrides

Organization-specific agents, commands, and settings should be configured in:
- Project-level `.claude/` directories (per-repo)
- `~/.claude/settings.json` (manually managed per machine, not overwritten by dotfiles)
- `~/.zshrc_local` (machine-specific shell config, not tracked)
