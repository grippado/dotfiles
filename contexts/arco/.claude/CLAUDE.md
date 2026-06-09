# Arco / OlaIsaac / ClassApp Workspace

> Carregado automaticamente quando `cwd` está sob `/Users/grippado/www/isaac/*`.
> Source-of-truth: `~/.dotfiles-ai/contexts/arco/.claude/CLAUDE.md`.

## Repos neste workspace

| Repo | Stack | CLAUDE.md? | Notas |
|------|-------|------------|-------|
| arco-agents | Docs/Agents | ✅ | Plugin marketplace local (`arco-default@olaisaac-arco-agents`) |
| backoffice | React SPA + Vite + Turborepo | ✅ | Portal admin Isaac (matrículas, contratos) |
| backoffice-bff | Node + Fastify 5 | ✅ | BFF entre SPA e microserviços |
| backoffice-local-proxy | Node + Express 4 | stub | Proxy local de desenvolvimento |
| claude-setup | meta-repo experimental | — | Repo experimental da org — sem stub |
| communication-api | Node + Fastify 5 | ✅ | Mensageria educacional + AWS |
| e2e-tests | Node | stub | Testes E2E |
| gravity-design-system | Node + Turborepo | ✅ | Design System Gravity |
| joy | Node + Express + GraphQL | ✅ | API ClassApp + Pearl Lambda |
| payment-api | Go 1.25 | stub | API de pagamentos |
| rf-monorepo | Node 22 + Next 16 | ✅ | 12 apps Next.js (alunos/responsáveis) |
| sorting-hat | Go 1.25 + Node | ✅ | IAM centralizado (Keycloak abstraction) |
| sre-scripts-collection | Scripts | stub | Scripts SRE |
| technical-refining | Docs | ✅ | Hub docs cross-repo (PRDs, plans) |
| terraform-github-organization | Terraform | stub | IaC da org GitHub |

## Convenções comuns

- **Commits**: Conventional Commits + emoji
- **Linguagem**: PT-BR para comunicação/comentários, EN para código
- **Acentuação PT-BR**: sempre correta (é, ã, ç, ê, ó) — vale para código (i18n strings), comentários e PR descriptions
- **Stack majoritária**: TypeScript / Go / Terraform
- **CI**: GitHub Actions
- **Notes/decisões**: persistir em `~/.notes/1-contexts/arco/`

## Modos de trabalho (IMPORTANTE)

Claude Code carrega 2 níveis de `.claude/`: o user (`~/.claude/`) e o **mais próximo** subindo a árvore. Não há merge de níveis intermediários.

Por isso, escolha o modo conforme a tarefa:

- **Workspace mode** — `cd ~/www/isaac && claude`
  Carrega: global + este workspace.
  Use para: review de PRs (`/review-arco`), navegação cross-repo, planejamento, trabalho em `technical-refining/`, leitura coordenada de múltiplos repos.

- **Repo mode** — `cd ~/www/isaac/<repo> && claude`
  Carrega: global + `.claude/` do próprio repo (sem este workspace layer).
  Use para: trabalho cirúrgico em um único repo (`/gravity-make`, `/forja:*`, comandos do REGISTRY/Atlas, etc.).

Plugin `arco-default@olaisaac-arco-agents` (que provê `arco-default:*` — worktree, codereview, write-plan, brainstorm, etc.) está habilitado **só no workspace mode** deste contexto. Se precisar dele dentro de repo mode, abra a sessão no workspace.

## Roteamento de trabalho

- **PR review**: `/review-arco` (delega ao agent `arco-pr-reviewer`) — workspace mode
- **Resposta a comentários PR (rascunho read-only)**: `/review-arco-answer` (delega ao `arco-pr-answerer`) — workspace mode
- **Iterar threads de PR (aplica + responde + reage + resolve + commita + pusha)**: `/review-arco-iterate` — workspace mode, repo checkout local
- **Cross-repo coordination**: consultar este arquivo + `technical-refining/` — workspace mode
- **Trabalho profundo em repo**: abrir sessão no repo direto (repo mode)

## Plugins ativos neste contexto

- `arco-default@olaisaac-arco-agents` — comandos arco-default:*
- `core@arco-ai-plugins` — core plugins do time
- `linear@claude-plugins-official` — Linear (tickets/projetos)
- `slack@claude-plugins-official` — Slack (comunicação time)
- `code-review@claude-plugins-official`
- `code-simplifier@claude-plugins-official`
- `atomic-agents@claude-plugins-official`
- `plugin-dev@claude-plugins-official`

`permissions.defaultMode: auto` ativo neste workspace (vs. global `default`).

## O que está fora deste contexto

- **FlagBridge, labor.city, declare-ui, gripp-link, etc.** → `~/.dotfiles-ai/contexts/personal/.claude/`
- **Comandos transversais** (`dep-check`, `explain`, `quick-commit`, `review-changes`, `roast`, `scaffold`, `pr-report`, `organize`, `ship`) → global `~/.claude/`
- **Agents genéricos** (`code-reviewer`, `doc-writer`, `git-assistant`, `memory-extractor`, `context-keeper`, `bug-hunter`, etc.) → global `~/.claude/`
