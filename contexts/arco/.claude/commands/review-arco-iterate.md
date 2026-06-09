---
name: review-arco-iterate
description: Itera as threads NÃO resolvidas de uma PR Arco/OlaIsaac (tipicamente do bot arco-pr-reviewer), verifica cada alegação contra o código real, aplica as correções pertinentes, e então responde + reage (👍/👎) + resolve as threads no GitHub, commita semanticamente e dá push. Diferente de /review-arco-answer (read-only), este comando ESCREVE no GitHub e no repo.
user_invocable: true
---

# /review-arco-iterate

Comando orquestrador para **fechar o loop** de uma rodada de review: lê as threads abertas, aplica o que é pertinente, responde/reage/resolve no GitHub, e atualiza a PR com commit + push.

É o irmão "ativo" da família:

- `/review-arco` — gera o review (read-only, salva no vault).
- `/review-arco-answer` — redige rascunhos de réplicas (read-only, salva no vault, não posta).
- `/review-arco-iterate` — **aplica + posta + resolve + commita + pusha** (este).

Roda independente dos outros. Pensado para PRs com rodadas do bot `arco-pr-reviewer`, mas trata threads humanas também.

## Inputs aceitos

| Forma | Significado |
|-------|-------------|
| `/review-arco-iterate` (sem arg) | PR da branch atual do `pwd` |
| `/review-arco-iterate 962` | PR #962 do repo do `pwd` atual |
| `/review-arco-iterate https://github.com/classapp/communication-api/pull/962` | PR do URL informado |
| `/review-arco-iterate 962 --auto` | Pula a confirmação e executa o fluxo completo direto (default da confirmação = "postar tudo") |

A flag `--auto` pode aparecer junto com qualquer forma acima.

## Ordem de execução OBRIGATÓRIA (NÃO reordenar)

1. **Ler** as threads não resolvidas.
2. **Planejar e executar** todas as correções pertinentes, mantendo os arquivos alterados no working tree.
3. **Responder** as threads no GitHub, **reagir** (👍/👎) e **resolver** cada thread.
4. **Commitar** semanticamente e **dar push**.

> O push só pode acontecer DEPOIS do passo 3 completo (todas as threads endereçadas respondidas E resolvidas). Nunca pushar antes de fechar as threads.

A confirmação interativa (passo 6) fica ENTRE a fase 2 (aplicar correções) e as fases 3-4 (postar + commitar): as correções locais são aplicadas primeiro (reversíveis), o plano completo é mostrado, e só então o usuário decide o que postar/pushar. Com `--auto`, pula a confirmação.

## Out of scope (NUNCA faça)

- Não aprovar nem mergear (`gh pr review --approve`, `gh pr merge`).
- Não usar `event: APPROVE` / `REQUEST_CHANGES` em nada.
- Não pushar para `main` nem trocar de branch sozinho.
- Não resolver thread humana que esteja em `needs-discussion` (ver guardrail no passo 3).
- Não retentar escrita em repo cross-org sem acesso — capturar o erro e reportar.

---

## Fluxo de execução

### 1. Resolver o target + sanidade

```bash
gh auth status           # se falhar, abortar pedindo `gh auth login`
# parse args: separar PR-spec de --auto
# URL  -> {owner}/{repo}/pull/{number}
# número -> REPO_FULL=$(gh repo view --json nameWithOwner -q .nameWithOwner)
# sem arg ->
#   PR_NUMBER=$(gh pr view --json number -q .number)
#   REPO_FULL=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

Cross-repo: se o `pwd` não for o checkout do repo alvo, **aborte** pedindo para `cd` no checkout local. Este comando precisa do working tree para aplicar correções e commitar, então só opera local.

**Atenção a worktrees:** o checkout da PR pode estar em `.worktrees/<branch>/`. Confirme em qual diretório a branch da PR está (`git worktree list`) e opere lá. A branch local precisa casar com `headRefName` da PR.

### 2. Coletar metadados + TODAS as threads (abertas e resolvidas)

```bash
gh pr view $PR_NUMBER --repo $REPO_FULL --json number,title,headRefName,baseRefName,url,state,isDraft
```

Buscar **todas** as threads via GraphQL (a REST não expõe `isResolved`). Buscar resolvidas também é essencial: elas formam o **corpus de referência** para o cross-reference do passo 3.

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

Particionar o resultado em dois conjuntos:

- **Threads abertas** (`isResolved == false`) — as que serão endereçadas neste run. Guardar: `id` (NODE id `PRRT_...`, usado para resolver), `path`, `line`, `isOutdated`, e do primeiro comentário `databaseId` (reply/react), `url` (permalink), `author.login`, `body`.
- **Corpus de referência** (`isResolved == true`) — guardar `url`, `path:line`, `author.login` e um resumo do ponto + veredito (ler o body; se truncado, `gh api repos/$REPO_FULL/pulls/comments/<databaseId>`). Esse corpus alimenta a detecção de sobreposição.

Ler o body completo de um comentário quando truncado:

```bash
gh api repos/$REPO_FULL/pulls/comments/<databaseId> -q '.body'
```

Ler o body completo de um comentário quando truncado:

```bash
gh api repos/$REPO_FULL/pulls/comments/<databaseId> -q '.body'
```

**Top-level PR comments** (sem `path:line`) também contam como threads endereçáveis: `gh api repos/$REPO_FULL/issues/$PR_NUMBER/comments`. Eles não têm reply nativo (responder = novo issue comment) nem resolução; reações vão em `repos/$REPO_FULL/issues/comments/<id>/reactions`.

**Pular threads triviais:** body só com aprovação (`LGTM`, `👍`, `:+1:`, `✅`) ou comentário do próprio autor sem réplica de terceiros.

Se não sobrar nenhuma thread acionável, avise no chat e **termine** (não commitar nada).

### 3. Verificar e decidir cada thread (planejar)  · fase 1

Para CADA thread aberta, ANTES de aceitar ou recusar:

- **Verificar a alegação contra o código/testes/docs reais.** O `arco-pr-reviewer` produz falsos positivos com frequência (ex.: aponta perda de precisão num `bigint mode:'number'`, ou "mensagem some" num cenário que já tem teste). Leia o arquivo citado, os testes adjacentes e a doc do endpoint antes de concluir. Reviewers humanos erram menos, mas o mesmo rigor se aplica.
- Classifique: **procede** (aplicar correção) ou **improcedente/marginal** (recusar com fundamento).
- Sempre **citar `arquivo:linha`** na justificativa.

#### 3a. Cross-reference com threads já tratadas (camada de decisão)

Antes de redigir a réplica, comparar o ponto de cada thread aberta contra (a) o corpus de threads resolvidas do passo 2 e (b) as threads já processadas mais cedo NESTE run. Classificar a sobreposição:

- **`none`** — ponto novo. Seguir normal.
- **`duplicate`** — mesmo ponto já tratado e decidido numa thread irmã, sem nada de novo. Aplica a MESMA decisão. A réplica DEVE citar e **linkar** a thread irmã (markdown `[link](url)`) e dizer explicitamente que é o mesmo ponto já endereçado. Não reabrir a análise nem reaplicar correção que já foi feita.
- **`related-but-distinct`** — toca o mesmo código/tema de uma thread irmã, mas traz um ângulo genuinamente diferente (ex.: mesma subquery, mas o irmão era sobre *correção* e este é sobre *performance/índice*). A réplica DEVE linkar a irmã para contexto E deixar claro **o que há de diferente**, e dar a este ponto sua **própria decisão** (não herdar a da irmã).

**Regra de ouro (a "camada de decisão" que o usuário pediu):** nunca tratar como duplicado de forma silenciosa. Sempre articular, na réplica, se é duplicado puro ou se, apesar de já citado em outro ponto, há algo distinto que merece decisão própria. Na dúvida entre `duplicate` e `related-but-distinct`, escolher `related-but-distinct` e explicar a diferença, errar para o lado de pensar a mais.

Como linkar a irmã: usar o `url` (permalink do comentário) coletado no passo 2. Ex.: `já endereçado em [PERF / MIN(id)](https://github.com/{owner}/{repo}/pull/{n}#discussion_r{databaseId})`.

#### 3b. Reação alinhada ao teor da resposta (vale para bot E humanos)

- 👍 (`content=+1`) quando a sugestão é acolhida/procedente (e será aplicada), OU quando é um `related-but-distinct` válido.
- 👎 (`content=-1`) quando improcedente, marginal, ou `duplicate` de algo já recusado.
- Para `duplicate` de algo já **aceito e aplicado**: 👍 (o ponto é válido), com réplica curta apontando a irmã.

Monte o **plano** (o "dry-run" da confirmação): por thread, registre `{databaseId, path:line, autor, veredito, sobreposição (none|duplicate|related-but-distinct + link da irmã), reação 👍/👎, rascunho da réplica}`, e ao final `{lista de arquivos alterados, resumo do diff, mensagem de commit proposta}`.

### 4. Aplicar as correções pertinentes  · fase 2

Para as threads que **procedem**, aplique as correções no working tree. Mantenha os arquivos alterados. Para as que NÃO procedem, não há mudança de código — só réplica + reação no passo 7.

### 5. Quality gate (antes de oferecer o push)

Nos arquivos tocados:

```bash
pnpm typecheck
pnpm lint        # ou: npx biome check <arquivos>
# testes unitários afetados:
CI=true AUTH_TOKEN=test-token npx vitest run <arquivos de teste afetados>
```

Integração roda em Docker. Se o daemon estiver down (`docker info` falha), **não bloqueie** — registre no plano "integração não validada localmente (Docker down)" e avise o usuário. Seguir o Agent Workflow do `CLAUDE.md` do repo (self-reviewer) quando aplicável.

> O Biome ignora os paths de teste de integração: rodar `biome check` num arquivo sob `tests/integration/` reporta "Checked 0 files" — isso é esperado, não é erro; registrar como n/a no plano.

### 6. Confirmação interativa (pular se `--auto`)

Mostre no chat o plano resumido (vereditos + reações + arquivos alterados + mensagem de commit), e pergunte via `AskUserQuestion` (single-select):

- **Header:** `Atualizar PR?`
- **Question:** `Apliquei as correções e preparei as respostas das {N} threads da PR #{number}. O que fazer agora?`
- **Options (nesta ordem):**
  1. `Postar tudo e atualizar a PR (Recomendado)` — descrição: `Posta as réplicas + reações 👍/👎, resolve as threads, e então commita + pusha as correções.`
  2. `Postar respostas e resolver, sem push` — descrição: `Interage no GitHub (réplicas, reações, resolve threads) mas deixa o commit/push pra você revisar o diff antes.`
  3. `Só deixar as correções locais` — descrição: `Não toca no GitHub. Threads ficam abertas, nada é commitado. Você revisa tudo localmente.`
  4. `Cancelar` — descrição: `Não posta nada. Os arquivos alterados ficam no working tree pra você inspecionar ou reverter.`

> A opção recomendada é a primeira, com `(Recomendado)` no label. Com `--auto`, assuma a opção 1 sem perguntar.

### 7. Postar réplicas + reações + resolver (opções 1 e 2)  · fase 3

Para cada thread endereçada, na ordem: **reply → reação → resolve**.

```bash
# Réplica (review comment line-anchored):
gh api repos/$REPO_FULL/pulls/$PR_NUMBER/comments/<databaseId>/replies -f body='...'

# Reação no comentário:
gh api repos/$REPO_FULL/pulls/comments/<databaseId>/reactions -f content='+1'   # ou -1

# Resolver a thread (usa o NODE id PRRT_..., NÃO o databaseId):
gh api graphql -f query='mutation($id:ID!){ resolveReviewThread(input:{threadId:$id}){ thread { isResolved } } }' -f id="<PRRT_...>"
```

**GOTCHA zsh:** variáveis não sofrem word-splitting. Ao iterar IDs, processe **um por vez** (loop com a lista literal ou linha a linha) — nunca passe a string inteira de IDs de uma vez para a mutation, senão o GraphQL recebe os IDs concatenados e dá `NOT_FOUND`.

Top-level issue comments: responder = novo `gh api repos/$REPO_FULL/issues/$PR_NUMBER/comments -f body=...` referenciando o autor; reação via `issues/comments/<id>/reactions`. Não há resolve.

**Guardrail para threads HUMANAS:** resolva automaticamente quando o assunto está encerrado (acolhido + aplicado, ou recusado com justificativa clara e baixa controvérsia). Se a thread precisa de decisão do revisor (`needs-discussion`), **poste a réplica + reação mas NÃO resolva** — deixe aberta e sinalize ao usuário no resumo final.

### 8. Commit + push (somente opção 1, e só após o passo 7 completo)  · fase 4

Confirme que TODAS as threads endereçadas foram respondidas e resolvidas antes de pushar.

```bash
git add <arquivos alterados>
git commit -m "$(cat <<'EOF'
<emoji> <tipo>(<escopo>): <descrição do que e por que>

<corpo: o que mudou e o porquê das correções dos comentários>

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
git push origin <headRefName>
```

- Conventional Commits + emoji prefix. Se forem correções heterogêneas, agrupe num commit coerente (ou separe em commits por tema, a critério).
- **OBRIGATÓRIO** o trailer `Co-Authored-By: Claude <noreply@anthropic.com>` via HEREDOC, sem exceção.
- Push só na branch da PR (`headRefName`), nunca em `main`.

### 9. Resposta no chat

Tabela curta: por thread `{path:line | veredito | sobreposição | 👍/👎}`, depois `{commit hash, range de push}`. Sinalize threads humanas deixadas abertas (`needs-discussion`) e quais foram marcadas como `duplicate`/`related-but-distinct` (com link da irmã). Não repita os bodies completos das réplicas.

## Convenções de texto (GitHub = publicação externa)

- PT-BR com acentuação correta sempre.
- **PROIBIDO travessão (—) e en-dash (–)** em qualquer texto postado no GitHub (réplicas, corpo de commit que vai pra PR). Usar vírgula, dois-pontos, parênteses, ponto-e-vírgula. (Regra global do usuário; vale para texto externo, não para este arquivo de doc interno.)
- Em `gh api -f body='...'`, usar **aspas simples** para o shell não interpretar crases/backticks. Conferir que o texto não contém apóstrofo (que quebraria a aspa simples); se contiver, reescrever sem apóstrofo ou usar HEREDOC via `--input`. Como backtick é literal dentro de aspas simples, dá pra usar markdown à vontade no body sem escape.

### Formatação markdown das réplicas (OBRIGATÓRIO)

O GitHub renderiza markdown nas réplicas. NÃO postar identificadores e código em plain text. Aplicar sempre:

- **Inline code (backticks)** em: identificadores (variáveis, funções, colunas, tabelas, enums, flags), expressões e trechos curtos de SQL/código, nomes de arquivo, valores literais e query params de exemplo. Ex.: `` `MIN(id)` ``, `` `cea2.event_id` ``, `` `eventId` ``, `` `?eventId=42` ``, `` `get-messages-with-event.school.integration.test.ts` ``.
- **Referências `arquivo:linha`** sempre em backticks, e quando ajudar o leitor, linkadas ao permalink do blob no SHA do head da PR:
  - Linha única: `` [`path:1467`](https://github.com/{owner}/{repo}/blob/{headSha}/{path}#L1467) ``
  - Range: `...#L1463-L1466`
  - Pegar o SHA: `gh pr view {n} --repo {owner}/{repo} --json headRefOid -q .headRefOid` (usar o SHA, não a branch, para o link não quebrar em pushes futuros).
- **Trechos de mais de uma linha** em bloco cercado com a linguagem: ```` ```sql ... ``` ````.
- Mesmo critério vale para as reações: o markdown é só do corpo textual; a reação 👍/👎 continua via `content=+1`/`-1`.

> Antifrase do dogfooding (PR #962): a réplica saiu correta no conteúdo mas em plain text (`linha 1467`, `MIN(id)`, `cea2.event_id`, nome do arquivo cru). O esperado é `` `MIN(id)` ``, `` [`messages.get-by-user.repository.ts:1467`](permalink) ``, etc.

## Notas finais

- Verificação vem antes de tudo: nunca aceitar um comentário do bot sem confirmar a alegação no código real.
- Roda UMA passada e termina. Não fica em loop esperando a próxima rodada do bot — se o bot comentar de novo, o usuário invoca o comando outra vez.
- Se `gh` não estiver autenticado, pedir `gh auth login` e abortar.
- Se o quality gate falhar (typecheck/lint/teste), **não** avançar para postar/pushar: reportar a falha e parar para o usuário decidir.
