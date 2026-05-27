---
description: "Monta/atualiza snapshot diário do brag document em ~/.notes/7-brag-doc/. Orquestra coleta de evidências e delega síntese ao agent brag-writer."
argument-hint: "[--since YYYY-MM-DD | --full | --bootstrap-monthly] [--deep] [--dry-run]"
---

Coleta evidências de impacto no vault `.notes` (notas, decisões, plans, PRs, RFCs) e invoca o agent **`brag-writer`** pra sintetizar/atualizar o brag document do dia em `~/.notes/7-brag-doc/YYYY-MM-DD-brag.md`.

> Este comando é **orquestração** (coleta + invocação). A escrita do brag, formato STAR, alinhamento com rubrica L12 e regras de tom moram no agent `brag-writer` (`~/.dotfiles-ai/claude/agents/brag-writer.md`). Pra evoluir o estilo do brag, editar lá.

## Modelo mental

- **Snapshot único por execução** (default): cada run gera 1 arquivo (o do dia). `--since DATE` define a **janela de evidências** que entram no snapshot, NÃO faz backfill por dia.
- **Cadência diária = versionamento via git**: o snapshot de cada dia vira commit no vault. `git diff` entre snapshots mostra evolução.
- **Modelo incremental por default**: sem args, `since` vira a data do último snapshot existente. Cada run cobre só o delta novo + carrega contexto do snapshot anterior pra dedupe.
- **Pools de evidência**:
  - **Pool A — Explícito**: notas com marcador (`brag_worthy: true`, tag `brag`, `impacto: alto`, `status: shipped`). Entra por padrão.
  - **Pool B — Implícito**: notas em pastas-chave sem marcador. Agent decide caso a caso.
  - **Pool C — Deep sweep**: ativado por `--deep`. Inclui pastas normalmente excluídas (threads, meetings, interviews, journal, archive). Agent aplica critério estrito.

## Quando usar

- **Antes de 1:1 com líder**: rode sem argumentos pra ter snapshot atualizado do dia
- **Antes de AVD / calibração de promoção**: rode com `--full --deep` pra varrer tudo
- **Continuamente**: deixe o `/organize` Frente 5 rodar automaticamente (sem --deep por default)
- **Primeira vez configurando o brag**: `--bootstrap-monthly --since 2026-01-01 --deep`

## Argumentos

`$ARGUMENTS`

**Janela de tempo** (mutuamente exclusivos):
- Sem args → janela = desde o último snapshot em `7-brag-doc/` (ou 6 meses atrás se não houver). 1 snapshot único de hoje.
- `--since YYYY-MM-DD` → força janela maior. 1 snapshot único (o de hoje) cobrindo desde DATE.
- `--full` → varre desde o início do PDI vigente (consultar `pdi_link` do último brag, ou `2026-01-01`).
- `--bootstrap-monthly` → modo bootstrap: gera 1 snapshot **por mês** entre `--since` (obrigatório) e hoje. Use **uma única vez**.

**Profundidade da coleta**:
- Sem `--deep` (default) → coleta Pool A + Pool B. Pastas excluídas: `threads/`, `meetings/`, `interviews/`, `0-inbox/`, `2-knowledge/`, `4-journal/`, `5-archive/`, `6-audits/`.
- `--deep` → adiciona Pool C: varre TODAS as notas datadas no vault, incluindo pastas excluídas. Agent aplica critério estrito de inclusão. Use pré-AVD ou em primeiro bootstrap.

**Modo**:
- `--dry-run` → gera em `~/.notes/7-brag-doc/YYYY-MM-DD-brag.preview.md` em vez do canônico. Usado pelo `/organize` em dry-run.

## Steps

1. **Localizar último brag**:
   ```bash
   ls -t ~/.notes/7-brag-doc/*-brag.md 2>/dev/null | grep -v "_index" | grep -v "preview" | head -1
   ```
   - Existir e sem `--full`/`--since`/`--bootstrap-monthly`: extrair `date` do frontmatter como `since` default
   - Não existir: `since` = 6 meses atrás

2. **Coletar evidências** (bash):

   **Pool A — Evidências explícitas**:
   ```bash
   # brag_worthy ou seção Brag-worthy
   grep -rl "brag_worthy: true" ~/.notes/1-contexts/ 2>/dev/null
   grep -rl "## Brag-worthy?" ~/.notes/1-contexts/ 2>/dev/null
   # tag brag
   grep -rl "tags:.*brag" ~/.notes/1-contexts/ 2>/dev/null
   # decisões alto impacto
   grep -rl "impacto: alto" ~/.notes/1-contexts/ 2>/dev/null
   # plans shipped
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
   # Inclui threads/, meetings/, interviews/, journal/, archive/ que B exclui
   ```

   Após cada find/grep:
   - Deduplicar paths entre pools (Pool A tem precedência > B > C)
   - Filtrar pela janela: pra cada arquivo, ler frontmatter `date:` e manter só se `date >= since`
   - Excluir o próprio diretório `7-brag-doc/` pra não auto-referenciar

3. **Se `--bootstrap-monthly`**: ramificação especial
   - Validar `--since YYYY-MM-DD` (obrigatório). Sem, abortar.
   - Calcular fronteiras mensais entre `--since` e hoje (lista de `YYYY-MM-01`)
   - Pra **cada** fronteira `M`: invocar `brag-writer` (passo 4) com:
     - `since` = `M-1` (ou `--since` original se for a primeira)
     - `today` = `M`
     - Destino: `~/.notes/7-brag-doc/<M>-brag.md`
     - Evidências filtradas pra janela `[since, M]`
     - Sinalizar pra **não** atualizar `_index.md` no passo individual
   - Após todas as invocações: atualizar `_index.md` **uma vez** com todos os snapshots criados (batch)
   - Reportar N snapshots criados + período de cada
   - Pular passo 4 normal

4. **Spawn `brag-writer`** via Task tool com este input (curto — o sistêmico mora no agent):

   ```
   Gere/atualize snapshot do brag em ~/.notes/7-brag-doc/<YYYY-MM-DD>-brag.md
   (ou .preview.md se em --dry-run).

   janela: <since> → <today>
   modo: <standard | deep | bootstrap-monthly>
   snapshot_anterior: <path ou "nenhum">

   Pool A (explícito, entrar por padrão):
   <lista de paths>

   Pool B (implícito, pasta-chave sem marcador, avaliar):
   <lista de paths>

   Pool C (deep sweep, só se modo=deep, critério estrito):
   <lista de paths ou "n/a">

   Após gerar, atualizar ~/.notes/7-brag-doc/_index.md conforme suas regras.
   Reportar: path criado, entries_count, diff vs anterior, gaps detectados, wikilinks quebrados.
   ```

5. **Reportar ao usuário** (consolidar output do agent):
   - Path absoluto do brag novo (ou lista, em bootstrap)
   - `entries_count`
   - Diff resumido vs snapshot anterior
   - Gaps de rubrica L12 (dimensões fracas) — input pro próximo ciclo de PDI
   - Wikilinks quebrados (se houver)

## Rules

- **NÃO** escrever o brag inline neste comando — sempre delegar ao agent `brag-writer`
- **NÃO** deletar arquivos de outros dias (snapshots são append-only por design)
- **NÃO** rodar `--bootstrap-monthly` mais de uma vez sem aviso explícito do usuário (sobrescreveria snapshots históricos)
- Em `--dry-run`, o output vai pra `.preview.md` (não tocar canônico). Brag-writer aceita esse flag via prompt.
- Se brag-writer der erro: reportar mas não falhar runs maiores (ex: `/organize` Frente 5 continua)
