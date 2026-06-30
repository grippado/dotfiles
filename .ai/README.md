# `.ai/` — o cérebro Atlas

> Parte do [cangaço](../README.md). Este doc é a fonte da verdade para a configuração do Claude Code: comandos, agents, skills, MCP local de notas e modelo multi-máquina.

O `.ai/` é a **fonte única da verdade** da minha configuração do Claude Code. Tudo aqui é versionado e espelhado por symlink em `~/.claude/` em cada máquina. A arquitetura, ADRs e princípios vivem em [`claude/ARCHITECTURE.md`](claude/ARCHITECTURE.md).

> Configs **dentro de repos de produto** (`<repo>/.claude/...`) **não** entram aqui — continuam versionadas em cada repo. O Atlas só indexa (symlinks) ou mantém o que é global.

---

## Índice

- [Início rápido](#início-rápido)
- [Anatomia](#anatomia)
- [O que vive aqui](#o-que-vive-aqui)
- [Duas camadas de comandos](#duas-camadas-de-comandos)
- [Modelo multi-máquina](#modelo-multi-máquina)
- [Workflow](#workflow)
- [Validação](#validação)
- [Docs relacionados](#docs-relacionados)

---

## Início rápido

### Personal (macOS, `$HOME` = `/Users/grippado`)

```bash
cd ~/cangaco/.ai
./install.sh --machine personal --dry-run   # inspeciona
./install.sh --machine personal             # aplica
```

Adicionar ao `~/.zshrc_local` (e `source ~/.zshrc_local` a partir do `~/.zshrc`):

```bash
export DOTFILES_AI_MACHINE=personal
source "$HOME/cangaco/.ai/machines/$DOTFILES_AI_MACHINE/env.sh"
```

Depois: `exec zsh && ./scripts/doctor.sh`.

### Arco (macOS, `$HOME` = `/Users/gabriel.gripp`)

```bash
cd ~/cangaco/.ai
./install.sh --machine arco --dry-run
./install.sh --machine arco
```

`~/.zshrc_local`:

```bash
export DOTFILES_AI_MACHINE=arco
source "$HOME/cangaco/.ai/machines/$DOTFILES_AI_MACHINE/env.sh"
```

Clone do memory-sync (obrigatório em toda máquina):

```bash
git clone git@github.com:grippado/ai-memory-sync.git ~/.ai-memory-sync
```

### VPS (servidor headless)

```bash
cd ~/cangaco/.ai
./install.sh --machine vps --dry-run
./install.sh --machine vps
```

> ⚠️ **Rode o install na máquina física, nunca por mount remoto.** O `atlas-sync` expande `$HOME` em tempo de execução para gravar paths absolutos nos symlinks. Por SMB/SSH montado, o `$HOME` seria o da máquina errada.

---

## Anatomia

```
.ai/
├── install.sh                     # instalador idempotente (--machine, --dry-run)
├── claude/                        # symlinkado em ~/.claude/
│   ├── CLAUDE.md                  # instruções globais
│   ├── ARCHITECTURE.md            # ADRs e princípios Atlas
│   ├── settings.base.json         # settings compartilhados (hooks, statusline, theme)
│   ├── commands/                  # 18 comandos globais
│   ├── agents/                    # 21 agents globais + suites Isaac
│   ├── skills/                    # maria-bonita (Lampião / Maria Bonita)
│   └── bin/                       # atlas-sync, atlas-snapshot, ccstatusline
├── machines/
│   ├── personal/                  # REGISTRY + overlay + env.sh
│   ├── arco/
│   └── vps/
├── contexts/                      # overlays de workspace (personal / arco)
├── notes-mcp/                     # MCP local sobre o vault Obsidian
├── bin/                           # ide-memory-harvest + ide-adapters
└── scripts/
    ├── doctor.sh                  # sanity check da instalação
    ├── merge-settings.sh          # base + overlay → ~/.claude/settings.json
    └── fnm-sync-globals.sh        # npm globals consistentes entre versões Node
```

---

## O que vive aqui

| Item | Quantidade | Onde |
|------|------------|------|
| **Comandos** (slash commands globais) | 18 | [`claude/commands/`](claude/commands/) |
| **Agents** globais | 21 | [`claude/agents/`](claude/agents/) · [catálogo](claude/agents/README.md) |
| **Agents** Isaac (por repo) | 6 suites | [`claude/agents/isaac/`](claude/agents/isaac/) · [AGENT_SPEC](claude/agents/isaac/AGENT_SPEC.md) |
| **Skills** | maria-bonita | [`claude/skills/`](claude/skills/) |
| **MCP local de notas** | notes-mcp | [`notes-mcp/`](notes-mcp/) |
| **Harvest de memórias IDE** | ide-adapters | [`bin/ide-adapters/`](bin/ide-adapters/) |

---

## Duas camadas de comandos

Há dois mecanismos complementares para slash commands em `~/.claude/commands/`:

1. **Globais genéricos** — `.md` commitados em `claude/commands/`. Symlinkados pelo `install.sh`. Funcionam em qualquer codebase (`ship`, `qa`, `quick-commit`, `explain`, `scaffold`, …).
2. **Escopados por repo** — symlinks gerados pelo `atlas-sync` apontando para `<repo>/.claude/commands/*.md`. O repo é a fonte da verdade; o Atlas só os torna alcançáveis globalmente. Nomenclatura: `<verbo>:<scope>.md` (ex.: `organize:notes.md`). Se o frontmatter define `alias_global: true`, o `atlas-sync` também cria `<verbo>.md` como alias global.

---

## Modelo multi-máquina

| Máquina | Perfil | `$HOME` típico |
|---------|--------|----------------|
| **personal** | Mac pessoal | `/Users/grippado` |
| **arco** | Mac de trabalho | `/Users/gabriel.gripp` |
| **vps** | servidor headless | `/root` ou similar |

Cada perfil traz:

- `REGISTRY.json` — fonte da verdade de `scope → path` (onde mora cada repo de produto).
- `settings.overlay.json` — plugins e ajustes específicos, mesclados sobre `settings.base.json`.
- `env.sh` — variáveis de ambiente (`NOTES_VAULT`, `DOTFILES_AI_PLAN`, …).

Selecione o perfil com `--machine <perfil>` ou exportando `DOTFILES_AI_MACHINE`. Mover um repo? Edita uma linha no `REGISTRY.json` e roda `atlas-sync`.

---

## Workflow

- **Novo comando/agent global** → drop o `.md` em `claude/commands/` ou `claude/agents/`, commit, push. Na outra máquina: `git pull && ./install.sh --machine <m>`.
- **Novo scope** → edita `machines/<m>/REGISTRY.json`, commit, push, depois na máquina-alvo: `git pull && ~/.claude/bin/atlas-sync` (ou re-roda `./install.sh`).
- **Ajustar settings** → edita `claude/settings.base.json` (compartilhado) ou `machines/<m>/settings.overlay.json` (só da máquina), depois `./scripts/merge-settings.sh <m>`.
- **Novo contexto de workspace** → ver runbook no vault: `~/.notes/1-contexts/dotfiles-ai/runbooks/add-context.md`.

---

## Validação

```bash
# sanity check da instalação Atlas
~/cangaco/.ai/scripts/doctor.sh

# regenera ~/.claude/settings.json a partir de base + overlay
~/cangaco/.ai/scripts/merge-settings.sh <perfil>

# valida consistência da documentação (sem drift de nomenclatura/paths)
~/cangaco/scripts/docs-check.sh
```

Toda mudança que o `atlas-sync` faz é rastreada e reversível: ele só remove o que ele mesmo criou (`.atlas-managed`), nunca toca em arquivo escrito à mão.

---

## Runtime files que NÃO entram no repo

Estes vivem em `~/.claude/` diretamente e nunca são commitados:

- `plugins/`, `projects/`, `cache/`, `file-history/`, `paste-cache/`, `shell-snapshots/`
- `backups/`, `history.jsonl`, `sessions/`, `todos/`, `ide/`, `telemetry/`, `statsig/`
- `*-cost-day*.json`, `stats-cache.json`, `mcp-needs-auth-cache.json`, `.atlas-managed`
- O `settings.json` final (regenerado por `merge-settings.sh`)

---

## Docs relacionados

| Doc | Conteúdo |
|-----|----------|
| [README principal](../README.md) | Mapa do cangaço — quatro pilares, anatomia, início rápido |
| [`claude/ARCHITECTURE.md`](claude/ARCHITECTURE.md) | ADRs, princípios, convenções de naming |
| [`claude/agents/README.md`](claude/agents/README.md) | Catálogo dos 21 agents globais |
| [`notes-mcp/README.md`](notes-mcp/README.md) | MCP local sobre o vault Obsidian |
| [`contexts/arco/README.md`](contexts/arco/README.md) | Overlay do workspace Isaac |
| [`contexts/personal/README.md`](contexts/personal/README.md) | Overlay do workspace pessoal |
| [`bin/ide-adapters/README.md`](bin/ide-adapters/README.md) | Contrato dos adapters de memória IDE |
| [`terminal/README.md`](../terminal/README.md) | Ghostty + tmux + frota de harnesses |

## Repos relacionados

- `git@github.com:grippado/ai-memory-sync.git` — hooks de memória (Stop/SessionStart) referenciados pelo `settings.base.json`. Clone em `$HOME/.ai-memory-sync` em toda máquina.
- `git@github.com:grippado/notes.git` — vault Obsidian. `$NOTES_VAULT` aponta pra cá.
