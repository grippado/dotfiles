# contexts/personal — overlay do workspace pessoal

> Parte do [cérebro Atlas](../../README.md). Camada intermediária entre o Claude Code global (`~/.claude/`) e os repos individuais em `~/www/personal/`.

## O que é

Quando o `cwd` está sob `~/www/personal/*`, o Claude Code carrega automaticamente este contexto via symlink:

```
~/www/personal/.claude  →  ~/cangaco/.ai/contexts/personal/.claude
```

O symlink é criado pelo [`install.sh`](../../install.sh) ao rodar com `--machine personal` (`$HOME=/Users/grippado`).

```
  ~/.claude/          contexts/personal/.claude/    repo/.claude/
  (global Atlas)  →   (workspace pessoal)       →   (repo específico)
```

## Estrutura

```
contexts/personal/
├── README.md
└── .claude/
    ├── CLAUDE.md         # mapa dos repos + convenções
    ├── settings.json     # plugins Personal-only (vercel)
    ├── .mcp.json         # MCP servers Personal (escopo project)
    ├── agents/           # (vazio — agents globais cobrem o workspace)
    └── commands/         # comandos escopados migrados para repos via REGISTRY
```

Repos mapeados no `CLAUDE.md`: FlagBridge, gripp-link, labor.city, declare-ui, vozes.social, tabua-mares-bot, guia-cumuru, claude-atlas, roaster-kit, e outros.

Comandos escopados por repo (`organize:notes`, `sync:flagbridge`, …) moram no `.claude/` de cada repo e são indexados pelo `atlas-sync` via `REGISTRY.json` — não neste overlay.

## Como adicionar coisa nova

- **Novo agent Personal** → preferir `claude/agents/` (global) se funcionar em qualquer repo; senão, criar em `.claude/agents/<name>.md`.
- **Novo command Personal** → criar em `<repo>/.claude/commands/` e registrar o scope no `REGISTRY.json`.
- **Novo plugin** → editar `.claude/settings.json`.
- **Novo MCP server** → editar `.claude/.mcp.json` (escopo project).
- **Novo repo** → adicionar linha no mapa do `CLAUDE.md`.

## Plugins ativos neste contexto

- `vercel@claude-plugins-official` — deploys de gripp-link, labor.city, etc.

## Docs relacionados

- [`.ai/README.md`](../../README.md) — hub Atlas
- [`contexts/arco/README.md`](../arco/README.md) — overlay do workspace Isaac
- [`notes-mcp/README.md`](../../notes-mcp/README.md) — MCP local sobre o vault
