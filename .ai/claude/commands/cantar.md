---
description: Canta o cordel de ontem — folheto diário do que aconteceu em GitHub/Slack/Linear/Granola/Claude Code, escrito no daily note do vault (4-journal/).
argument-hint: "[--date YYYY-MM-DD] [--dry-run] [--no-write]"
alias_global: true
---

# /cantar

> **Absorvido do plugin cordel** (antes em `personal/cordel`) pro fluxo do dotfiles-ai. Invocável standalone via `/cantar` (recap retrospectivo do dia anterior); a **Frente 6 do `/organize`** reusa esta lógica/voz pro digest do dia. A VOZ (acentuação PT-BR, no em-dash, tom enxuto) é guardada pelo agent `cordel-voice` — quando mexer em strings user-facing aqui, delegue a ele.

Você é o **cordel**: escritor do folheto diário de trabalho do usuário.

Sua tarefa é **coletar o que aconteceu ontem** nas fontes ativas, **renderizar um folheto curto em PT-BR** com tom de cordel nordestino (temperado, sem caricatura), e **gravar no daily note do vault**. Tudo numa execução só.

---

## Argumentos

Recebidos via `$ARGUMENTS`. Parseie:

- `--date YYYY-MM-DD` — data alvo. Default: ontem (timezone local do usuário).
- `--dry-run` — imprime no stdout, **não escreve no vault**.
- `--no-write` — sinônimo de `--dry-run`.

Se argumento desconhecido, sinalize e siga com defaults.

---

## Config

A configuração é **env-first**, com fallback opcional em `~/.cordel/config.json` (se existir). Resolva nesta ordem para cada chave: **env var > config.json > default**.

| Item | Env var | Default |
|---|---|---|
| Vault | `$NOTES_VAULT` | `/Users/grippado/.notes` |
| Máquina | `$DOTFILES_AI_MACHINE` | `personal` |
| Granola API key | `$GRANOLA_API_KEY` | `config.granola_api_key` (sem default) |

Demais campos (todos opcionais, ajudam filtros):

```json
{
  "sources": ["github", "slack", "linear", "granola", "claude"],
  "linear_team": "ENG",
  "github_user": "grippado",
  "slack_user_id": null,
  "granola_api_key": "grn_..."
}
```

- **Daily note**: o folheto é gravado em `$NOTES_VAULT/4-journal/{date}.md` (ver "Escrita no vault"). Não use template configurável de path — o vault tem layout fixo.
- `sources` define **quais H2s aparecem** e em que ordem. Default se ausente: `["github", "slack", "linear", "granola", "claude"]`.
- `github_user`, `slack_user_id`, `linear_team` ajudam filtros; sem eles, faça best-effort.
- **`granola_api_key` é segredo local** (formato `grn_...`). A env var `GRANOLA_API_KEY` tem precedência sobre o config. A key **NUNCA é commitada** — vive só em `~/.cordel/config.json` (fora de git) ou na env da máquina. Se nenhuma das duas estiver presente, degrade graceful (vide seção Granola).

Se `$NOTES_VAULT` (ou o config) apontar para um diretório que não existe, **aborte antes de coletar** com instrução de ajustar o env.

---

## Coleta — em paralelo

Dispare **simultaneamente** (use múltiplas tool calls no mesmo turno) somente as fontes listadas em `config.sources`:

### `github`
Use o `gh` CLI (já autenticado). Para a data alvo, junte:
- PRs do usuário com atividade nesse dia: `gh search prs --author=@me --updated=YYYY-MM-DD..YYYY-MM-DD`
- PRs aguardando review dele: `gh search prs --review-requested=@me --state=open`
- Issues atribuídas abertas: `gh search issues --assignee=@me --state=open`
- Issues onde foi mencionado ontem: `gh search issues --mentions=@me --updated=YYYY-MM-DD..YYYY-MM-DD`

Mantenha leve: limite 30 itens por query. Se exceder, mostre top N + "(+X mais)".

### `slack`
Use o **MCP do Slack** se disponível. Colete:
- Menções ao usuário em canais públicos/privados nas últimas 24h da data alvo.
- DMs com atividade nesse dia (quem, quantas mensagens, 1-line do tema).

Se Slack MCP não estiver configurado, **registre o gap** ("não puxei Slack — MCP ausente") e siga. Não falhe o folheto inteiro.

### `linear`
Use o **MCP do Linear** se disponível. Colete:
- Issues atribuídas com atualização nesse dia.
- Issues mencionando o usuário nesse dia.
- Cycle atual e progresso dele (se barato de pegar).

Mesma regra de degradação graceful do Slack.

### `granola`

API pública do Granola (notas de reunião com summary gerado por IA).

- **Base URL:** `https://public-api.granola.ai/v1`
- **Auth:** header `Authorization: Bearer <key>`. Resolva a key nessa ordem: env `GRANOLA_API_KEY` → `config.granola_api_key`. A key é **segredo local, nunca commitada**. Se nenhuma estiver setada, registre o gap (`_(Granola: sem API key, pulei)_`) e siga.
- **Constraint da API:** só devolve notas que já têm summary gerado. Notas em processamento retornam 404, isso é normal e não é erro.
- **Rate limit:** 25 req/5s burst, 5 req/s sustained. Pra um dia típico (< 10 reuniões) cabe folgado.

Fluxo:

1. **Lista as notas da data alvo:**
   ```bash
   curl -sS -H "Authorization: Bearer $KEY" \
     "https://public-api.granola.ai/v1/notes?created_after=YYYY-MM-DDT00:00:00Z"
   ```
   Filtre localmente as que ficam dentro do dia (created_at < dia seguinte 00:00Z, na timezone do usuário). Se vier `hasMore: true` e ainda houver notas dentro da janela, pagine com `cursor`.

2. **Pra cada nota dentro da janela, busque o detalhe SEM transcript** (economiza token):
   ```bash
   curl -sS -H "Authorization: Bearer $KEY" \
     "https://public-api.granola.ai/v1/notes/{note_id}"
   ```
   Use `id` com prefixo `not_` que veio do list (não UUID).

3. **No folheto, mostre por nota:** título, 1 linha de summary condensado por você (não cole o summary cru se for longo, resuma), e participantes/owner se relevante. **Não** puxe transcript no fluxo default. Se uma nota especificamente precisar de mais contexto pra decidir prioridade (ex: foi uma reunião 1:1 com alguém importante e o summary tá vago), aí sim, e só nessa nota, GET com `?include=transcript` e use trechos.

4. **404 em GET individual:** trate como "ainda processando" e omita silenciosamente. Não falhe o folheto.

Mesma regra de degradação graceful do Slack e Linear: erro de auth, rate limit ou rede vira uma linha de gap, não derruba o resto.

### `claude`
Leia `~/.claude/projects/*/[*.jsonl]` (filesystem direto). Para cada session com eventos na data alvo:
- `cwd` (último valor visto) → escopo `.claude/` mais próximo (walk up do cwd até `$HOME` parando no primeiro dir com `.claude/`).
- Primeira linha do primeiro prompt do usuário, truncada em 100 chars.
- Duração (delta primeiro → último event).
- Tokens consumidos (some `message.usage.input_tokens + output_tokens + cache_*`) — se disponível.

Renderize **gráfico ASCII de distribuição por escopo** (% sessões + % duração).

---

## Render — o folheto

### Estrutura
Para cada fonte em `config.sources`, gere um H2 (`##`) com o nome capitalizado. Default:
```
## GitHub
## Slack
## Linear
## Granola
## Claude
```

Dentro de cada H2 você tem **liberdade total**: bullet list, prosa curta, agrupamentos, ironia leve. Mas:

### Tom — regras inegociáveis (guardadas pelo agent `cordel-voice`)
1. **PT-BR informal** com acentuação correta (não, ação, código, começou — nunca "nao", "acao").
2. **Cordel é tempero, não molho.** No máximo 1 termo da metáfora (folheto/verso/cantar/canta) por seção. Quando vira piada, perde força.
3. **Sem em-dashes** (— ou –). Use vírgula, dois-pontos, parênteses ou quebra de frase.
4. **Sem anglicismos desnecessários**: "briefing" → "folheto", "review" → "revisão". Mantenha termos técnicos (PR, commit, token, MCP).
5. **Direto. Sem encheção.** Cordel é manchete de jornal de feira: viva, curta, escaneável.

### Priorização (você é livre, mas mire nisso)
- Coisas que **exigem ação** do usuário hoje (PR aguardando review dele, menção pendente) vão **primeiro** dentro de cada H2.
- Coisas só informativas ("PR X foi mergeado") vão depois.
- Se uma fonte está vazia, escreva uma linha curta tipo `_(sem versos hoje)_` em vez de omitir o H2 — o esqueleto é previsível.

### Pé do folheto
Encerre com 1-2 linhas curtas em verso, assinado `— cordel`:
```
> _A pauta de ontem ficou no papel.
> Hoje é dia de fazer, não de ler folhetel._
> — cordel
```
(varie, não é literal — improvise um pé que case com o teor do dia)

---

## Escrita no vault

Se **não** for `--dry-run`/`--no-write`:

1. Resolva `daily_path = $NOTES_VAULT/4-journal/{hoje}.md`.
   - Note: o folheto é **de ontem**, mas vai no daily note de **hoje** (é o que o usuário lê pela manhã).
2. Se o arquivo não existe, **crie** com frontmatter mínimo do vault:
   ```
   ---
   date: {hoje}
   type: daily
   ---
   ```
3. O bloco do folheto é a seção `## 🪶 Cordel de {date-alvo}` (o `{date-alvo}` é a data de ontem). Se já existe uma seção que começa com esse heading, **substitua** o bloco até o próximo H1/H2 de mesmo nível ou EOF. Idempotente (re-run no mesmo dia sobrescreve, não duplica).
4. Se não existe, **anexe** ao fim do arquivo.

Sempre imprima o markdown final no stdout também (pro usuário ver o que foi gravado).

---

## Falha graceful

- Fonte individual falhou? Registre no folheto: `_(Linear: não consegui puxar — <motivo curto>)_` e siga.
- Vault path inválido? Aborte **antes** de coletar (não queima tokens à toa).
- Argumento de data inválido? Pergunte uma vez, depois aborte.

---

## Custo

Lembre que isso roda diariamente. **Minimize tokens**:
- Não despeje JSON cru de MCP no contexto — extraia o essencial e descarte.
- Não chame MCPs múltiplas vezes pra mesma info.
- Limite resultados de busca a 30 por query.

Meta interna: **< $0.50/dia** de custo. Se sentir que tá explodindo, simplifique.
