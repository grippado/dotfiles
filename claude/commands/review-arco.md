---
name: review-arco
description: Revisa uma PR (ou branch atual vs main) no contexto Arco/OlaIsaac e persiste o review como arquivo .md no Obsidian vault em ~/www/personal/notes/1-contexts/arco/pr-reviews/<repo>/
user_invocable: true
---

# /review-arco

Skill orquestradora de PR review para o time Arco. Coleta contexto, delega análise ao subagent `arco-pr-reviewer`, e persiste o resultado num arquivo markdown padronizado no vault Obsidian do Gabriel.

**Out of scope (NUNCA faça):**

- Não rodar `pnpm test` / `pnpm typecheck` / `pnpm lint` / qualquer suite de testes
- Não comentar na PR (`gh pr comment`, `gh pr review`)
- Não fazer commit, push, nem modificar arquivos do repo sob review
- Não aprovar nem mergear (`gh pr review --approve`, `gh pr merge`)
- Não escrever em lugar nenhum exceto o arquivo final no vault

## Inputs aceitos

| Forma | Significado |
|-------|-------------|
| `/review-arco` (sem arg) | Branch atual do `pwd` vs `main` |
| `/review-arco 790` | PR #790 do repo do `pwd` atual |
| `/review-arco https://github.com/OlaIsaac/backoffice-bff/pull/790` | PR do URL informado (qualquer repo OlaIsaac/classapp) |
| `/review-arco https://github.com/classapp/communication-api/pull/698` | idem, cross-repo |

## Fluxo de execução

### 1. Resolver o target

```bash
# se arg numérico:
PR_NUMBER=$1
REPO_FULL=$(gh repo view --json nameWithOwner -q .nameWithOwner)

# se arg é URL:
# parse {owner}/{repo}/pull/{number}

# se sem arg:
# branch atual vs main, REPO_FULL = $(gh repo view --json nameWithOwner -q .nameWithOwner)
# PR_NUMBER = null
```

### 2. Decidir cross-repo vs local

Se o `pwd` é o checkout do repo alvo (ou não há arg), trabalhe direto. Se for cross-repo:

1. Tente buscar diff via `gh pr diff <n> --repo {owner}/{repo}` — se funcionar, segue só com diff
2. Se falhar (auth, repo privado sem acesso), **aborte** com mensagem:
   > `Não consegui acessar o diff de {owner}/{repo}#{n} a partir daqui. Faça \`cd\` no checkout local de {repo} e rode /review-arco {n} novamente.`
3. Não tente trocar de pwd automaticamente

### 3. Coletar contexto

Para PR existente:

```bash
gh pr view $PR_NUMBER --repo $REPO_FULL --json number,title,body,author,headRefName,baseRefName,url,state,additions,deletions,changedFiles,commits
gh pr diff $PR_NUMBER --repo $REPO_FULL
```

Buscar nome humano do autor:

```bash
gh api users/{login} --jq .name
# se vier null/vazio, usa só o login
```

Para branch local (sem PR):

```bash
git branch --show-current
git log main..HEAD --oneline
git diff main..HEAD
git diff main..HEAD --stat
```

Extrair ticket Linear do título da PR ou nome da branch (regex `[A-Z]{2,5}-\d+`).

Se tiver checkout local do repo alvo, também leia:

- `CLAUDE.md`
- `.github/PULL_REQUEST_TEMPLATE.md`

### 4. Delegar análise ao subagent

Use a Task tool com `subagent_type: arco-pr-reviewer` passando:

- O diff completo
- Lista de commits
- Título + ticket
- Metadados (repo, autor, branches)
- Caminho do checkout local se disponível

O subagent retorna o relatório estruturado nas seções `SUMARIO`, `COMENTARIOS`, `CHECKLIST`, `VEREDITO`, `STATUS`, `PRIORIDADE`. Você não precisa traduzir nada — só fazer parsing e injetar no template.

### 5. Computar nome do arquivo

Convenção:

- **Com PR number:** `YYYY-MM-DD-{repo-slug}-PR{number}.md`
  - Exemplo: `2026-04-30-backoffice-bff-PR790.md`
- **Sem PR (branch local):** `YYYY-MM-DD-{repo-slug}-{branch-slug}.md`
  - Exemplo: `2026-04-30-backoffice-bff-cma-2400-feature-x.md`
  - branch-slug = nome da branch em kebab-case, sem prefixos como `feat/`, `fix/`

Path completo: `$NOTES_VAULT/1-contexts/arco/pr-reviews/{repo-slug}/{filename}`

> **Estrutura por repo:** desde 2026-05-08, PR reviews vivem em subpastas por repositório (`pr-reviews/communication-api/`, `pr-reviews/rf-monorepo/`, etc.). Crie a subpasta se não existir. Reviews que não se encaixam em um repo único (DRTs, análises cross-cutting) ficam no root `pr-reviews/`.

**Re-runs no mesmo dia:**

- Se já existe o arquivo, sufixar com `-v2`, `-v3`, etc.
  - `2026-04-30-backoffice-bff-PR790-v2.md`
- Se for review de réplicas/respostas (modo futuro), o sufixo seria `-v1-answers`, `-v2-answers`. Por ora, `/review-arco` puro só usa `-vN`. **Não** implemente lógica de respostas neste comando — fica para um futuro `/review-arco-answer`

### 6. Renderizar template e gravar

Template canônico (preencher com os dados coletados + output do subagent):

```markdown
---
type: pr-review
date: {YYYY-MM-DD}
pr_url: "{url ou 'N/A — local branch'}"
pr_number: {number ou null}
repo: "{repo-slug}"
author: "{gh-login}"
status: {status do subagent}
tags: [pr-review, {repo-slug}, {area-tag-opcional}, {ticket-slug-lowercase}, {TICKET-XXX}]
---

# PR Review: [{TICKET-XXX}] {Título da PR}

**PR:** [#{number}]({url})
**Repo:** {repo-slug}
**Author:** {gh-login}{ se nome humano disponível: ` ({Nome Humano})`}
**Branch:** `{head}` -> `{base}`
**Revisado em:** {YYYY-MM-DD}
**Tamanho:** {N} arquivos, +{adds}/-{dels} (size_{xs|s|m|l|xl})
**Status atual:** {state da PR — Open, Merged, Closed, etc + observação se relevante}

## Resumo

{seção SUMARIO do subagent}

## Legenda

| Emoji | Tipo | Postar na PR? |
|-------|------|---------------|
| 🔴 | Crítico | Sim, obrigatório |
| 🟡 | Necessário | Sim, recomendado |
| 🔵 | Sugestão | A critério do revisor |
| 🟢 | Elogio | Opcional |
| ⚠️ | Breaking change | Sim, obrigatório |
| 💭 | Nota interna | Não |

## Comentários de Review

{seção COMENTARIOS do subagent — já vem com headers `### {emoji} ...`}

## Checklist antes do merge

{seção CHECKLIST do subagent — omitir a seção inteira se subagent não retornou checklist}

## Decisão

{seção VEREDITO + PRIORIDADE do subagent, formatadas assim:}

**{tradução do STATUS para PT-BR}** — {texto do veredito}

Prioridade dos comentários:

1. {item 1 da PRIORIDADE}
2. {item 2}
3. {...}
```

Tradução do STATUS para o título da decisão:

- `approved` → "Aprovar"
- `approved-with-suggestions` → "Aprovar com sugestões"
- `approved-with-changes` → "Aprovar com mudanças"
- `request-changes` → "Solicitar mudanças"

Cálculo do `size_*` (heurístico, baseado no total de adds+dels):

- `size_xs`: < 50
- `size_s`: 50–199
- `size_m`: 200–499
- `size_l`: 500–1999
- `size_xl`: ≥ 2000 (se grosso for lockfile/migration auto-gerado, anotar entre parênteses)

Use a Write tool para gravar o arquivo no caminho calculado.

### 7. Resposta no chat

Depois de gravar com sucesso, responda **apenas** com:

```
Review salvo em {caminho-completo-do-arquivo}.

Veredito: {STATUS} — {1 frase do veredito}.
```

**Não** repita o conteúdo do review no chat. **Não** faça resumo expandido. O arquivo é a fonte de verdade.

## Notas finais

- Sempre PT-BR com acentuação correta no conteúdo do review (frontmatter pode ficar em inglês onde já era padrão: `type`, `status`)
- Se o subagent retornar erro ou output mal formatado, mostre o erro e **não** grave arquivo parcial
- Se faltar `gh` autenticado, peça ao usuário pra rodar `gh auth login` e aborte
