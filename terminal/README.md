# terminal/ — Ghostty + tmux + orquestração de harnesses

Ecossistema de terminal do cangaço. Camadas independentes:

- **Ghostty** = rendering (GPU), splits/tabs efêmeros, quick terminal dropdown.
- **tmux** = persistência de sessão + base programável da orquestração de agentes.
- **sesh / tmuxp** = sessões e layouts declarativos.
- **agent-dashboard** = painel TUI do estado de cada harness.

## Instalação

```bash
./installers/terminal.sh   # idempotente; também roda dentro do install.sh
```

Instala `tmux sesh tmuxp mprocs gum zoxide`, clona o TPM, builda o `agent-dashboard`
(precisa de Go) e cria os symlinks:

| Config | Symlink |
|--------|---------|
| `terminal/ghostty/config` | `~/.config/ghostty/config` |
| `terminal/tmux/tmux.conf` | `~/.tmux.conf` |
| `terminal/sesh/sesh.toml` | `~/.config/sesh/sesh.toml` |

Dentro do tmux, na primeira vez: `prefix + I` instala os plugins (o installer já
faz isso headless numa máquina nova).

## Atalhos

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

Ghostty: `cmd+\`` quick terminal · `cmd+d`/`cmd+shift+d` split · `cmd+alt+setas`
navega · `cmd+shift+enter` zoom · `cmd+shift+r` reload config.

## Orquestrar múltiplos harnesses

1. Isolamento: `claude --worktree` (git worktree nativo, sem gerenciar na mão).
2. Subir vários: `agent-new fix-login`, `agent-new refactor`, … (cada um numa window).
   Ou declarativo: edite `terminal/tmuxp/agent-fleet.yaml` e rode `fleet`.
3. Observar: `prefix + D` abre o agent-dashboard (estado por agente: blocked /
   running / review / PR / merged) e despacha input pra quem precisa.

### Plugin do agent-dashboard no Claude Code (rodar dentro do Claude Code)

```
/marketplace add bjornjee/agent-dashboard
/plugin install agent-dashboard@agent-dashboard
/plugin enable agent-dashboard@agent-dashboard
```

Depois reinicie as sessões do Claude Code para os hooks ativarem.

## Notas

- **Starship não é usado**: o shell roda Powerlevel10k. Se um dia quiser trocar,
  é um passo isolado (remover ZSH_THEME do `.zshrc_base` + `eval "$(starship init zsh)"`).
- **Persistência**: `tmux-resurrect` + `tmux-continuum` salvam/restauram sessões
  a cada 15 min — sessões de agente sobrevivem a fechar a janela.
- **Catppuccin tmux**: versão pinada (`v2.1.2`); a v2 quebrou a API da v1.
