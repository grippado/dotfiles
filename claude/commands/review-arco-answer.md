---
name: review-arco-answer
description: Lê threads de comentários de uma PR Arco/OlaIsaac, redige rascunhos de réplicas em PT-BR e persiste o resultado como arquivo .md no Obsidian vault em ~/www/personal/notes/1-contexts/arco/pr-reviews/<repo>/. Não posta nada no GitHub.
user_invocable: true
---

# /review-arco-answer

Skill orquestradora para **redigir réplicas** a comentários abertos de uma PR. Coleta threads via `gh api`, delega a redação ao subagent `arco-pr-answerer`, e persiste o resultado em arquivo markdown padronizado no vault Obsidian do Gabriel.

Roda **independente** de `/review-arco` — não exige review prévio. Pode ser usado em qualquer PR com comentários pertinentes.

**Out of scope (NUNCA faça):**

- Não rodar `pnpm test` / `pnpm typecheck` / `pnpm lint` / qualquer suite
- Não postar nada no GitHub: `gh pr comment`, `gh pr review`, nem executar os comandos `gh api ... POST` que aparecem no output (esses são pra o usuário copiar-colar)
- Não fazer commit, push, nem modificar arquivos do repo
- Não aprovar nem mergear
- Não escrever em lugar nenhum exceto o arquivo final no vault

## Inputs aceitos

| Forma | Significado |
|-------|-------------|
| `/review-arco-answer` (sem arg) | PR da branch atual do `pwd` |
| `/review-arco-answer 790` | PR #790 do repo do `pwd` atual |
| `/review-arco-answer https://github.com/OlaIsaac/backoffice-bff/pull/790` | PR do URL informado |
| `/review-arco-answer 790 --all` | Inclui threads resolvidos (default = só não-resolvidos) |

A flag `--all` pode aparecer junto com qualquer forma acima.

## Fluxo de execução

### 1. Resolver o target

```bash
# parse args: separar PR-spec de --all
# se URL: parsear {owner}/{repo}/pull/{number}
# se número: REPO_FULL=$(gh repo view --json nameWithOwner -q .nameWithOwner)
# se sem arg:
#   PR_NUMBER=$(gh pr view --json number -q .number)
#   REPO_FULL=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

Se `gh auth status` falhar, aborte pedindo `gh auth login`.

### 2. Decidir cross-repo vs local

Se o `pwd` é checkout do repo alvo (ou sem arg), trabalhe direto. Se for cross-repo:

1. Tente `gh pr view <n> --repo {owner}/{repo}` — se funcionar, segue só com gh
2. Se falhar (auth, repo privado sem acesso), aborte:
   > `Não consegui acessar {owner}/{repo}#{n} a partir daqui. Faça \`cd\` no checkout local de {repo} e rode /review-arco-answer {n} novamente.`
3. Não tente trocar de pwd automaticamente

### 3. Coletar metadados da PR

```bash
gh pr view $PR_NUMBER --repo $REPO_FULL --json number,title,body,author,headRefName,baseRefName,url,state,isDraft
gh pr diff $PR_NUMBER --repo $REPO_FULL
```

### 4. Coletar threads de comentários

**Review comments (line-anchored):**

```bash
gh api "repos/$REPO_FULL/pulls/$PR_NUMBER/comments" --paginate
```

Campos relevantes por comentário: `id`, `in_reply_to_id`, `path`, `line` (ou `original_line`), `diff_hunk`, `body`, `user.login`, `created_at`, `updated_at`.

**Agrupar em threads:**

- Thread raiz = comentário com `in_reply_to_id == null`
- Réplicas = comentários com `in_reply_to_id == <id-da-raiz>` (cronológico por `created_at`)

**Top-level PR comments:**

```bash
gh api "repos/$REPO_FULL/issues/$PR_NUMBER/comments" --paginate
```

Cada um vira uma "thread" sem `path:line`. Não há réplicas nativas — quem responde cria novo issue comment.

### 5. Filtrar threads

GitHub não expõe `resolved` em `pulls/{n}/comments`. Para detectar resolução, usar GraphQL:

```bash
gh api graphql -f query='
  query($owner:String!,$repo:String!,$pr:Int!){
    repository(owner:$owner,name:$repo){
      pullRequest(number:$pr){
        reviewThreads(first:100){
          nodes{ id isResolved comments(first:1){ nodes{ databaseId } } }
        }
      }
    }
  }
' -F owner="$OWNER" -F repo="$REPO" -F pr=$PR_NUMBER
```

Mapear `isResolved` para cada thread via `databaseId` do primeiro comentário (que casa com `id` do REST).

**Default:** filtrar apenas threads onde `isResolved == false`.
**Com `--all`:** incluir todos.

Se a query GraphQL falhar (permissão, rate limit), avisar no chat e seguir com **todos** os threads como fallback (anotar no frontmatter `resolution_data: unavailable`).

**Skip threads triviais** (regardless de flags):

- Body só com emoji de aprovação (`:+1:`, `LGTM`, `👍`, `✅`)
- Comentário do próprio autor da PR sem réplica de outros (não há ninguém pra responder)

### 6. Buscar nome humano do autor da PR

```bash
gh api users/{login} --jq .name
# se vier null/vazio, usa só o login
```

### 7. Delegar redação ao subagent

Use a Task tool com `subagent_type: arco-pr-answerer` passando:

- Lista de threads (cada um com: id, path:line, diff_hunk, cadeia de mensagens, estado resolved/unresolved)
- Diff atual da PR
- Metadados: `{owner}/{repo}`, número da PR, autor, branches
- Caminho do checkout local se disponível

Subagent retorna seções: `SUMARIO`, `THREADS`, `RESUMO_ACOES`, `STATUS_GERAL`. Faça parsing e injete no template.

### 8. Computar nome do arquivo

Convenção:

- **Sempre com PR number** (sem PR não faz sentido — não há comentários):
  - `YYYY-MM-DD-{repo-slug}-PR{number}-v{N}-answers.md`
  - Exemplo: `2026-04-30-backoffice-bff-PR790-v1-answers.md`

**Re-runs:**

- Sempre regenerar do zero (não tentar diff incremental)
- Se já existe `-v1-answers.md`, usar `-v2-answers.md`, e assim por diante
- Independente do `--all` — flag não muda o sufixo

Path completo: `$NOTES_VAULT/1-contexts/arco/pr-reviews/{repo-slug}/{filename}`

> **Estrutura por repo:** desde 2026-05-08, PR reviews (e seus answers) vivem em subpastas por repo (`pr-reviews/communication-api/`, etc.). Procure o review original na subpasta do repo correspondente.

### 9. Linkar review original (opcional)

Procurar no diretório do vault (na subpasta do repo):

```bash
ls "$NOTES_VAULT/1-contexts/arco/pr-reviews/{repo-slug}/" \
  | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}-{repo-slug}-PR{number}(-v[0-9]+)?\.md$" \
  | sort | tail -1
```

Se encontrar, preencher `answers_to: <filename>` no frontmatter. Senão, omitir o campo.

### 10. Renderizar template e gravar

```markdown
---
type: pr-answer
date: {YYYY-MM-DD}
pr_url: "{url}"
pr_number: {number}
repo: "{repo-slug}"
author: "{gh-login}"
threads_addressed: {count}
threads_filter: {unresolved-only | all}
status_geral: {short slug do status}
{ se review prévio existe: }answers_to: "{filename do review}"
tags: [pr-answer, {repo-slug}, PR{number}]
---

# PR Answers: [{TICKET-XXX se houver}] {Título da PR}

**PR:** [#{number}]({url})
**Repo:** {repo-slug}
**Author:** {gh-login}{ se nome humano: ` ({Nome Humano})`}
**Branch:** `{head}` -> `{base}`
**Threads endereçados:** {count} ({unresolved | all})
**Gerado em:** {YYYY-MM-DD}

## Resumo

{seção SUMARIO do subagent}

## Legenda de classificação

| Classificação | Significado |
|---------------|-------------|
| `accepts-suggestion` | Concorda e vai aplicar |
| `needs-code-change` | Aceita + exige mudança maior no código |
| `defends-decision` | Discorda com fundamento, mantém como está |
| `needs-discussion` | Precisa de mais contexto / decisão do reviewer |

## Threads

{seção THREADS do subagent — já vem formatada com `### Thread N — ...`}

## Ações no código

{seção RESUMO_ACOES — omitir a seção inteira se subagent não retornou}

## Status

{seção STATUS_GERAL do subagent}
```

Use a Write tool para gravar.

### 11. Resposta no chat

Depois de gravar com sucesso, responda **apenas** com:

```
Answers salvos em {caminho-completo}.

{count} threads endereçados ({unresolved | all}).
{breakdown da classificação — ex.: "3 accepts-suggestion, 1 defends-decision, 1 needs-discussion"}
```

**Não** repita o conteúdo no chat. **Não** execute os comandos `gh api ... POST` do output.

## Notas finais

- PT-BR com acentuação correta no conteúdo (frontmatter pode ficar em inglês)
- Se subagent retornar erro ou output mal formatado, mostre o erro e **não** grave arquivo parcial
- Se não houver threads pertinentes (todos triviais ou só do próprio autor), avise no chat e **não** grave arquivo
- Se faltar `gh` autenticado, peça ao usuário pra rodar `gh auth login` e aborte
