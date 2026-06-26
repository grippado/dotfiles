# Personal Workspace — Gabriel Gripp

> Carregado automaticamente quando `cwd` está sob `/Users/grippado/www/personal/*`.
> Source-of-truth: `~/cangaco/.ai/contexts/personal/.claude/CLAUDE.md`.

## Repos neste workspace

| Repo | Stack | CLAUDE.md? | Status |
|------|-------|------------|--------|
| flagbridge | Workspace/Docs (multi-repo da org GitHub) | ✅ | Ativo (foco principal) |
| gripp-link | Vite + vanilla TS | ✅ | Ativo (site pessoal) |
| guia-cumuru | Go + Angular monorepo | ✅ | Ativo |
| labor.city | TS (verificar) | ✅ | Ativo (commands `*:labor-city` dedicados) |
| declare-ui | TS (verificar) | stub | Ativo (`.claude/commands/` próprio) |
| vozes.social | (verificar) | stub | Ativo (`.claude/settings.local.json`) |
| tabua-mares-bot | (verificar) | stub | Ativo |
| claude-atlas | Python (claude-atlas) | stub | Ativo |
| roaster-kit | Node | stub | Ativo |
| acesso-morador-frontend | Node | — | **Stale** (último commit 2025-07-25) — considerar arquivar |
| operation-frontend | Angular 16 | — | **Stale** (último commit 2024-08-30) — considerar arquivar |
| gripp-link-n--OLD | — | — | **Arquivar** (cópia antiga de gripp-link) |
| opengateway.digital | vazio | — | **Ignorar** (pasta vazia) |

## Convenções comuns

- **Commits**: Conventional Commits + emoji prefixes
- **Linguagem**: PT-BR para comunicação, EN para código
- **Acentuação PT-BR**: sempre correta (é, ã, ç, ê, ó)
- **Package managers**: pnpm (preferido), yarn, npm
- **direnv** para gestão de ambiente

## Modos de trabalho (IMPORTANTE)

Claude Code carrega 2 níveis de `.claude/`: o user (`~/.claude/`) e o **mais próximo** subindo. Sem merge de níveis intermediários.

- **Workspace mode** — `cd ~/www/personal && claude`
  Carrega: global + este workspace (plugin Vercel + comandos personal).
  Use para: trabalho cross-repo, navegação geral, comandos `*:flagbridge`/`*:labor-city`/`context:declare-ui` (se gerenciados pelo Atlas REGISTRY, podem estar disponíveis também em repo mode — verificar).

- **Repo mode** — `cd ~/www/personal/<repo> && claude`
  Carrega: global + `.claude/` do próprio repo.
  Use para: trabalho cirúrgico em um único repo.

## Roteamento de trabalho

- **FlagBridge** (workspace ou via Atlas em repo mode): comandos `/backend:flagbridge`, `/frontend:flagbridge`, `/cto:flagbridge`, `/cmo:flagbridge`, `/cpo:flagbridge`, `/design:flagbridge`, `/docs:flagbridge`, `/sdk:flagbridge`, `/security:flagbridge`, `/sre:flagbridge`, `/qa:flagbridge`, `/clickup:flagbridge`, `/bug:flagbridge`, `/sync:flagbridge`, `/brain:flagbridge`, `/brain:github:flagbridge`, `/brain:slack:flagbridge`
- **labor.city**: `/api:labor-city`, `/component:labor-city`, `/page:labor-city`, `/pixel:labor-city`, `/prd:labor-city`, `/task:labor-city`
- **declare-ui**: `/context:declare-ui`
- **Notes/decisões**: persistir em `~/.notes/1-contexts/personal/` (e subpastas por projeto: `flagbridge/`, etc.)

## Plugins ativos neste contexto

- `vercel@claude-plugins-official` — deploys

## MCP servers neste contexto (a definir — Fase 3)

Candidatos:
- `figma-remote-mcp` (HTTP)
- `claude.ai Vercel`
- `claude.ai ClickUp` (FlagBridge usa)

## O que está fora deste contexto

- **Arco/OlaIsaac/ClassApp** → `~/cangaco/.ai/contexts/arco/.claude/` (carrega quando em `~/www/isaac/`)
- **Comandos transversais** (`dep-check`, `explain`, `quick-commit`, `review-changes`, `roast`, `scaffold`, `pr-report`, `organize`, `ship`) → global `~/.claude/`
- **MCPs transversais** (Google Calendar, Google Drive) → global
