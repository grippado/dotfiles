# contexts/arco

Workspace overlay para `/Users/grippado/www/isaac/` (Arco / OlaIsaac / ClassApp / Isaac).

## O que é

Camada intermediária entre o Claude Code global (`~/.claude/`) e os repos individuais. Carregada automaticamente pelo Claude Code quando `cwd` está sob `/Users/grippado/www/isaac/*`, via symlink:

```
/Users/grippado/www/isaac/.claude  →  ~/cangaco/.ai/contexts/arco/.claude
```

O symlink é criado pelo `install.sh`.

## Estrutura

```
contexts/arco/
├── README.md             # este arquivo
├── .claude/
│   ├── CLAUDE.md         # mapa dos repos + convenções comuns
│   ├── settings.json     # plugins/permissions Arco-only
│   ├── agents/           # arco-pr-reviewer, arco-pr-answerer
│   └── commands/         # review-arco, review-arco-answer
└── templates/
    └── CLAUDE.stub.md    # template para repos sem CLAUDE.md
```

## Como adicionar coisa nova

- **Novo agent Arco**: criar em `.claude/agents/<name>.md`. Disponível só dentro do workspace.
- **Novo command Arco**: criar em `.claude/commands/<name>.md`.
- **Novo plugin/MCP**: editar `.claude/settings.json` (plugins) ou criar `.claude/.mcp.json` (MCP servers).
- **Novo repo**: adicionar linha no mapa do `CLAUDE.md`. Se não tiver `CLAUDE.md` próprio, copiar `templates/CLAUDE.stub.md` pra raiz do repo.

## Bootstrap em máquina nova

Ver runbook: `~/.notes/1-contexts/dotfiles-ai/runbooks/add-context.md`.
