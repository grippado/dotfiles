---
name: review-arco
description: Revisa uma PR (ou branch atual vs main) no contexto Arco/OlaIsaac e persiste o review como arquivo .md no Obsidian vault em ~/.notes/pr-reviews/ (contexto arco no frontmatter)
user_invocable: true
---

# /review-arco

Skill orquestradora de PR review para o time Arco. Coleta contexto, delega análise ao subagent `arco-pr-reviewer`, e persiste o resultado num arquivo markdown padronizado no vault Obsidian do Gabriel.

**Out of scope (NUNCA faça sem confirmação explícita):**

- Não rodar `pnpm test` / `pnpm typecheck` / `pnpm lint` / qualquer suite de testes — EXCETO no modo "aplicar correções" do passo 8 (PR própria), onde rodar a verificação dos arquivos tocados é obrigatório
- Não fazer commit, push, nem modificar arquivos do repo sob review — EXCETO no modo "aplicar correções" do passo 8 (PR própria), e mesmo aí só após o usuário escolher essa opção
- Não aprovar nem mergear (`gh pr review --approve`, `gh pr merge`)
- Não escrever em lugar nenhum exceto: o arquivo final no vault; (opcionalmente) a review da PR via `gh api` no passo 8; e, no modo "aplicar correções", os arquivos de código + commit na branch da PR própria. O modo "redigir rascunhos de réplica" (passo 8d) também grava um arquivo de rascunhos no vault — mas **nunca posta no GitHub**.

**Sobre o passo 8:** após gravar o arquivo no Obsidian (passo 6), o passo 8 oferece, via `AskUserQuestion`, a ação pós-review. O menu MUDA conforme a PR seja **de terceiros** (postar comentários inline, incluindo a opção de redigir rascunhos de réplica para threads abertas) ou **do próprio Gabriel** (aplicar as correções recomendadas em commits semânticos). Nunca agir sem o usuário escolher uma opção positiva.

## Inputs aceitos

| Forma | Significado |
|-------|-------------|
| `/review-arco` (sem arg) | Branch atual do `pwd` vs `main` |
| `/review-arco 790` | PR #790 do repo do `pwd` atual |
| `/review-arco https://github.com/OlaIsaac/backoffice-bff/pull/790` | PR do URL informado (qualquer repo OlaIsaac/classapp) |
| `/review-arco https://github.com/classapp/communication-api/pull/698` | idem, cross-repo |

**Flag opcional:** `--agents-on` (alias `-aon`) pode aparecer em qualquer posição dos argumentos (antes ou depois do PR number/URL). Quando ausente: comportamento atual inalterado. Quando presente: ativa o pipeline de agents especializados do repo em benchmark mode (ver passo 3c).

## Fluxo de execução

### 1. Resolver o target

```bash
# Detectar e remover a flag --agents-on / -aon antes de resolver o target
AGENTS_ON=false
for arg in "$@"; do
  case "$arg" in --agents-on|-aon) AGENTS_ON=true ;; esac
done
# ARGS = argumentos sem a flag (usados abaixo como PR_NUMBER / URL)

# se arg numérico (após remover a flag):
PR_NUMBER=<primeiro arg que não seja a flag>
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

Detectar se a PR é **do próprio Gabriel** (decide o menu do passo 8). Buscar também o assignee:

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

Extrair ticket Linear do título da PR ou nome da branch (regex `[A-Z]{2,5}-\d+`).

Se tiver checkout local do repo alvo, também leia:

- `CLAUDE.md`
- `.github/PULL_REQUEST_TEMPLATE.md`

### 3b. Histórico de rodadas anteriores e threads existentes

**Rodadas anteriores da mesma PR (vault):**

```bash
ls ~/.notes/pr-reviews/ \
  | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}-{repo-slug}-PR{number}(-v[0-9]+)?\.md$" \
  | sort
```

Se houver arquivo(s), ler o mais recente e extrair apenas a seção `## Comentários de Review` + frontmatter (`status`, `date`). Guardar como `PREV_REVIEW_COMMENTS`. Se não houver, `PREV_REVIEW_COMMENTS = null`.

**Threads já postadas na PR (abertas e resolvidas):**

```bash
gh api graphql -f query='
{
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: PR) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          comments(first: 1) {
            nodes { databaseId url author { login } createdAt body }
          }
        }
      }
    }
  }
}'
```

Para comentários com body truncado (> 200 chars), buscar o body completo via REST:

```bash
gh api repos/$REPO_FULL/pulls/comments/<databaseId> -q '.body'
```

Guardar como `PR_THREADS` (dois conjuntos: `open` + `resolved`). Se a query GraphQL falhar (rate limit, permissão), continuar com `PR_THREADS = null` e avisar no chat.

### 3c. Pipeline --agents-on (quando `AGENTS_ON == true`)

Detectar o repo-slug e o caminho do repo-owner:

```bash
REPO_SLUG=$(gh repo view --json name -q .name)
REPO_OWNER_PATH="$HOME/.dotfiles-ai/claude/agents/isaac/$REPO_SLUG/repo-owner.md"
```

Se `$REPO_OWNER_PATH` não existir:
- Avise no chat: `nenhum agent especializado encontrado para <repo-slug>. Seguindo com fluxo normal.`
- Defina `AGENTS_ON = false` e avance para o passo 4 sem benchmark.

Se existir, invocar o `repo-owner` via Task tool ANTES do passo 4 (passar o repo-owner.md como `subagent_type` ou via instrução inline):
- Inputs: diff completo, metadados da PR (título, número, repo, branches, autor) e a flag `--agents-on`.
- O repo-owner orquestra os agents especializados e retorna um `AGENT_REPORT` estruturado com findings por categoria (Critical, Important, Notes) e "Agents run".
- Guardar `AGENT_REPORT` — alimenta o benchmark no passo 4b e o template no passo 6.

### 4. Delegar análise ao subagent

**Inputs base** (comuns aos dois fluxos abaixo):
- Diff completo, lista de commits, título + ticket, metadados (repo, autor, branches), caminho do checkout local se disponível
- `PREV_REVIEW_COMMENTS` — instrução: não repetir findings já cobertos; referenciar "já apontado em rodada anterior" se sobreposição for inevitável
- `PR_THREADS` — instrução: se um finding cobrir o mesmo ponto de thread existente, classificar como `resolved` (se `isResolved == true`) ou referenciar a URL da thread irmã

O subagent retorna o relatório estruturado em `SUMARIO`, `COMENTARIOS`, `CHECKLIST`, `VEREDITO`, `STATUS`, `PRIORIDADE`. Você não precisa traduzir nada — só fazer parsing e injetar no template.

#### 4a. Sem --agents-on (`AGENTS_ON == false`)

Use a Task tool com `subagent_type: arco-pr-reviewer` passando os inputs base. Guardar resultado como `FINAL_REPORT`.

#### 4b. Com --agents-on — benchmark mode (`AGENTS_ON == true`)

Execute em paralelo via Task tool:

**Task A — Baseline:** `arco-pr-reviewer` com os inputs base (sem `AGENT_REPORT`). Guardar como `BASELINE_REPORT`.

**Task B — Agents:** `arco-pr-reviewer` com os inputs base **mais** o `AGENT_REPORT` do passo 3c como seção adicional. Instrução ao subagent: usar os findings do `AGENT_REPORT` como contexto para aprofundar a análise, não apenas replicá-los — avaliar se cada finding procede e integrá-lo como evidência. Guardar como `AGENTS_REPORT`.

Após ambas concluírem, computar o benchmark (identificar findings por chave `(arquivo, linha/bloco, tema)`):

```
só_agents   = findings em AGENTS_REPORT   não presentes em BASELINE_REPORT
só_baseline = findings em BASELINE_REPORT não presentes em AGENTS_REPORT
ambos       = findings presentes nos dois
```

Guardar `BENCHMARK = { só_agents, só_baseline, ambos }`.
O `AGENTS_REPORT` é o relatório consolidado que vai para o vault. Definir `FINAL_REPORT = AGENTS_REPORT`.

### 5. Computar nome do arquivo

Convenção:

- **Com PR number:** `YYYY-MM-DD-{repo-slug}-PR{number}.md`
  - Exemplo: `2026-04-30-backoffice-bff-PR790.md`
- **Sem PR (branch local):** `YYYY-MM-DD-{repo-slug}-{branch-slug}.md`
  - Exemplo: `2026-04-30-backoffice-bff-cma-2400-feature-x.md`
  - branch-slug = nome da branch em kebab-case, sem prefixos como `feat/`, `fix/`

Path completo: `$NOTES_VAULT/pr-reviews/{filename}`

> **Eixo achatado:** desde o flattening do vault, PR reviews vivem todas em `pr-reviews/` na raiz — o repo já está embutido no nome do arquivo (`{repo-slug}-PR{number}`). O contexto (`arco`) viaja no frontmatter (campo `context`), não como subpasta.

**Re-runs no mesmo dia:**

- Se já existe o arquivo, sufixar com `-v2`, `-v3`, etc.
  - `2026-04-30-backoffice-bff-PR790-v2.md`
- Se o usuário escolher "Redigir rascunhos de réplica" (passo 8d), o arquivo usa sufixo `-v{N}-answers.md`. O `/review-arco` puro usa só `-vN`.

### 6. Renderizar template e gravar

Template canônico (preencher com os dados coletados + output do subagent):

> **Quando `AGENTS_ON == true`:** inserir a seção `## Benchmark --agents-on` imediatamente ANTES do `## Resumo`, conforme bloco abaixo. Quando `AGENTS_ON == false`, omitir essa seção inteira.

```markdown
<!-- SOMENTE quando --agents-on está presente -->
## Benchmark --agents-on

| Categoria | Findings |
|-----------|----------|
| Encontrado apenas com agents | {lista de (arquivo:linha — tema) de só_agents, ou "(nenhum)"} |
| Encontrado apenas no baseline | {lista de só_baseline, ou "(nenhum)"} |
| Encontrado em ambos | {lista de ambos, ou "(nenhum)"} |

Agents run: {lista de agents invocados pelo repo-owner, conforme seção "Agents run" do AGENT_REPORT}
<!-- FIM da seção benchmark -->
```

```markdown
---
type: pr-review
date: {YYYY-MM-DD}
pr_url: "{url ou 'N/A — local branch'}"
pr_number: {number ou null}
repo: "{repo-slug}"
context: arco
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

Depois de gravar com sucesso, responda com:

```
Review salvo em {caminho-completo-do-arquivo}.

Veredito: {STATUS} — {1 frase do veredito}.
```

**Não** repita o conteúdo do review no chat. **Não** faça resumo expandido. O arquivo é a fonte de verdade.

Em seguida, vá direto para o passo 8 (sem esperar input adicional do usuário). Se o review **não tem PR number** (branch local sem PR aberta) ou se o subagent não retornou nenhum comentário 🔴/🟡/🔵/🟢/⚠️ acionável, **pule o passo 8** — apenas terminar.

### 8. Oferecer ação pós-review (aplicar ou publicar)

Se há PR aberta e comentários acionáveis no review, perguntar via `AskUserQuestion` (uma única question, single-select). **O conjunto de opções depende de `IS_OWN_PR`** (passo 3): em PR própria, o padrão é aplicar as correções; em PR de terceiros, o padrão é postar inline.

#### 8a. PR do próprio Gabriel (`IS_OWN_PR == true`)

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
  3. `Postar comentários inline` — descrição: `Em vez de aplicar, posta o review na PR (mesmo menu de PR de terceiros). Útil pra registrar sem mexer no código agora.`
  4. `Não fazer nada` — descrição: `Review fica só no Obsidian. Você decide depois.`

Se escolher 1 ou 2 → ir para **8c**. Se escolher 3 → usar a postagem de **8b**. Se 4 → terminar.

#### 8b. PR de terceiros (`IS_OWN_PR == false`) — publicar inline

Perguntar via `AskUserQuestion` (single-select):

- **Header:** `Postar na PR?`
- **Question:** `Quer postar algum subset dos comentários direto na PR #{number}?`
- **Options (nessa ordem):**
  1. `Prioridades + kudos (Recomendado)` — descrição: `Posta 🔴 + ⚠️ + itens da lista PRIORIDADE + todos os 🟢 inline. Padrão histórico do Gabriel.`
  2. `Só prioridades` — descrição: `Posta 🔴 + ⚠️ + itens da lista PRIORIDADE inline. Sem kudos.`
  3. `Tudo` — descrição: `Posta todos os comentários do review (🔴 🟡 🔵 🟢 ⚠️) inline. 💭 nunca vai.`
  4. `Não postar` — descrição: `Review fica só no Obsidian. Eu reviso antes de decidir.`
  5. `Redigir rascunhos de réplica` — descrição: `Lê as threads abertas, redige rascunhos de réplica em PT-BR classificados (accepts-suggestion / defends-decision / needs-discussion / needs-code-change) e salva no vault como {repo}-PR{n}-v{N}-answers.md. Não posta nada no GitHub.`

> A opção "Recomendado" é a primeira e tem `(Recomendado)` no label, conforme padrão do tool.

Se o usuário escolher a opção 5, ir para **8d**. Caso contrário, se o usuário escolher uma opção positiva (1, 2 ou 3), montar a review e postar via `gh api`:

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
- Kudos sobre arquivo inteiro novo (ex: `.changeset/*`) vão no `body` da review (não dão pra inline em "arquivo todo").
- Manter PT-BR com acentuação correta e o emoji prefix (🔴 🟡 🔵 🟢 ⚠️) em cada `body` de comentário, para casar com a legenda do review.
- **Sem em-dashes** nos textos publicados (regra global do usuário — usar vírgula, dois-pontos, parênteses).
- Se a PR está em repo cross-org sem acesso de escrita, capturar o erro do `gh api` e reportar ao usuário sem retentar.

Após `gh api` retornar sucesso (com `html_url` da review), responder no chat **só** com:

```
Review postada: {html_url}

{n} inline + {m} kudos no corpo. Submetida como COMMENTED (não-bloqueante).
```

Se o usuário escolher "Não postar" ou cancelar a question, apenas terminar (sem mensagem extra).

#### 8c. Aplicar correções (modo PR própria)

Aplicar no working tree as correções **acionáveis** do review: 🔴 (obrigatórias), 🟡 (necessárias) e 🔵 (sugestões) que sejam mudança concreta de código. **Pular** 🟢 (elogios), 💭 (notas internas) e itens que sejam só "considerar/avaliar" sem ação definida.

Regras:

- **Verificar antes de aplicar:** cada finding deve ser confirmado contra o código real (o `arco-pr-reviewer` gera falsos positivos). Se um item for improcedente na verificação, NÃO aplicar, e registrar no resumo final por que foi pulado. Se for uma decisão de design genuinamente ambígua (trade-off real), perguntar ao usuário em vez de chutar.
- **3-file gate (regra do arco):** se as correções tocarem **mais de 3 arquivos**, NÃO edite direto — delegue a um agente de implementação (`general-purpose` ou específico) com instruções precisas: arquivos, edições exatas, comandos de verificação e mensagem(ns) de commit. Para ≤3 arquivos, pode aplicar direto.
- **Verificação obrigatória** nos arquivos tocados, antes de commitar: typecheck + lint + os testes unitários afetados. Respeitar a versão de Node pinada do repo (`.nvmrc` via fnm/nvm) quando houver. Se algum gate falhar por motivo ambiental (registry/auth/deps faltando), confirmar que é idêntico ao baseline `main` e registrar; se falhar por causa da mudança, corrigir antes de commitar.
- **Commits semânticos:** Conventional Commits + emoji, PT-BR com acentuação correta. Agrupar por tema (um commit por finding ou por grupo coerente, a critério). Trailer **obrigatório** `Co-Authored-By: Claude <noreply@anthropic.com>` via HEREDOC. Se o repo tiver hook (husky/lint-staged) quebrado por ambiente, usar `--no-verify` e registrar o motivo.
- **Push:** só na opção 2 (Aplicar e dar push), e só na branch `headRefName` da PR (nunca `main`). Opção 1 deixa os commits locais.
- **Nunca** postar comentário, aprovar nem mergear neste modo.
- **Atualizar a descrição da PR** quando a correção mudar materialmente o que a PR faz (ex.: removeu/alterou algo descrito no corpo): editar via `gh pr edit $PR_NUMBER --repo $REPO_FULL --body-file <arquivo>`. Manter sem em-dashes (texto externo).

Resposta no chat ao final: tabela curta `{finding | aplicado/pulado | arquivos}`, depois `{commit(s) SHA, resultado da verificação, e range de push se houve}`. Sinalizar findings pulados (improcedentes/ambíguos) e o que precisa de decisão do usuário.

#### 8d. Redigir rascunhos de réplica

Usar os `PR_THREADS.open` já coletados no passo 3b. Se `PR_THREADS` for `null` (query falhou no passo 3b), coletar agora com o mesmo query GraphQL.

**Skip threads triviais (independente de flags):**
- Body só com emoji de aprovação (`:+1:`, `LGTM`, `👍`, `✅`)
- Comentário do próprio autor da PR sem réplica de outros (não há ninguém pra responder)

Delegar ao subagent `arco-pr-answerer` passando:

- Lista de threads abertas (id, path:line, diff_hunk, cadeia de mensagens, isResolved)
- Diff atual da PR
- Metadados: `{owner}/{repo}`, número da PR, autor, branches

O subagent retorna seções: `SUMARIO`, `THREADS`, `RESUMO_ACOES`, `STATUS_GERAL`.

**Nome do arquivo:** `YYYY-MM-DD-{repo-slug}-PR{number}-v{N}-answers.md`
Re-runs: se já existe `-v1-answers.md`, usar `-v2-answers.md`, e assim por diante.
Path: `$NOTES_VAULT/pr-reviews/{filename}`

Gravar com Write tool. Resposta no chat:

```
Rascunhos salvos em {caminho}.

{count} threads endereçados. {breakdown: "3 accepts-suggestion, 1 defends-decision, 1 needs-discussion"}
```

**Nunca** executar os comandos `gh api ... POST` do output — o arquivo é draft-only para revisão antes de postar.

## Notas finais

- Sempre PT-BR com acentuação correta no conteúdo do review (frontmatter pode ficar em inglês onde já era padrão: `type`, `status`)
- Se o subagent retornar erro ou output mal formatado, mostre o erro e **não** grave arquivo parcial
- Se faltar `gh` autenticado, peça ao usuário pra rodar `gh auth login` e aborte
