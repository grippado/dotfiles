# contexts/arco — overlay do workspace Isaac

> Parte do [cérebro Atlas](../../README.md). Camada intermediária entre o Claude Code global (`~/.claude/`) e os repos individuais em `~/www/isaac/`.

## O que é

Quando o `cwd` está sob `~/www/isaac/*`, o Claude Code carrega automaticamente este contexto via symlink:

```
~/www/isaac/.claude  →  ~/cangaco/.ai/contexts/arco/.claude
```

O symlink é criado pelo [`install.sh`](../../install.sh) ao rodar com `--machine arco` (na máquina física, `$HOME=/Users/gabriel.gripp`).

```
  ~/.claude/          contexts/arco/.claude/       repo/.claude/
  (global Atlas)  →   (workspace Isaac)        →   (repo específico)
```

## Estrutura

```
contexts/arco/
├── README.md
├── .claude/
│   ├── CLAUDE.md         # mapa dos repos + convenções comuns
│   ├── settings.json     # plugins/permissions Arco-only
│   ├── agents/           # 6 agents de workspace
│   └── commands/         # 5 commands de workspace
└── templates/
    └── CLAUDE.stub.md    # template para repos sem CLAUDE.md
```

### Agents (workspace)

| Agent | Propósito |
|-------|-----------|
| `arco-pr-reviewer` | Review de PRs no contexto Arco |
| `arco-pr-answerer` | Respostas a comentários de PR |
| `arco-doc-reviewer` | Review de documentação |
| `arco-agentic-scouter` | Scouting de oportunidades agentic |
| `capina-executor` | Execução de capina técnica |
| `node-deps-doctor` | Diagnóstico de dependências Node |

### Commands (workspace)

| Command | Propósito |
|---------|-----------|
| `review-arco` | Review estruturado de PR Arco |
| `review-arco-iterate` | Iteração sobre review existente |
| `capina-arco` | Fluxo de capina |
| `agentic-scout` | Scout agentic |
| `workflow` | Workflow Arco |

## Como adicionar coisa nova

- **Novo agent Arco** → criar em `.claude/agents/<name>.md`. Disponível só dentro do workspace.
- **Novo command Arco** → criar em `.claude/commands/<name>.md`.
- **Novo plugin/MCP** → editar `.claude/settings.json` (plugins) ou `.claude/.mcp.json` (MCP servers).
- **Novo repo** → adicionar linha no mapa do `CLAUDE.md`. Se não tiver `CLAUDE.md` próprio, copiar `templates/CLAUDE.stub.md` pra raiz do repo.

## Bootstrap em máquina nova

Runbook no vault: `~/.notes/1-contexts/dotfiles-ai/runbooks/add-context.md`.

## Docs relacionados

- [`.ai/README.md`](../../README.md) — hub Atlas
- [`contexts/personal/README.md`](../personal/README.md) — overlay do workspace pessoal
- [`claude/agents/isaac/`](../../claude/agents/isaac/) — suites por repo Isaac
