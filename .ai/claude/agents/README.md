# Agents globais — catálogo

> Parte do [cérebro Atlas](../../README.md). Agents versionados em `claude/agents/` e symlinkados em `~/.claude/agents/`.

Este diretório contém **21 agents globais** — especialistas invocáveis de qualquer codebase. Agents escopados por repo de produto moram em `<repo>/.claude/agents/` e são indexados pelo `atlas-sync` (não listados aqui).

Para a suíte Isaac (backoffice, bff, e2e, …), ver [`isaac/AGENT_SPEC.md`](isaac/AGENT_SPEC.md).

---

## Catálogo (21 globais)

| Agent | Propósito |
|-------|-----------|
| `brag-writer` | Brag documents no formato STAR-quantified |
| `bug-hunter` | Investiga bugs rastreando código, logs e causa raiz |
| `canonical-taxonomy-scouter` | Saneia taxonomia canônica de notas antes da promoção pelo vault-organizer |
| `code-reviewer` | Review de qualidade, padrões e issues em mudanças de código |
| `context-keeper` | Persiste contexto de projeto, decisões e resumos de sessão |
| `cordel-voice` | Voz PT-BR user-facing no estilo cordel (logs, mensagens, digests) |
| `devto-writer` | Artigos para dev.to em markdown nativo da plataforma |
| `doc-writer` | Documentação, PR descriptions, changelogs, READMEs, ADRs |
| `git-assistant` | Conventional commits, branch names, release notes a partir de diffs |
| `linkedin-articles-writer` | Artigos longos do LinkedIn (Articles/Newsletter) |
| `linkedin-strategist` | Posts de LinkedIn — hooks, estrutura, tom |
| `memory-extractor` | Extrai decisões, padrões e contexto de conversas e código |
| `mutirao-planner` | Pauta de mutirão a partir de issues.md, tasks ou Linear |
| `pr-reviewer` | Review genérico de PRs (qualquer repo) com findings em PT-BR |
| `refactor-scout` | Analisa oportunidades de refatoração, smells e duplicação |
| `refactorer` | Aplica refatorações sem mudar comportamento |
| `shellcheck-guardian` | Roda shellcheck após mudanças em scripts bash do cangaço |
| `slack-context-profiler` | Enriquece contexto de canais Slack para workflows |
| `slides-architect` | Cria, estrutura e revisa apresentações de slides |
| `test-writer` | Escreve testes seguindo padrões existentes no codebase |
| `vault-organizer` | Organização e auditoria do vault Obsidian central-brain |

---

## Suites Isaac (por repo)

Agents aninhados em `isaac/<repo>/` — cada suite tem um `AGENT.md` (repo-owner) e auditors especializados. Não contam nos 21 globais.

| Repo | Suite | Agents |
|------|-------|--------|
| `backoffice` | [`isaac/backoffice/`](isaac/backoffice/) | repo-owner, component-auditor, form-auditor, gravity-ds-auditor, hook-service-reviewer, module-boundary-auditor, a11y-scouter |
| `backoffice-bff` | [`isaac/backoffice-bff/`](isaac/backoffice-bff/) | repo-owner, route-auditor, use-case-auditor, contract-scouter, payload-reviewer, correlation-id-auditor, antipattern-scouter, test-coverage-scouter |
| `communication-api` | [`isaac/communication-api/`](isaac/communication-api/) | repo-owner, route-auditor, contract-scouter, payload-reviewer, repository-layer-auditor, test-coverage-scouter |
| `e2e-tests` | [`isaac/e2e-tests/`](isaac/e2e-tests/) | repo-owner, e2e-pma-planejador, e2e-pma-implementador, e2e-pma-validador, pom-pattern-reviewer, scenario-coverage-auditor |
| `rf-monorepo` | [`isaac/rf-monorepo/`](isaac/rf-monorepo/) | repo-owner, trpc-auditor, env-auditor, module-boundary-auditor |
| `sigaweb` | [`isaac/sigaweb/`](isaac/sigaweb/) | repo-owner, component-auditor, react-query-auditor, styling-auditor |

---

## Como adicionar

### Agent global

1. Criar `claude/agents/<nome>.md` com frontmatter YAML (`name`, `description`, `tools`, …).
2. Commit e push.
3. Na máquina-alvo: `git pull && ~/cangaco/.ai/install.sh --machine <perfil>`.

O `install.sh` symlinka arquivo a arquivo em `~/.claude/agents/`, preservando os scoped symlinks do `atlas-sync` no mesmo diretório.

### Agent escopado (repo de produto)

1. Criar em `<repo>/.claude/agents/<nome>.md`.
2. Garantir que o repo está no `REGISTRY.json` da máquina.
3. Rodar `~/.claude/bin/atlas-sync`.

Para suites Isaac, seguir o checklist em [`isaac/AGENT_SPEC.md`](isaac/AGENT_SPEC.md).

---

## Docs relacionados

- [`.ai/README.md`](../../README.md) — hub Atlas
- [`ARCHITECTURE.md`](../ARCHITECTURE.md) — convenções de naming, frontmatter `extends:`, princípio de override
- [`commands/`](../commands/) — slash commands globais (complementam os agents)
