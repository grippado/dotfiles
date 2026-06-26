---
description: "Atualiza brag documents em ~/.notes/7-brag-doc/. Mês corrente = captura DIÁRIA (pasta YYYY-MM/ com 1 arquivo por dia); meses fechados = 1 arquivo mensal consolidado por dimensão. Orquestra coleta de evidências e delega síntese ao agent brag-writer."
argument-hint: "[--month YYYY-MM | --bootstrap --since YYYY-MM-DD] [--consolidate YYYY-MM] [--deep] [--dry-run]"
---

Coleta evidências de impacto no vault `.notes` (notas, decisões, plans, PRs, RFCs) e invoca o agent **`brag-writer`** pra atualizar os brag documents em `~/.notes/7-brag-doc/`.

> Este comando é **orquestração** (coleta + agrupamento por dia/mês + invocação). A escrita do brag, formato STAR, alinhamento com rubrica L12 e regras de tom moram no agent `brag-writer` (`~/cangaco/.ai/claude/agents/brag-writer.md`). Pra evoluir o estilo do brag, editar lá.

## Modelo mental

O brag tem **duas granularidades**, decididas pela posição do mês em relação a hoje:

- **Mês corrente → captura DIÁRIA.** Pasta `~/.notes/7-brag-doc/<YYYY-MM>/` com **1 arquivo por dia**: `<YYYY-MM-DD>-brag.md` (`type: brag-daily`). Todo brag é melhor capturado no dia — esse é o surface de captura do mês em andamento. Um arquivo de dia cobre só evidências cujo `date:` cai naquele dia.
- **Meses fechados → consolidado MENSAL.** `~/.notes/7-brag-doc/<YYYY-MM>-brag.md` (`type: brag-monthly`), organizado por dimensão da rubrica L12, com as seções de síntese (Por contexto, Mentoria, Gaps vs PDI). É gerado **consolidando os diários** quando o mês fecha (ou direto no backfill, varrendo evidências por data quando não há diários históricos).
- **Fechamento de mês:** ao rodar e detectar que o mês corrente virou (existe pasta `<mês-anterior>/` com diários e o `<mês-anterior>-brag.md` não existe ou está stale), consolidar os diários no mensal **e manter a pasta** ao lado (rastro auditável).
- **Backfill (`--bootstrap`):** meses passados vão direto pro formato mensal `YYYY-MM-brag.md`. Não cria pastas diárias retroativas — não há captura diária histórica pra esses meses.

### Critério de granularidade (determinístico)

```
HOJE=$(date +%Y-%m-%d); MES_CORRENTE=$(date +%Y-%m)
# Evidência com date == HOJE e mês == MES_CORRENTE → arquivo do dia em <MES_CORRENTE>/<date>-brag.md
# Evidência de dia anterior do mês corrente sem arquivo de dia → cria o arquivo daquele dia
# Evidência de mês < MES_CORRENTE → consolidado mensal <YYYY-MM>-brag.md
```

### Critério de inclusão

Nota vai pro brag do **dia** (mês corrente) ou do **mês** (meses fechados) indicado pelo `date:` do frontmatter dela. Não há overlap entre arquivos de dia. O consolidado mensal do mês corrente (se existir) é derivado dos diários, não fonte independente.

### Execução incremental (a regra que conserta o bug do skip)

- **Mês corrente:** a unidade incremental é o **DIA**, não o mês. Pra cada dia com evidência, criar/atualizar `<MES_CORRENTE>/<dia>-brag.md`. **NUNCA pular o dia porque a pasta do mês ou o consolidado mensal já existem.** O dia de hoje sempre é (re)processado se há evidência datada de hoje.
- **Meses fechados:** só reprocessa se `--month` ou `--consolidate` for passado, ou no fechamento automático. No fluxo diário, meses fechados não são tocados.

### Pools de evidência (inalterados)

- **Pool A — Explícito**: notas com marcador (`brag_worthy: true`, tag `brag`, `impacto: alto`, `status: shipped`). Entra por padrão.
- **Pool B — Implícito**: notas em pastas-chave sem marcador. Agent decide caso a caso.
- **Pool C — Deep sweep**: ativado por `--deep`. Inclui pastas normalmente excluídas (threads, meetings, interviews, journal, archive). Agent aplica critério estrito.

## Quando usar

- **Diariamente / antes de 1:1**: rode sem argumentos. Cria/atualiza o arquivo do dia de hoje na pasta do mês corrente; consolida automaticamente o mês anterior se ele acabou de fechar.
- **Regerar um único dia**: `--month` não serve pra isso; rode sem args (reprocessa hoje) ou edite o arquivo do dia à mão.
- **Consolidar um mês manualmente**: `--consolidate 2026-05` (lê a pasta `2026-05/` + pools e (re)gera `2026-05-brag.md`, mantendo a pasta).
- **Regerar um mês fechado do zero**: `--month 2026-04` (sobrescreve `2026-04-brag.md` varrendo evidências do mês).
- **Bootstrap (primeira vez / máquina nova / pré-AVD)**: `--bootstrap --since 2026-01-01 --deep`. Itera cada mês fechado de `since` até o mês anterior ao corrente, gerando o mensal. O mês corrente é tratado como diário.

## Argumentos

`$ARGUMENTS`

**Modo de execução** (mutuamente exclusivos):
- Sem args → modo incremental: arquivo do dia de hoje (mês corrente) + fechamento automático do mês anterior se aplicável.
- `--consolidate YYYY-MM` → (re)gera o consolidado mensal a partir da pasta de diários daquele mês + pools. Mantém a pasta.
- `--month YYYY-MM` → regerar um único mês fechado do zero (sobrescreve o arquivo mensal, varrendo evidências do mês).
- `--bootstrap --since YYYY-MM-DD` → itera mês a mês de `since` até o mês anterior ao corrente, gerando cada mensal do zero.

**Profundidade da coleta**:
- Sem `--deep` (default) → coleta Pool A + Pool B. Pastas excluídas: `threads/`, `meetings/`, `interviews/`, `0-inbox/`, `2-knowledge/`, `4-journal/`, `5-archive/`, `6-audits/`, `7-brag-doc/`.
- `--deep` → adiciona Pool C: varre TODAS as notas datadas no vault, incluindo pastas excluídas. Agent aplica critério estrito de inclusão.

**Modo dry-run**:
- `--dry-run` → escreve em `.preview.md` em vez do canônico, pra cada arquivo tocado (dia ou mês).

## Steps

1. **Resolver datas**: `HOJE=$(date +%Y-%m-%d)`, `MES_CORRENTE=$(date +%Y-%m)`, `MES_ANTERIOR` = mês civil imediatamente anterior.

2. **Coletar evidências** (Pools A/B/C):

   **Pool A — Evidências explícitas**:
   ```bash
   grep -rl "brag_worthy: true" ~/.notes/1-contexts/ 2>/dev/null
   grep -rl "## Brag-worthy?" ~/.notes/1-contexts/ 2>/dev/null
   grep -rl "tags:.*brag" ~/.notes/1-contexts/ 2>/dev/null
   grep -rl "impacto: alto" ~/.notes/1-contexts/ 2>/dev/null
   grep -rl "status: shipped" ~/.notes/1-contexts/ 2>/dev/null
   ```

   **Pool B — Implícito em pastas-chave**:
   ```bash
   find ~/.notes/1-contexts/arco/decisions/ \
        ~/.notes/1-contexts/arco/rfcs/ \
        ~/.notes/1-contexts/arco/pr-reviews/ \
        ~/.notes/1-contexts/arco/analyses/ \
        ~/.notes/1-contexts/arco/plans/ \
        ~/.notes/1-contexts/arco/tech-debt/ \
        ~/.notes/1-contexts/arco/strategies/ \
        ~/.notes/1-contexts/arco/self-improving/ \
        ~/.notes/1-contexts/pessoal/ \
        ~/.notes/1-contexts/flagbridge/ \
        ~/.notes/1-contexts/vozes/ \
        ~/.notes/1-contexts/opengateway/ \
        ~/.notes/1-contexts/guia-cumuru/ \
        ~/.notes/1-contexts/gripp-link/ \
        ~/.notes/1-contexts/dotfiles-ai/ \
     -name "*.md" -type f 2>/dev/null
   ```

   **Pool C — Deep sweep** (só se `--deep`):
   ```bash
   find ~/.notes/1-contexts/ ~/.notes/4-journal/ ~/.notes/5-archive/ \
     -name "*.md" -type f 2>/dev/null
   ```

   Após cada find/grep:
   - Deduplicar paths entre pools (A > B > C)
   - Excluir o próprio diretório `7-brag-doc/`

3. **Agrupar por data** (do `date:` do frontmatter de cada nota):
   - Pra cada path, extrair `date:` (`grep -m1 '^date:' "$path"`)
   - `dia` = `date` (YYYY-MM-DD); `mes` = primeiros 7 chars (YYYY-MM)
   - Notas sem `date` válido: pular e acumular numa lista de warnings pro report final
   - Particionar: evidências do `MES_CORRENTE` agrupadas por **dia**; evidências de meses fechados agrupadas por **mês** (só relevantes em `--month`/`--bootstrap`/`--consolidate`)

4. **Mês corrente — gerar/atualizar arquivos de dia** (modo incremental):

   Pra cada `dia` do mês corrente com evidência (priorizar `HOJE`, mas processar qualquer dia do mês corrente sem arquivo):

   a. Destino: `~/.notes/7-brag-doc/<MES_CORRENTE>/<dia>-brag.md` (ou `.preview.md` se `--dry-run`). Criar a pasta `<MES_CORRENTE>/` se não existir.

   b. Determinar evidências: todas as do `dia`. Se o arquivo do dia já existe, brag-writer faz dedupe interno do dia (manter/atualizar/adicionar). **Não pular por causa de existência da pasta/mensal.**

   c. Invocar `brag-writer` via Task tool:
   ```
   Gere/atualize brag DIÁRIO em ~/.notes/7-brag-doc/<MES_CORRENTE>/<dia>-brag.md
   (ou .preview.md se em --dry-run).

   granularity: daily
   day: <YYYY-MM-DD>
   month: <YYYY-MM>
   modo: incremental
   arquivo_existente: <path ou "nenhum">

   Pool A (explícito, entrar por padrão): <paths do dia>
   Pool B (implícito, avaliar): <paths do dia>
   Pool C (deep sweep, só se --deep, critério estrito): <paths do dia ou "n/a">

   Após gerar, atualizar ~/.notes/7-brag-doc/_index.md conforme suas regras
   (registrar/atualizar a entrada da pasta do mês corrente).
   ```

5. **Fechamento automático do mês anterior** (se aplicável):
   - Se existe pasta `~/.notes/7-brag-doc/<MES_ANTERIOR>/` com diários E (`<MES_ANTERIOR>-brag.md` não existe OU seu `last_updated` é anterior ao diário mais recente da pasta):
   - Invocar `brag-writer` em `granularity: monthly`, `modo: consolidate`, lendo os diários da pasta + pools do mês como fonte. **Manter a pasta** após consolidar.

6. **`--consolidate YYYY-MM`** (manual): igual ao passo 5 pra um mês específico, sem checar se fechou.

7. **`--month YYYY-MM` / `--bootstrap`** (meses fechados, regen do zero):

   a. Destino: `~/.notes/7-brag-doc/<YYYY-MM>-brag.md` (ou `.preview.md`)

   b. Processar TODAS as evidências do mês (regen, sobrescreve)

   c. Invocar `brag-writer`:
   ```
   Gere brag MENSAL em ~/.notes/7-brag-doc/<YYYY-MM>-brag.md (ou .preview.md).

   granularity: monthly
   month: <YYYY-MM>
   modo: <regen | bootstrap>
   fonte: pools (sem pasta de diários — mês histórico)

   Pool A: <paths do mês>
   Pool B: <paths do mês>
   Pool C: <paths do mês ou "n/a">

   update_index: <false em bootstrap; true caso contrário>
   ```

   d. **Bootstrap**: validar `--since` (obrigatório), calcular meses de `since` até `MES_ANTERIOR`, alertar se já existem arquivos mensais no range, gerar cada mês com `update_index: false`, e consolidar o `_index.md` uma única vez no fim.

8. **Reportar ao usuário**:
   - Arquivos de dia criados/atualizados (path absoluto) + `entries_count` de cada
   - Consolidações mensais geradas (path + entries_count)
   - Notas sem `date` válido (precisam de correção manual)
   - Gaps de rubrica L12 reportados pelo writer
   - Wikilinks quebrados (se houver)

## Rules

- **NÃO** escrever o brag inline neste comando — sempre delegar ao agent `brag-writer`
- **NUNCA pular o dia de hoje no mês corrente** porque a pasta do mês ou o consolidado mensal já existem — a unidade incremental do mês corrente é o DIA
- **NÃO** misturar evidência de dias/meses diferentes num mesmo arquivo
- **NÃO** criar pastas diárias retroativas pra meses fechados (backfill é mensal)
- No fechamento de mês, **consolidar E manter a pasta** de diários
- Em `--dry-run`, output vai pra `.preview.md` (não tocar canônico)
- Em `--bootstrap`, alertar antes se já existem arquivos mensais (vão ser sobrescritos)
- Se brag-writer der erro pra um dia/mês específico: reportar e continuar com os outros (não abortar o run inteiro)
