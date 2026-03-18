# Grippado Dotfiles

<div align="center">

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Linux](https://img.shields.io/badge/Linux-APT-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

```
  ▄▀  █▄▄▄▄ ▄█ █ ▄▄  █ ▄▄  ██   ██▄   ████▄
▄▀    █  ▄▀ ██ █   █ █   █ █ █  █  █  █   █
█ ▀▄  █▀▀▌  ██ █▀▀▀  █▀▀▀  █▄▄█ █   █ █   █
█   █ █  █  ▐█ █     █     █  █ █  █  ▀████
 ███    █    ▐  █     █       █ ███▀
       ▀         ▀     ▀     █
                            ▀
██▄   ████▄    ▄▄▄▄▀ ▄████  ▄█ █     ▄███▄     ▄▄▄▄▄
█  █  █   █ ▀▀▀ █    █▀   ▀ ██ █     █▀   ▀   █     ▀▄
█   █ █   █     █    █▀▀    ██ █     ██▄▄   ▄  ▀▀▀▀▄
█  █  ▀████    █     █      ▐█ ███▄  █▄   ▄▀ ▀▄▄▄▄▀
███▀          ▀       █      ▐     ▀ ▀███▀
                       ▀
```

</div>

## Features

- **Shell Environment** — ZSH + Oh-My-ZSH + Powerlevel10k, 150+ aliases, custom functions, FZF, FNM
- **Development Tools** — Neovim (LazyVim), Git with Conventional Commits, Docker/K8s tooling
- **Claude Code** — Agnostic agents, commands, and base config shared across machines
- **Modular Design** — Machine-specific paths, org aliases, and functions via local override files
- **Security** — Secrets management via `~/.secrets` (never committed)

## Quick Start

```bash
git clone git@github.com:grippado/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
chmod +x install.sh
./install.sh
```

## What Gets Installed

| Component | Description |
|-----------|-------------|
| **Package Manager** | Homebrew (macOS) or APT (Linux) |
| **Shell** | ZSH + Oh-My-Zsh + Powerlevel10k + plugins |
| **Tools** | git, curl, wget, neovim, fzf, fnm, btop |
| **Apps** (macOS) | Chrome, Brave, VS Code, iTerm2, Spotify, Rectangle |
| **Claude Code** | Base agents, commands, and settings (symlinked) |

## Directory Structure

```
.dotfiles/
├── install.sh              # Main installer
├── configs/
│   ├── git.sh              # Git global config
│   └── secrets.sh          # Secret loader (~/.secrets)
├── installers/
│   ├── package-manager.sh  # Homebrew/APT setup
│   ├── base.sh             # Core packages
│   ├── omzsh.sh            # Oh-My-Zsh
│   ├── fzf.sh              # Fuzzy finder
│   ├── zsh-plugins.sh      # ZSH plugins & themes
│   └── lazyvim.sh          # Neovim setup
├── zsh/
│   ├── .zshrc_base         # Main ZSH config
│   ├── .zsh_alias          # Aliases
│   ├── .zsh_functions      # Shell functions
│   ├── .zsh_git            # Conventional Commits helper
│   └── .zsh_gcloud         # Google Cloud SDK (legacy)
└── claude/
    ├── install.sh           # Claude config installer
    ├── settings.json        # Base plugin config (agnostic)
    ├── CLAUDE.md            # Global workspace instructions
    ├── agents/              # Shared agents
    │   ├── code-reviewer.md
    │   ├── refactorer.md
    │   ├── bug-hunter.md
    │   └── test-writer.md
    └── commands/            # Shared commands
        ├── review-changes.md
        ├── explain.md
        ├── quick-commit.md
        ├── dep-check.md
        └── scaffold.md
```

## Local Overrides (Not Tracked)

The installer creates these files on first run for machine-specific config:

| File | Purpose |
|------|---------|
| `~/.zshrc_local` | Machine-specific paths (Go, Java, PSQL, etc.) |
| `~/.zsh_aliases_local` | Org-specific aliases (project shortcuts, etc.) |
| `~/.zsh_functions_local` | Org-specific functions |
| `~/.secrets` | API tokens and credentials |

These files are loaded automatically by the dotfiles but are **never committed** to the repo.

## Claude Code

The `claude/` directory contains agnostic Claude Code configs that work on any machine:

**Agents:**
- `code-reviewer` — Thorough code review with security/perf/readability checks
- `refactorer` — Safe refactoring without behavior changes
- `bug-hunter` — Systematic bug investigation
- `test-writer` — Test generation matching project conventions

**Commands (slash commands):**
- `/review-changes` — Review all uncommitted changes
- `/explain <target>` — Explain how code/systems work
- `/quick-commit` — Conventional commit helper
- `/dep-check` — Dependency audit
- `/scaffold <what>` — Generate boilerplate from project patterns

The Claude installer symlinks these to `~/.claude/` without overwriting existing local configs. To add org-specific agents or settings, use project-level `.claude/` directories or edit `~/.claude/settings.json` directly.

## Manual Setup

After installation, edit your local override files:

```bash
# Add machine-specific paths
vim ~/.zshrc_local

# Add org-specific aliases
vim ~/.zsh_aliases_local

# Add secrets
vim ~/.secrets
```

---

# Portugues

## Inicio Rapido

```bash
git clone git@github.com:grippado/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
chmod +x install.sh
./install.sh
```

## Arquivos Locais (Nao Rastreados)

O instalador cria estes arquivos para configuracao especifica da maquina:

- `~/.zshrc_local` — Paths especificos (Go, Java, PSQL)
- `~/.zsh_aliases_local` — Aliases da organizacao
- `~/.zsh_functions_local` — Funcoes da organizacao
- `~/.secrets` — Tokens e credenciais

## Claude Code

O diretorio `claude/` contem configuracoes agnosticas do Claude Code:

- **Agents**: code-reviewer, refactorer, bug-hunter, test-writer
- **Comandos**: /review-changes, /explain, /quick-commit, /dep-check, /scaffold

O instalador cria symlinks em `~/.claude/` sem sobrescrever configs locais existentes.

## Licenca

MIT - Copyright 2023 Gabriel Gripp
