---
name: review-pr
description: Revisa uma PR (ou branch atual vs main) de qualquer repo, delega análise ao agent `pr-reviewer` (com override local do repo se existir), persiste o resultado como arquivo .md no Obsidian vault em ~/.notes/1-contexts/<contexto>/pr-reviews/, e oferece ação pós-review (aplicar correções em PR própria ou postar comentários inline em PR de terceiros).
user_invocable: true
---

# /review-pr

Skill orquestradora de PR review **genérica** — funciona em qualquer repo (pessoal, Arco, ou outras orgs). Coleta contexto, delega análise ao subagent `pr-reviewer` (ou override local do repo), persiste o resultado num `.md` padronizado no vault Obsidian do Gabriel, e oferece uma ação pós-review opt-in (passo 9): aplicar as correções (PR própria) ou postar comentários inline (PR de terceiros).

Inspirada em `/review-arco`, mas neutra a contexto: o caminho de save é resolvido dinamicamente pelo owner/repo, e a verificação no modo "aplicar correções" detecta o toolchain do projeto em vez de assumir um stack específico.

**Out of scope (NUNCA faça sem confirmação explícita):**

- Não rodar suite de testes / typecheck / lint (`pnpm test`, `uv run pytest`, `go test`, etc.) — EXCETO no modo "aplicar correções" do passo 9 (PR própria), onde rodar a verificação dos arquivos tocados é obrigatório
- Não comentar na PR (`gh pr comment`, `gh pr review`) — EXCETO no modo "postar inline" do passo 9, e só após o usuário escolher essa opção
- Não fazer commit, push, nem modificar arquivos do repo sob review — EXCETO no modo "aplicar correções" do passo 9 (PR própria), e mesmo aí só após o usuário escolher essa opção
- Não aprovar nem mergear (`gh pr review --approve`, `gh pr merge`)
- Não escrever em lugar nenhum exceto: o arquivo final no vault; (opcionalmente) a review da PR via `gh api` no passo 9; e, no modo "aplicar correções", os arquivos de código + commit na branch da PR própria

**Sobre o passo 9:** após gravar o arquivo no Obsidian (passo 7) e responder no chat (passo 8), o passo 9 oferece, via `AskUserQuestion`, a ação pós-review. O menu MUDA conforme a PR seja **de terceiros** (postar comentários inline) ou **do próprio Gabriel** (aplicar as correções recomendadas em commits semânticos). Nunca agir sem o usuário escolher uma opção positiva. Esta camada é **agnóstica a repo**: detecta o toolchain do projeto em vez de assumir um gerenciador de pacotes específico.

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

Detectar se a PR é **do próprio Gabriel** (decide o menu do passo 9). Buscar também o assignee:

```bash
ME=$(gh api user -q .login)                                              # login do usuário logado
gh pr view $PR_NUMBER --repo $REPO_FULL --json author,assignees \
  -q '{author: .author.login, assignees: [.assignees[].login]}'
# IS_OWN_PR = true se ME == author.login OU ME estiver em assignees
```

Guardar `IS_OWN_PR` (bool) e `ME`. Para branch local sem PR aberta, tratar como própria (`IS_OWN_PR = true`).

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

Em seguida, vá direto para o passo 9 (sem esperar input adicional do usuário). Se o review **não tem PR number** (branch local sem PR aberta) ou se nenhum agent retornou comentário acionável (🔴/🟡/🔵/🟢/⚠️), **pule o passo 9** — apenas terminar.

### 9. Oferecer ação pós-review (aplicar ou publicar)

Se há PR aberta e comentários acionáveis no review, perguntar via `AskUserQuestion` (uma única question, single-select). **O conjunto de opções depende de `IS_OWN_PR`** (passo 3): em PR própria, o padrão é aplicar as correções; em PR de terceiros, o padrão é postar inline.

> **Multi-agent (frontend + backend):** o passo 9 opera sobre a **união** dos comentários de todas as seções de agent do arquivo. Não renumere prioridades cruzadas — colete os findings de cada seção mantendo o emoji prefix, e use a lista "Top-3 prioridades cross-scope" da `## Decisão agregada` como ordem de prioridade ao publicar.

#### 9a. PR do próprio Gabriel (`IS_OWN_PR == true`)

Postar comentário pra si mesmo não agrega; o valor é aplicar a correção. Antes de perguntar, se a PR ainda não tiver o Gabriel como assignee, atribuir:

```bash
gh pr edit $PR_NUMBER --repo $REPO_FULL --add-assignee "$ME"
```

Perguntar:

- **Header:** `Ação na PR?`
- **Question:** `A PR #{number} é sua. O que fazer com as recomendações do review?`
- **Options (nessa ordem):**
  1. `🛠️ Aplicar correções em commits semânticos (Recomendado)` — descrição: `Aplica os 🔴 + 🟡 + 🔵 acionáveis no working tree, roda a verificação dos arquivos tocados, e commita semanticamente. Não posta nada. Sem push automático.`
  2. `Aplicar e dar push` — descrição: `Igual acima, e ao final dá push na branch da PR.`
  3. `Postar comentários inline` — descrição: `Em vez de aplicar, posta o review na PR (mesmo fluxo de PR de terceiros). Útil pra registrar sem mexer no código agora.`
  4. `Não fazer nada` — descrição: `Review fica só no Obsidian. Você decide depois.`

Se escolher 1 ou 2 → ir para **9c**. Se escolher 3 → usar a postagem de **9b**. Se 4 → terminar.

#### 9b. PR de terceiros (`IS_OWN_PR == false`) — publicar inline

Perguntar via `AskUserQuestion` (single-select):

- **Header:** `Postar na PR?`
- **Question:** `Quer postar algum subset dos comentários direto na PR #{number}?`
- **Options (nessa ordem):**
  1. `Prioridades + kudos (Recomendado)` — descrição: `Posta 🔴 + ⚠️ + itens da lista PRIORIDADE + todos os 🟢 inline. Padrão histórico do Gabriel.`
  2. `Só prioridades` — descrição: `Posta 🔴 + ⚠️ + itens da lista PRIORIDADE inline. Sem kudos.`
  3. `Tudo` — descrição: `Posta todos os comentários do review (🔴 🟡 🔵 🟢 ⚠️) inline. 💭 nunca vai.`
  4. `Não postar` — descrição: `Review fica só no Obsidian. Eu reviso antes de decidir.`

> A opção "Recomendado" é a primeira e tem `(Recomendado)` no label, conforme padrão do tool.

Se o usuário escolher uma opção positiva (1, 2 ou 3), montar a review e postar via `gh api`:

```bash
gh api -X POST repos/{owner}/{repo}/pulls/{number}/reviews --input <json-file>
```

JSON shape esperado:

```json
{
  "event": "COMMENT",
  "body": "<corpo com kudos de arquivo-inteiro novo, ex: changeset>",
  "comments": [
    { "path": "...", "line": N, "side": "RIGHT", "body": "🟡 ..." },
    { "path": "...", "start_line": N, "line": M, "side": "RIGHT", "body": "🟢 ..." }
  ]
}
```

Regras para montar o payload:

- `event` **sempre** `COMMENT`. Nunca `APPROVE` nem `REQUEST_CHANGES` sem pedido explícito separado.
- Cada comentário usa `side: "RIGHT"`. Range multi-linha → `start_line` + `line`. Linha única → só `line`.
- **Validar os números de linha contra o diff real** antes de postar — os números no markdown do vault podem estar relativos a hunks ou desatualizados. Buscar a linha no novo arquivo (RIGHT side) procurando pelo trecho citado.
- Kudos sobre arquivo inteiro novo (ex: `.changeset/*`, arquivo novo inteiro) vão no `body` da review (não dão pra inline em "arquivo todo").
- Manter PT-BR com acentuação correta e o emoji prefix (🔴 🟡 🔵 🟢 ⚠️) em cada `body` de comentário, para casar com a legenda do review.
- **Sem em-dashes** nos textos publicados (regra global do usuário — usar vírgula, dois-pontos, parênteses).
- Se a PR está em repo cross-org sem acesso de escrita, capturar o erro do `gh api` e reportar ao usuário sem retentar.

Após `gh api` retornar sucesso (com `html_url` da review), responder no chat **só** com:

```
Review postada: {html_url}

{n} inline + {m} kudos no corpo. Submetida como COMMENTED (não-bloqueante).
```

Se o usuário escolher "Não postar" ou cancelar a question, apenas terminar (sem mensagem extra).

#### 9c. Aplicar correções (modo PR própria)

Aplicar no working tree as correções **acionáveis** do review: 🔴 (obrigatórias), 🟡 (necessárias) e 🔵 (sugestões) que sejam mudança concreta de código. **Pular** 🟢 (elogios), 💭 (notas internas) e itens que sejam só "considerar/avaliar" sem ação definida.

Regras:

- **Verificar antes de aplicar:** cada finding deve ser confirmado contra o código real (o `pr-reviewer` pode gerar falsos positivos). Se um item for improcedente na verificação, NÃO aplicar, e registrar no resumo final por que foi pulado. Se for uma decisão de design genuinamente ambígua (trade-off real), perguntar ao usuário em vez de chutar.
- **3-file gate:** se as correções tocarem **mais de 3 arquivos**, NÃO edite direto — delegue a um agente de implementação (`general-purpose` ou específico) com instruções precisas: arquivos, edições exatas, comandos de verificação e mensagem(ns) de commit. Para ≤3 arquivos, pode aplicar direto.
- **Verificação obrigatória (toolchain-agnóstica)** nos arquivos tocados, antes de commitar: typecheck + lint + os testes unitários afetados. Detectar o ecossistema do repo e usar o comando certo, em vez de assumir um único:
  - Node: detectar o gerenciador por lockfile (`pnpm-lock.yaml` → `pnpm`, `yarn.lock` → `yarn`, `package-lock.json` → `npm`) e rodar os scripts existentes no `package.json` (`typecheck`/`lint`/`test`). Respeitar a versão de Node pinada (`.nvmrc`/`.node-version` via fnm/nvm/asdf) quando houver.
  - Python: `uv run`/`poetry run`/venv conforme o projeto (`uv.lock`, `poetry.lock`); rodar `pytest` + `ruff`/`mypy` se configurados.
  - Go: `go build ./...` + `go vet ./...` + `go test` nos pacotes tocados.
  - Rust: `cargo check` + `cargo clippy` + `cargo test`.
  - Se não der pra inferir o toolchain, perguntar ao usuário qual comando de verificação rodar em vez de chutar.
  - Se algum gate falhar por motivo ambiental (registry/auth/deps faltando), confirmar que é idêntico ao baseline `main` e registrar; se falhar por causa da mudança, corrigir antes de commitar.
- **Commits semânticos:** Conventional Commits + emoji, PT-BR com acentuação correta. Agrupar por tema (um commit por finding ou por grupo coerente, a critério). Trailer **obrigatório** `Co-Authored-By: Claude <noreply@anthropic.com>` via HEREDOC. Se o repo tiver hook (husky/lint-staged/pre-commit) quebrado por ambiente, usar `--no-verify` e registrar o motivo.
- **Push:** só na opção 2 (Aplicar e dar push), e só na branch `headRefName` da PR (nunca `main` nem a branch default do repo). Opção 1 deixa os commits locais.
- **Nunca** postar comentário, aprovar nem mergear neste modo.
- **Atualizar a descrição da PR** quando a correção mudar materialmente o que a PR faz (ex.: removeu/alterou algo descrito no corpo): editar via `gh pr edit $PR_NUMBER --repo $REPO_FULL --body-file <arquivo>`. Manter sem em-dashes (texto externo).

Resposta no chat ao final: tabela curta `{finding | aplicado/pulado | arquivos}`, depois `{commit(s) SHA, resultado da verificação, e range de push se houve}`. Sinalizar findings pulados (improcedentes/ambíguos) e o que precisa de decisão do usuário.

## Notas finais

- Sempre PT-BR com acentuação correta no conteúdo do review (frontmatter pode ficar em inglês onde já era padrão: `type`, `status`)
- Se o subagent retornar erro ou output mal formatado, mostre o erro e **não** grave arquivo parcial
- Se faltar `gh` autenticado, peça ao usuário pra rodar `gh auth login` e aborte
- Para repos do time Arco (`OlaIsaac/*`, `classapp/*`), considere usar `/review-arco` em vez deste — ele tem regras específicas pro contexto. Este comando funciona, mas o especializado é mais preciso
