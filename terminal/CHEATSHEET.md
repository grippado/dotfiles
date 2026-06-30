# 🐗 tmux cheat sheet — cangaço

> Parte do [terminal/](README.md). **Prefix = `Ctrl+a`** (substitui o `Ctrl+b` padrão).
> Notação: `prefix c` = aperta `Ctrl+a`, **solta**, depois `c`.
> `Ctrl+a` segurado junto da tecla só nos resize (`H/J/K/L`) que são repetíveis.

## Memória muscular — o mínimo pra começar

| Quero… | Atalho |
|--------|--------|
| Nova window (aba) | `prefix c` |
| Renomear a window atual | `prefix ,` |
| Fechar a window | `prefix &` (pede confirmação) |
| Split vertical (lado a lado) | `prefix \|` |
| Split horizontal (em cima/baixo) | `prefix -` |
| **Fechar um pane sem digitar `exit`** | `prefix x` (pede confirmação) |
| Pular entre panes | `prefix h/j/k/l` |
| Zoom no pane (tela cheia / volta) | `prefix z` |
| Recarregar config | `prefix r` |
| Abrir o agent-dashboard | `prefix D` |

## Sessões

| Ação | Atalho / comando |
|------|------------------|
| Listar sessões | `tmux ls` ou alias `tls` |
| Criar sessão nomeada | `tmux new -s nome` ou alias `tn nome` |
| Anexar à última | `tmux attach` ou alias `ta` |
| **Detach** (sair sem matar) | `prefix d` |
| Trocar de sessão (fuzzy) | `prefix o` (sessionx) ou alias `ss` |
| Renomear a sessão | `prefix $` |
| Matar sessão | alias `tk nome` |
| Próxima / anterior sessão | `prefix )` / `prefix (` |

## Windows (abas)

| Ação | Atalho |
|------|--------|
| Nova window | `prefix c` |
| Renomear | `prefix ,` |
| Fechar | `prefix &` |
| Próxima / anterior | `prefix n` / `prefix p` |
| Ir pra window N | `prefix 1` … `prefix 9` |
| Última window usada | `prefix l` (L minúsculo) |
| Listar/escolher window | `prefix w` |
| Mover/reordenar window | `prefix .` |
| Buscar texto e pular | `prefix f` |

## Panes (divisões)

| Ação | Atalho |
|------|--------|
| Split vertical | `prefix \|` |
| Split horizontal | `prefix -` |
| Navegar | `prefix h/j/k/l` |
| Navegar (sem prefix, integra Neovim) | `Ctrl+h/j/k/l` |
| Redimensionar | `prefix H/J/K/L` (pode repetir) |
| **Fechar pane** | `prefix x` |
| Zoom (maximiza/restaura) | `prefix z` |
| Transformar pane em window | `prefix !` |
| Rodar panes (trocar layout) | `prefix Espaço` |
| Trocar pane de lugar | `prefix { ` / `prefix }` |
| Mostrar números dos panes | `prefix q` (digite o número pra pular) |

## Copy mode (rolar / copiar)

| Ação | Atalho |
|------|--------|
| Entrar no copy mode | `prefix [` |
| Rolar / mover | setas, `Ctrl+u` / `Ctrl+d`, ou mouse |
| Começar seleção | `v` (estilo vim) |
| Copiar (vai pro clipboard macOS) | `y` |
| Sair do copy mode | `q` |
| Colar o buffer do tmux | `prefix ]` |
| Busca no buffer | `/` (pra frente) `?` (pra trás) |

> Com `mouse on`: dá pra selecionar arrastando (copia direto), clicar pra trocar de pane, e rolar com o scroll.

## Plugins instalados

| Plugin | O que faz | Como usar |
|--------|-----------|-----------|
| tmux-resurrect | Salva/restaura sessões | `prefix Ctrl+s` salva, `prefix Ctrl+r` restaura |
| tmux-continuum | Auto-save a cada 15 min + auto-restore | automático |
| tmux-sessionx | Fuzzy-finder de sessões | `prefix o` |
| tmux-yank | Copiar pro clipboard | `y` no copy mode |
| vim-tmux-navigator | Navegação tmux↔Neovim | `Ctrl+h/j/k/l` |
| catppuccin/tmux | Tema da status bar | visual |

## Atalhos de shell (fora do tmux)

| Comando | Ação |
|---------|------|
| `ss` | escolher sessão via sesh + fzf |
| `sl` | listar sessões do sesh |
| `fleet` | subir a frota de agentes (tmuxp) |
| `agent-new <nome> [cmd]` | harness isolado (worktree) numa window própria |
| `z <pasta>` | pular pra pasta (zoxide) |

## Ghostty (terminal, fora do tmux)

| Ação | Atalho |
|------|--------|
| Quick terminal (dropdown) | `` cmd+` `` |
| Split à direita / abaixo | `cmd+d` / `cmd+shift+d` |
| Navegar splits | `cmd+alt+setas` |
| Zoom no split | `cmd+shift+enter` |
| Nova aba | `cmd+t` |
| Recarregar config | `cmd+shift+r` |
| Tela cheia | `cmd+enter` |

---

**Regra de ouro:** quase tudo é `prefix` (`Ctrl+a`) + uma tecla. Quando esquecer, `prefix ?`
lista TODOS os atalhos ativos. Pra fechar pane/window, pensa `x` (pane) e `&` (window),
nunca precisa digitar `exit`.
