# terminal/ — tmux + orquestração de harnesses

> Parte do [cangaço](../README.md). Este doc é a fonte da verdade para o ecossistema de terminal: persistência e frota de agentes de IA.

Camadas independentes que, juntas, transformam o terminal num cockpit de orquestração:

```
  tmux (persistência, prefix C-a)
       │
       ├── sesh / tmuxp (sessões declarativas, fleet)
       └── agent-dashboard (estado dos harnesses)
```

Atalhos completos: [`CHEATSHEET.md`](CHEATSHEET.md).

---

## Instalação

```bash
./installers/terminal.sh   # idempotente; também roda dentro do install.sh da raiz
```

Instala `tmux sesh tmuxp mprocs gum zoxide`, clona o TPM, builda o `agent-dashboard`
(precisa de Go) e cria os symlinks:

| Config | Symlink |
|--------|---------|
| `terminal/tmux/tmux.conf` | `~/.tmux.conf` |
| `terminal/sesh/sesh.toml` | `~/.config/sesh/sesh.toml` |

Dentro do tmux, na primeira vez: `prefix + I` instala os plugins (o installer já
faz isso headless numa máquina nova).

---

## Fluxo típico

1. **Isolar** — `claude --worktree` (git worktree nativo).
2. **Subir harnesses** — `agent-new fix-login`, `agent-new refactor`, … ou declarativo via `fleet` (`terminal/tmuxp/agent-fleet.yaml`).
3. **Observar** — `prefix + D` abre o agent-dashboard (blocked / running / review / PR / merged) e despacha input pra quem travou.

---

## Atalhos essenciais

tmux (prefix = `C-a`):

| Tecla | Ação |
|-------|------|
| `prefix + I` | instala plugins (TPM) |
| `prefix + r` | recarrega tmux.conf |
| `prefix + D` | abre o agent-dashboard num popup |
| `prefix + o` | sessionx (fuzzy-find de sessões) |
| `prefix + h/j/k/l` | navega entre panes |
| `prefix + \| / -` | split horizontal / vertical (no cwd) |
| `prefix + H/J/K/L` | redimensiona pane |

Shell:

| Comando | Ação |
|---------|------|
| `ss` | fuzzy-pick de sessão (sesh + fzf) |
| `sl` | lista sessões |
| `fleet` | sobe a frota de agentes (tmuxp agent-fleet.yaml) |
| `agent-new <nome> [cmd]` | sobe um harness isolado (worktree) numa window própria |

> Tabela completa: [`CHEATSHEET.md`](CHEATSHEET.md).

---

## Plugin do agent-dashboard no Claude Code

Rodar dentro do Claude Code:

```
/marketplace add bjornjee/agent-dashboard
/plugin install agent-dashboard@agent-dashboard
/plugin enable agent-dashboard@agent-dashboard
```

Depois reinicie as sessões do Claude Code para os hooks ativarem.

---

## Notas

- **Starship não é usado**: o shell roda Powerlevel10k. Se um dia quiser trocar,
  é um passo isolado (remover ZSH_THEME do `.zshrc_base` + `eval "$(starship init zsh)"`).
- **Persistência**: `tmux-resurrect` + `tmux-continuum` salvam/restauram sessões
  a cada 15 min — sessões de agente sobrevivem a fechar a janela.
- **Catppuccin tmux**: versão pinada (`v2.1.2`); a v2 quebrou a API da v1.

---

## Docs relacionados

| Doc | Conteúdo |
|-----|----------|
| [README principal](../README.md) | Mapa do cangaço — pilar terminal |
| [`CHEATSHEET.md`](CHEATSHEET.md) | Referência completa de atalhos tmux |
| [`.ai/README.md`](../.ai/README.md) | Cérebro Atlas — orquestração de agentes Claude Code |
