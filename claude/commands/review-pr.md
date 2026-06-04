---
name: review-pr
description: Revisa uma PR (ou branch atual vs main) de qualquer repo, delega análise ao agent `pr-reviewer` (com override local do repo se existir), e persiste o resultado como arquivo .md no Obsidian vault em ~/.notes/1-contexts/<contexto>/pr-reviews/.
user_invocable: true
---

# /review-pr

Skill orquestradora de PR review **genérica** — funciona em qualquer repo (pessoal, Arco, ou outras orgs). Coleta contexto, delega análise ao subagent `pr-reviewer` (ou override local do repo), e persiste o resultado num `.md` padronizado no vault Obsidian do Gabriel.

Inspirada em `/review-arco`, mas neutra a contexto: o caminho de save é resolvido dinamicamente pelo owner/repo.

**Out of scope (NUNCA faça):**

- Não rodar `pnpm test` / `pnpm typecheck` / `pnpm lint` / qualquer suite de testes
- Não comentar na PR (`gh pr comment`, `gh pr review`)
- Não fazer commit, push, nem modificar arquivos do repo sob review
- Não aprovar nem mergear (`gh pr review --approve`, `gh pr merge`)
- Não escrever em lugar nenhum exceto o arquivo final no vault

## Inputs aceitos

| Forma | Significado |
|-------|-------------|
| `/review-pr` (sem arg) | Branch atual do `pwd` vs `main` |
| `/review-pr 25` | PR #25 do repo do `pwd` atual |
| `/review-pr https://github.com/grippado/guia-cumuru/pull/25` | PR do URL informado (qualquer repo) |

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

Extraia `OWNER` e `REPO` separadamente — são usados no passo 5 para resolver o caminho de save.

### 2. Decidir cross-repo vs local

Se o `pwd` é o checkout do repo alvo (ou não há arg), trabalhe direto. Se for cross-repo:

1. Tente buscar diff via `gh pr diff <n> --repo {owner}/{repo}` — se funcionar, segue só com diff
2. Se falhar (auth, repo privado sem acesso), **aborte** com mensagem:
   > `Não consegui acessar o diff de {owner}/{repo}#{n} a partir daqui. Faça \`cd\` no checkout local de {repo} e rode /review-pr {n} novamente.`
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

Extrair ticket do título da PR ou nome da branch (regex `[A-Z]{2,5}-\d+` para Linear/Jira; ou `#\d+` para GitHub issues).

Se tiver checkout local do repo alvo, também leia:

- `CLAUDE.md` (e `.claude/CLAUDE.md` se existir)
- `.github/PULL_REQUEST_TEMPLATE.md`

### 4. Detectar agents disponíveis e mapear por path

Listar arquivos alterados na PR para roteamento:

```bash
# Para PR existente:
gh pr view $PR_NUMBER --repo $REPO_FULL --json files -q '.files[].path'

# Para branch local:
git diff main..HEAD --name-only
```

Inspecione `<repo-checkout>/.claude/agents/` (quando há checkout local) procurando reviewers especializados:

- `pr-reviewer-frontend.md` — escopo declarado no frontmatter (qual subdir)
- `pr-reviewer-backend.md` — idem
- `pr-reviewer.md` — override genérico do repo (cobre tudo)
- (qualquer outro `pr-reviewer-*.md`)

**Regra de roteamento (em ordem de prioridade):**

1. **Multi-agent especializado**: se existem agents `pr-reviewer-frontend` e/ou `pr-reviewer-backend` no repo, use o(s) que casa(m) com os paths alterados:
   - Mudou só `client/**` → só `pr-reviewer-frontend`
   - Mudou só `api/**` → só `pr-reviewer-backend`
   - Mudou ambos → **dispatcha os dois EM PARALELO** (uma única mensagem com 2 chamadas Task)
   - Mudou nenhum dos escopos (ex: só `README.md`, `docker-compose.yml`) → use `pr-reviewer.md` local se existir, senão global
2. **Override genérico do repo**: existe `<repo>/.claude/agents/pr-reviewer.md` mas nenhum especializado → usa esse
3. **Fallback global**: nenhum dos acima → `subagent_type: pr-reviewer` (global em `~/.claude/agents/`)

Os mapeamentos `client/` → frontend e `api/` → backend são **convenção do guia-cumuru**. Para outros repos com agents `pr-reviewer-*` similares, leia o frontmatter do agent — campo `description` indica o escopo (ex: "escopo `client/`").

**Como detectar e despachar paralelamente** (caso multi-agent):

Quando precisar rodar 2+ agents, **emita uma única mensagem com múltiplas chamadas Task** (paralelismo nativo do Claude Code):

- Task #1: `subagent_type: pr-reviewer-frontend` com diff filtrado em `client/**`
- Task #2: `subagent_type: pr-reviewer-backend` com diff filtrado em `api/**`

Filtre o diff antes de passar:

```bash
gh pr diff $PR_NUMBER --repo $REPO_FULL > /tmp/full.diff
# Ou para branch local: git diff main..HEAD > /tmp/full.diff

# Filtrar por path no diff (separar por arquivo `diff --git`):
# Frontend: blocos cujo path começa com client/
# Backend: blocos cujo path começa com api/
```

Se filtragem por sed/awk for frágil, alternativa pragmática: passe o **diff completo** para cada agent e instrua no prompt: "Revise APENAS arquivos sob `client/`" (resp. `api/`). Os agents já têm essa instrução no system prompt deles, mas reforce.

### 5. Delegar análise ao(s) subagent(s)

Para cada agent selecionado, passe no prompt da Task:

- O diff (filtrado por escopo, ou completo com instrução de filtro)
- Lista de commits relacionados
- Título + ticket (se houver)
- Metadados (repo, autor, branches)
- Caminho do checkout local se disponível

Cada subagent retorna o relatório estruturado nas seções `SUMARIO`, `COMENTARIOS`, `CHECKLIST`, `VEREDITO`, `STATUS`, `PRIORIDADE`. Você faz parsing e injeta no template.

**Quando rodam 2+ agents:** mantenha os outputs separados — eles viram seções `## Frontend` e `## Backend` no arquivo final. **Não** tente mergear comentários nem renumerar prioridades; cada agent tem seu próprio status e veredito.

### 6. Resolver caminho de save no vault

Convenção de **contexto** (subdir em `1-contexts/`):

| Owner | Contexto | Path final |
|-------|----------|------------|
| `OlaIsaac`, `classapp` | `arco` | `1-contexts/arco/pr-reviews/{repo}/` |
| `grippado` (user pessoal do Gabriel) | `{repo}` | `1-contexts/{repo}/pr-reviews/` |
| outros | `{owner}` | `1-contexts/{owner}/pr-reviews/{repo}/` |

> **Razão**: repos pessoais do Gabriel (grippado/*) já são contextos próprios no vault — `guia-cumuru`, `flagbridge`, `dotfiles-ai`, etc. já existem em `1-contexts/`. Repos de orgs ficam agrupados pelo owner.

Antes de gravar, **verifique se o diretório de contexto existe**:

```bash
VAULT="$HOME/.notes"
ls "$VAULT/1-contexts/$CONTEXTO" 2>/dev/null || \
  echo "Contexto '$CONTEXTO' não existe. Criar? (sim/não)"
```

Se não existir, **pergunte ao usuário** antes de criar — pode ser typo no owner/repo. Crie a subpasta `pr-reviews/` (e `pr-reviews/<repo>/` quando aplicável) sob demanda.

Convenção de **filename**:

- **Com PR number:** `YYYY-MM-DD-{repo-slug}-PR{number}.md`
  - Exemplo: `2026-05-08-guia-cumuru-PR25.md`
- **Sem PR (branch local):** `YYYY-MM-DD-{repo-slug}-{branch-slug}.md`
  - Exemplo: `2026-05-08-guia-cumuru-feat-establishment-soft-delete.md`
  - branch-slug = nome da branch em kebab-case, sem prefixos como `feat/`, `fix/`

**Re-runs no mesmo dia:**

- Se já existe o arquivo, sufixar com `-v2`, `-v3`, etc.
  - `2026-05-08-guia-cumuru-PR25-v2.md`

### 7. Renderizar template e gravar

**Template — single-agent (1 reviewer rodou):**

```markdown
---
type: pr-review
date: {YYYY-MM-DD}
pr_url: "{url ou 'N/A — local branch'}"
pr_number: {number ou null}
repo: "{repo-slug}"
owner: "{owner}"
author: "{gh-login}"
status: {status do subagent}
tags: [pr-review, {repo-slug}, {area-tag-opcional}, {ticket-slug-lowercase-se-houver}]
---

# PR Review: [{TICKET-XXX se houver}] {Título da PR}

**PR:** [#{number}]({url})
**Repo:** {owner}/{repo-slug}
**Author:** {gh-login}{ se nome humano disponível: ` ({Nome Humano})`}
**Branch:** `{head}` -> `{base}`
**Revisado em:** {YYYY-MM-DD}
**Tamanho:** {N} arquivos, +{adds}/-{dels} (size_{xs|s|m|l|xl})
**Status atual:** {state da PR}
**Reviewer agent:** {nome-do-agent-usado}

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

{seção COMENTARIOS do subagent}

## Checklist antes do merge

{seção CHECKLIST do subagent — omitir se vazio}

## Decisão

**{tradução do STATUS para PT-BR}** — {texto do VEREDITO}

Prioridade dos comentários:

1. {item 1 da PRIORIDADE}
2. {item 2}
3. {...}
```

**Template — multi-agent (2+ reviewers em paralelo):**

Use este formato quando frontend + backend (ou outros) rodaram em paralelo. Cada agent tem sua própria seção; status agregado é calculado abaixo.

```markdown
---
type: pr-review
date: {YYYY-MM-DD}
pr_url: "..."
pr_number: {n}
repo: "{repo}"
owner: "{owner}"
author: "{login}"
status: {status agregado — ver regra abaixo}
reviewers: [pr-reviewer-frontend, pr-reviewer-backend]
scopes: [frontend, backend]
tags: [pr-review, {repo}, multi-scope, ...]
---

# PR Review: [{TICKET}] {Título}

**PR:** [#{n}]({url})
**Repo:** {owner}/{repo}
**Author:** {login}{ (Nome) se disponível}
**Branch:** `{head}` -> `{base}`
**Revisado em:** {YYYY-MM-DD}
**Tamanho:** {N} arquivos, +{adds}/-{dels} (size_*)
**Status atual:** {state}
**Escopos revisados:** Frontend (`client/`) + Backend (`api/`)

## Resumo geral

{Concatene os SUMARIOs de cada agent em 2 bullets curtos cada, ou escreva 1 parágrafo unificando — como preferir for mais legível. Pode citar "Frontend: ..." / "Backend: ..." pra clareza.}

## Legenda

| Emoji | Tipo | Postar na PR? |
|-------|------|---------------|
| 🔴 | Crítico | Sim, obrigatório |
| 🟡 | Necessário | Sim, recomendado |
| 🔵 | Sugestão | A critério do revisor |
| 🟢 | Elogio | Opcional |
| ⚠️ | Breaking change | Sim, obrigatório |
| 💭 | Nota interna | Não |

---

## Frontend

**Reviewer:** `pr-reviewer-frontend`
**Status:** {status frontend}

### Resumo

{SUMARIO do agent frontend}

### Comentários

{COMENTARIOS do agent frontend}

### Checklist

{CHECKLIST do agent frontend — omitir se vazio}

### Decisão (frontend)

**{tradução do STATUS}** — {VEREDITO frontend}

Prioridade:
1. {...}
2. {...}

---

## Backend

**Reviewer:** `pr-reviewer-backend`
**Status:** {status backend}

### Resumo

{SUMARIO do agent backend}

### Comentários

{COMENTARIOS do agent backend}

### Checklist

{CHECKLIST do agent backend — omitir se vazio}

### Decisão (backend)

**{tradução do STATUS}** — {VEREDITO backend}

Prioridade:
1. {...}
2. {...}

---

## Decisão agregada

**{tradução do status agregado}** — {1-2 frases combinando os vereditos. Se um lado pede mudança, a PR como um todo precisa de mudança.}

Top-3 prioridades cross-scope:

1. **[Frontend|Backend]** {emoji} {item}
2. **[Frontend|Backend]** {emoji} {item}
3. **[Frontend|Backend]** {emoji} {item}
```

**Regra de status agregado** (multi-agent):

Pegue o "pior" dos status individuais nesta ordem (mais grave → mais leve):

1. `request-changes` (qualquer agent pediu) → agregado é `request-changes`
2. `approved-with-changes` (qualquer agent) → agregado é `approved-with-changes`
3. `approved-with-suggestions` (qualquer agent) → agregado é `approved-with-suggestions`
4. Todos `approved` → agregado é `approved`

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

### 8. Resposta no chat

Depois de gravar com sucesso, responda **apenas** com:

```
Review salvo em {caminho-completo-do-arquivo}.

Reviewer(s): {lista de agents usados, ex: "pr-reviewer-frontend + pr-reviewer-backend (paralelo)"}
Veredito: {STATUS agregado} — {1 frase combinando os vereditos}.
```

**Não** repita o conteúdo do review no chat. **Não** faça resumo expandido. O arquivo é a fonte de verdade.

## Notas finais

- Sempre PT-BR com acentuação correta no conteúdo do review (frontmatter pode ficar em inglês onde já era padrão: `type`, `status`)
- Se o subagent retornar erro ou output mal formatado, mostre o erro e **não** grave arquivo parcial
- Se faltar `gh` autenticado, peça ao usuário pra rodar `gh auth login` e aborte
- Para repos do time Arco (`OlaIsaac/*`, `classapp/*`), considere usar `/review-arco` em vez deste — ele tem regras específicas pro contexto. Este comando funciona, mas o especializado é mais preciso
