<div align="center">

```
  ___ __ _ _ __   __ _  __ _  ___ ___
 / __/ _` | '_ \ / _` |/ _` |/ __/ _ \
| (_| (_| | | | | (_| | (_| | (_| (_) |
 \___\__,_|_| |_|\__, |\__,_|\___\___/
                 |___/
```

**O bando que anda comigo em toda máquina.**

Dotfiles, cérebro de IA, orquestração de terminal e editores, num repositório só, versionado e idempotente.

![macOS](https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-APT-FCC624?logo=linux&logoColor=black)
![Shell](https://img.shields.io/badge/shell-zsh%20%2B%20p10k-89e051?logo=gnubash&logoColor=white)
![Claude Code](https://img.shields.io/badge/Claude%20Code-Atlas-d97757)
![License](https://img.shields.io/badge/license-MIT-blue)

</div>

---

## Por que "cangaço"

No sertão, o cangaço era o bando: gente que andava junta, cada um com sua função, leais ao grupo e ao chefe. Aqui é a mesma ideia aplicada ao meu ambiente de trabalho.

Em vez de configuração espalhada por quinze lugares, um bando só de configs, agents e harnesses que viaja comigo de máquina em máquina. Clona o repo, roda um instalador, e a máquina nova já nasce com a minha cara: shell, terminal, editores e, principalmente, o cérebro de IA que orquestra tudo.

> **A metáfora vira nome de verdade no código.** O sistema pessoal de IA chama [**Lampião**](.ai/claude/skills/maria-bonita/SKILL.md). A Claude, quando entra em modo parceira opinativa, atende por **Maria Bonita**. E a arquitetura que mantém tudo sem ambiguidade de fonte da verdade chama [**Atlas**](.ai/claude/ARCHITECTURE.md).

---

## Os quatro pilares

```
                          ┌─────────────────────────────┐
                          │           cangaço           │
                          └──────────────┬──────────────┘
            ┌──────────────┬─────────────┼─────────────┬──────────────┐
            ▼              ▼             ▼             ▼              ▼
      ╔═══════════╗  ╔═══════════╗ ╔═══════════╗ ╔═══════════╗  ╔═══════════╗
      ║   shell   ║  ║    .ai    ║ ║ terminal  ║ ║ editores  ║  ║ máquinas  ║
      ║   zsh +   ║  ║   Claude  ║ ║  Ghostty  ║ ║   Zed +   ║  ║ personal  ║
      ║   p10k    ║  ║   Atlas   ║ ║  + tmux   ║ ║  LazyVim  ║  ║ arco/vps  ║
      ╚═══════════╝  ╚═══════════╝ ╚═══════════╝ ╚═══════════╝  ╚═══════════╝
```

| Pilar | O que é | Doc |
|-------|---------|-----|
| **Shell** | zsh + Oh-My-Zsh + Powerlevel10k, 150+ aliases, funções, FZF, FNM | (este README) |
| **`.ai/` (Atlas)** | Fonte da verdade da config do Claude Code: 18 comandos, 23 agents, skills, MCP local de notas, modelo multi-máquina | [`.ai/README.md`](.ai/README.md) · [`ARCHITECTURE.md`](.ai/claude/ARCHITECTURE.md) |
| **Terminal** | Ghostty (GPU) + tmux (persistência) + sesh/tmuxp para orquestrar uma frota de harnesses de IA | [`terminal/README.md`](terminal/README.md) · [`CHEATSHEET.md`](terminal/CHEATSHEET.md) |
| **Editores** | Config versionada do Zed (settings, keymap, temas) e setup do Neovim (LazyVim) | (este README) |

---

## Índice

- [Início rápido](#início-rápido)
- [Anatomia do repositório](#anatomia-do-repositório)
- [Pilar 1: shell e dotfiles](#pilar-1-shell-e-dotfiles)
- [Pilar 2: `.ai/`, o cérebro Atlas](#pilar-2-ai-o-cérebro-atlas)
- [Pilar 3: terminal e a frota de harnesses](#pilar-3-terminal-e-a-frota-de-harnesses)
- [Pilar 4: editores](#pilar-4-editores)
- [Modelo multi-máquina](#modelo-multi-máquina)
- [Overrides locais e segredos](#overrides-locais-e-segredos)
- [Manutenção](#manutenção)
- [Princípios de organização](#princípios-de-organização)
- [Repositórios do bando](#repositórios-do-bando)
- [Licença](#licença)

---

## Início rápido

```bash
git clone git@github.com:grippado/cangaco.git ~/cangaco
cd ~/cangaco
./install.sh
```

Isso liga o **pilar de sistema** (shell, terminal, editores). É idempotente: pode rodar de novo sem medo. Ele instala o gerenciador de pacotes (Homebrew no macOS, APT no Linux), zsh + plugins, FZF, Neovim, o ecossistema de terminal e os symlinks do Zed; depois cria os arquivos de override local (veja [Overrides locais](#overrides-locais-e-segredos)).

Em seguida, ligue o **cérebro de IA** apontando para a máquina certa:

```bash
cd ~/cangaco/.ai
./install.sh --machine personal --dry-run   # inspeciona o que vai mudar
./install.sh --machine personal             # aplica
```

> ⚠️ **Rode o install do `.ai/` sentado na máquina física, nunca por mount remoto.** O `atlas-sync` expande `$HOME` em tempo de execução para gravar paths absolutos nos symlinks. Por SMB/SSH montado, o `$HOME` seria o da máquina errada. Detalhe em [`.ai/README.md`](.ai/README.md).

---

## Anatomia do repositório

```
cangaco/
├── install.sh            # instalador do sistema (shell, terminal, editores)
├── configs/
│   ├── git.sh            # config global do git
│   ├── repos.txt         # mapa de repos do bando (clone-all)
│   └── secrets.sh        # carregador de ~/.secrets
├── installers/           # módulos idempotentes, um por responsabilidade
│   ├── package-manager.sh
│   ├── base.sh
│   ├── omzsh.sh
│   ├── fzf.sh
│   ├── zsh-plugins.sh
│   ├── lazyvim.sh
│   └── terminal.sh
├── zsh/                  # config de shell versionada
│   ├── .zshrc_base
│   ├── .zsh_alias
│   ├── .zsh_functions
│   ├── .zsh_git          # helpers de Conventional Commits
│   └── .zsh_gcloud
├── terminal/             # Ghostty + tmux + sesh + frota de agentes  -> README próprio
├── zed/                  # settings, keymap e temas do Zed
└── .ai/                  # cérebro Atlas (Claude Code)               -> README próprio
    ├── install.sh        # symlinks de config p/ ~/.claude (--machine, --dry-run)
    ├── claude/           # CLAUDE.md, settings, 18 comandos, 23 agents, skills
    ├── machines/         # personal / arco / vps (REGISTRY + overlays + env)
    ├── contexts/         # templates de contexto por ambiente
    ├── notes-mcp/        # MCP local (stdio) sobre o vault Obsidian
    └── scripts/          # doctor.sh, merge-settings.sh, fnm-sync-globals.sh
```

Cada subsistema com vida própria carrega o seu próprio README. Este aqui é o mapa; os detalhes moram perto do dono.

---

## Pilar 1: shell e dotfiles

O `install.sh` da raiz monta um shell consistente em qualquer máquina:

- **zsh + Oh-My-Zsh + Powerlevel10k**, plugins de autosuggestion e syntax-highlighting.
- **150+ aliases** e funções em [`zsh/.zsh_alias`](zsh/.zsh_alias) e [`zsh/.zsh_functions`](zsh/.zsh_functions).
- **Helpers de Conventional Commits** em [`zsh/.zsh_git`](zsh/.zsh_git).
- **FZF** e **FNM** (Node) já cabeados.

O instalador é **modular**: cada peça é um script isolado em [`installers/`](installers/), e o `install.sh` só os encadeia. Quer entender o que entra na máquina? Cada arquivo faz uma coisa só e diz o que faz.

`configs/repos.txt` guarda o **mapa do bando**: o conjunto de repositórios (pessoais e de trabalho) que andam junto, no formato `path<TAB>git-url`, pronto para um clone em massa.

---

## Pilar 2: `.ai/`, o cérebro Atlas

O coração do repo. `.ai/` é a **fonte única da verdade** da minha configuração do Claude Code, versionada e espelhada por symlink em `~/.claude/` em cada máquina.

> Doc completa: [`.ai/README.md`](.ai/README.md). Arquitetura, ADRs e princípios: [`.ai/claude/ARCHITECTURE.md`](.ai/claude/ARCHITECTURE.md).

O que vive aqui:

| Item | Quantidade | Onde |
|------|------------|------|
| **Comandos** (slash commands) | 18 | [`.ai/claude/commands/`](.ai/claude/commands/) |
| **Agents** especializados | 23 | [`.ai/claude/agents/`](.ai/claude/agents/) |
| **Skills** | maria-bonita | [`.ai/claude/skills/`](.ai/claude/skills/) |
| **MCP local de notas** | notes-mcp | [`.ai/notes-mcp/`](.ai/notes-mcp/) |

**Modelo de duas camadas de comandos:**

1. **Globais genéricos** (`ship`, `qa`, `quick-commit`, `explain`, `scaffold`): funcionam em qualquer codebase, viram symlink em `~/.claude/commands/`.
2. **Escopados por repo** (`organize:notes`, `sync:flagbridge`): a fonte da verdade mora no `.claude/` do próprio repo de produto; o `atlas-sync` só os torna alcançáveis de qualquer diretório, com nomenclatura `<verbo>:<scope>.md`.

**notes-mcp** é um servidor MCP local (stdio) que dá ao Claude Desktop busca semântica + full-text sobre o meu vault Obsidian. Roda 100% na máquina: embeddings gerados localmente, nada do segundo cérebro sai pra fora. Detalhe em [`.ai/notes-mcp/README.md`](.ai/notes-mcp/README.md).

---

## Pilar 3: terminal e a frota de harnesses

Camadas independentes que, juntas, transformam o terminal num cockpit de orquestração de múltiplos agentes de IA rodando em paralelo:

- **Ghostty**: rendering por GPU, splits/tabs efêmeros, quick terminal dropdown.
- **tmux** (`prefix = C-a`): persistência de sessão (sobrevive a fechar a janela via `resurrect` + `continuum`) e a base programável da orquestração.
- **sesh / tmuxp**: sessões e layouts declarativos. `fleet` sobe a frota inteira a partir de [`terminal/tmuxp/agent-fleet.yaml`](terminal/tmuxp/agent-fleet.yaml).
- **agent-dashboard**: painel TUI com o estado de cada harness (blocked / running / review / PR / merged), aberto num popup com `prefix + D`.

Fluxo típico: `claude --worktree` para isolar cada agente num git worktree, `agent-new <nome>` para subir harnesses em janelas próprias, e o dashboard para observar e despachar input pra quem travou.

> Guia completo e tabela de atalhos: [`terminal/README.md`](terminal/README.md) e [`terminal/CHEATSHEET.md`](terminal/CHEATSHEET.md).

---

## Pilar 4: editores

- **Zed**: `settings.json`, `keymap.json` e a pasta de temas, todos versionados em [`zed/`](zed/) e symlinkados para `~/.config/zed/`. O instalador também expõe o CLI `zed` no PATH, espelhando `code`/`cursor`.
- **Neovim (LazyVim)**: setup via [`installers/lazyvim.sh`](installers/lazyvim.sh).

---

## Modelo multi-máquina

O mesmo repo serve três perfis sem `if` espalhado: a diferença mora em [`.ai/machines/<perfil>/`](.ai/machines/).

| Máquina | Perfil | `$HOME` típico |
|---------|--------|----------------|
| **personal** | Mac pessoal | `/Users/grippado` |
| **arco** | Mac de trabalho | `/Volumes/gabriel.gripp` |
| **vps** | servidor headless | `/root` ou similar |

Cada perfil traz:

- `REGISTRY.json`: a **única** fonte de verdade de `scope -> path` (onde mora cada repo de produto).
- `settings.overlay.json`: plugins e ajustes específicos da máquina, mesclados sobre o `settings.base.json` comum.
- `env.sh`: variáveis de ambiente (ex.: `NOTES_VAULT`).

Você seleciona o perfil com `--machine <perfil>` ou exportando `DOTFILES_AI_MACHINE`. Mover um repo de lugar? Edita uma linha no `REGISTRY.json` e roda `atlas-sync`. Nada mais precisa saber onde os repos moram.

---

## Overrides locais e segredos

Nada específico de máquina ou sensível entra no repo. O instalador cria estes arquivos no primeiro run, e o `.gitignore` garante que eles nunca sejam commitados:

| Arquivo | Para quê |
|---------|----------|
| `~/.zshrc_local` | Paths específicos da máquina (Go, Java, PSQL, ...) |
| `~/.zsh_aliases_local` | Aliases da organização / projeto |
| `~/.zsh_functions_local` | Funções da organização / projeto |
| `~/.secrets` | Tokens e credenciais (carregado por [`configs/secrets.sh`](configs/secrets.sh)) |

São carregados automaticamente pelo shell, mas vivem fora do versionamento.

---

## Manutenção

```bash
# valida o estado da instalação do cérebro Atlas
~/cangaco/.ai/scripts/doctor.sh

# regenera ~/.claude/settings.json a partir de base + overlay da máquina
~/cangaco/.ai/scripts/merge-settings.sh <perfil>
```

Adicionar um comando ou agent global é um `git push` de um lado e `git pull && ./install.sh --machine <perfil>` do outro. Toda mudança que o `atlas-sync` faz é rastreada e reversível: ele só remove o que ele mesmo criou, nunca toca em arquivo escrito à mão.

---

## Princípios de organização

O que mantém esse bando organizado, em vez de virar mais uma pasta de dotfiles bagunçada (extraído de [`ARCHITECTURE.md`](.ai/claude/ARCHITECTURE.md)):

1. **Uma fonte da verdade por coisa.** Sem mirror parcial, sem "qual dos dois é o canônico". O `REGISTRY.json` resolve `scope -> path`; o resto deriva dele.
2. **A fonte da verdade fica perto do dono.** Comando de um repo de produto mora no `.claude/` daquele repo; o que existe em `~/.claude/` é symlink, não cópia.
3. **Verbo puro só pra genérico de verdade.** Se um comando depende de um repo, ele carrega `:scope` no nome. Aliases são sempre explícitos, nunca inferidos pelo filesystem.
4. **Drift é detectado, não previsto.** Um snapshot diário registra desvios; se o número sobe do nada, eu fico sabendo.
5. **Toda automação é reversível.** O que é gerado automaticamente é rastreado e some com um comando. Arquivo escrito à mão nunca é tocado por script.
6. **Repo de time é read-only pro Atlas.** Em scope compartilhado, o Atlas só indexa (expõe globalmente), nunca modifica. Mudança em repo de time é PR, não operação local.

---

## Repositórios do bando

| Repo | Papel |
|------|-------|
| [`grippado/cangaco`](https://github.com/grippado/cangaco) | Este repo: dotfiles + cérebro + terminal + editores |
| `grippado/ai-memory-sync` | Hooks de memória (Stop / SessionStart) referenciados pelo `settings.base.json` |
| `grippado/notes` | Vault Obsidian (segundo cérebro). `$NOTES_VAULT` aponta pra cá |

---

## Licença

[MIT](LICENSE) · Copyright (c) 2023 Gabriel Gripp
