# contexts/personal

Workspace overlay para `/Users/grippado/www/personal/` (FlagBridge, gripp-link, labor.city, declare-ui, vozes.social, tabua-mares-bot, guia-cumuru, claude-atlas, roaster-kit).

## O que é

Camada intermediária entre o Claude Code global (`~/.claude/`) e os repos individuais. Carregada automaticamente pelo Claude Code quando `cwd` está sob `/Users/grippado/www/personal/*`, via symlink:

```
/Users/grippado/www/personal/.claude  →  ~/cangaco/.ai/contexts/personal/.claude
```

O symlink é criado pelo `install.sh`.

## Estrutura

```
contexts/personal/
├── README.md             # este arquivo
└── .claude/
    ├── CLAUDE.md         # mapa dos repos + convenções
    ├── settings.json     # plugins Personal-only (vercel)
    ├── .mcp.json         # MCP servers Personal (a definir — fase 3)
    ├── agents/
    └── commands/         # *:flagbridge, *:labor-city, context:declare-ui (a migrar)
```

## Como adicionar coisa nova

- **Novo agent Personal**: criar em `.claude/agents/<name>.md`
- **Novo command Personal**: criar em `.claude/commands/<name>.md`
- **Novo plugin**: editar `.claude/settings.json`
- **Novo MCP server**: editar `.claude/.mcp.json` (escopo project)
- **Novo repo**: adicionar linha no mapa do `CLAUDE.md`

## Plugins ativos neste contexto

- `vercel@claude-plugins-official` — deploys de gripp-link, labor.city, etc.
