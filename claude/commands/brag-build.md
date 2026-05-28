---
description: "Atualiza brag documents mensais em ~/.notes/7-brag-doc/ (1 arquivo por mês civil). Orquestra coleta de evidências e delega síntese ao agent brag-writer."
argument-hint: "[--month YYYY-MM | --bootstrap --since YYYY-MM-DD] [--deep] [--dry-run]"
---

Coleta evidências de impacto no vault `.notes` (notas, decisões, plans, PRs, RFCs), agrupa por mês civil (baseado no `date:` de cada nota) e invoca o agent **`brag-writer`** pra atualizar os arquivos mensais em `~/.notes/7-brag-doc/<YYYY-MM>-brag.md`.

> Este comando é **orquestração** (coleta + agrupamento por mês + invocação). A escrita do brag, formato STAR, alinhamento com rubrica L12 e regras de tom moram no agent `brag-writer` (`~/.dotfiles-ai/claude/agents/brag-writer.md`). Pra evoluir o estilo do brag, editar lá.

## Modelo mental

- **1 arquivo por mês civil**: `~/.notes/7-brag-doc/YYYY-MM-brag.md`. Cada arquivo é auto-contido.
- **Critério de inclusão**: nota vai pro brag do mês indicado pelo `date:` do frontmatter dela. Não há overlap entre arquivos.
- **Execução incremental**: cada run lê `last_updated` dos arquivos mensais existentes e processa só notas com `date >= last_updated` daquele mês. Múltiplos meses podem ser atualizados em um único run (ex: rodar dia 03/06 com pendência de 30/05 atualiza tanto `2026-05-brag` quanto `2026-06-brag`).
- **Pools de evidência** (inalterados):
  - **Pool A — Explícito**: notas com marcador (`brag_worthy: true`, tag `brag`, `impacto: alto`, `status: shipped`). Entra por padrão.
  - **Pool B — Implícito**: notas em pastas-chave sem marcador. Agent decide caso a caso.
  - **Pool C — Deep sweep**: ativado por `--deep`. Inclui pastas normalmente excluídas (threads, meetings, interviews, journal, archive). Agent aplica critério estrito.

## Quando usar

- **Diariamente / antes de 1:1**: rode sem argumentos. Atualiza só o(s) mês(es) com evidência nova.
- **Regerar um mês específico**: `--month 2026-04` (apaga conteúdo atual desse mês e regenera do zero).
- **Bootstrap (primeira vez ou máquina nova)**: `--bootstrap --since 2026-01-01 --deep`. Itera cada mês de `since` até hoje, regerando.
- **Antes de AVD / calibração**: rode `--bootstrap --since <início-do-semestre> --deep` pra ter cada mês completo e em sync.

## Argumentos

`$ARGUMENTS`

**Modo de execução** (mutuamente exclusivos):
- Sem args → modo incremental: atualiza arquivos dos meses com evidência nova desde o último `last_updated` de cada.
- `--month YYYY-MM` → regerar um único mês do zero (apaga conteúdo do arquivo existente).
- `--bootstrap --since YYYY-MM-DD` → itera mês a mês de `since` até hoje, regerando cada um do zero.

**Profundidade da coleta**:
- Sem `--deep` (default) → coleta Pool A + Pool B. Pastas excluídas: `threads/`, `meetings/`, `interviews/`, `0-inbox/`, `2-knowledge/`, `4-journal/`, `5-archive/`, `6-audits/`, `7-brag-doc/`.
- `--deep` → adiciona Pool C: varre TODAS as notas datadas no vault, incluindo pastas excluídas. Agent aplica critério estrito de inclusão.

**Modo dry-run**:
- `--dry-run` → escreve em `~/.notes/7-brag-doc/<YYYY-MM>-brag.preview.md` em vez do canônico, pra cada mês tocado.

## Steps

1. **Coletar evidências** (Pools A/B/C):

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

2. **Agrupar por mês** (do `date:` do frontmatter de cada nota):
   - Pra cada path, extrair `date:` do frontmatter (`grep -m1 '^date:' "$path"`)
   - Bucket = primeiros 7 chars do `date` (`YYYY-MM`)
   - Notas sem `date` válido: pular e acumular numa lista de warnings pro report final
   - Se `--month YYYY-MM` foi passado: filtrar pra manter só esse mês

3. **Para cada mês com evidência** (no modo incremental ou bootstrap):

   a. Path destino: `~/.notes/7-brag-doc/<YYYY-MM>-brag.md` (ou `.preview.md` se `--dry-run`)

   b. Determinar evidências a processar:
   - Modo **incremental** (default, sem `--month`/`--bootstrap`): se arquivo existe, ler `last_updated` do frontmatter, filtrar evidências do mês pra `note.date > last_updated`. Se 0 evidências novas, **pular esse mês** (no-op).
   - Modo **regen** (`--month`) ou **bootstrap**: processar TODAS as evidências do mês (regen do zero, sobrescreve arquivo).

   c. Invocar `brag-writer` via Task tool:
   ```
   Gere/atualize brag mensal em ~/.notes/7-brag-doc/<YYYY-MM>-brag.md
   (ou .preview.md se em --dry-run).

   month: <YYYY-MM>
   modo: <incremental | regen | bootstrap>
   arquivo_existente: <path ou "nenhum">

   Pool A (explícito, entrar por padrão):
   <lista de paths do mês>

   Pool B (implícito, pasta-chave sem marcador, avaliar):
   <lista de paths do mês>

   Pool C (deep sweep, só se --deep, critério estrito):
   <lista de paths do mês ou "n/a">

   Após gerar, atualizar ~/.notes/7-brag-doc/_index.md conforme suas regras
   (apenas se este NÃO for um run em --bootstrap; em bootstrap o orchestrator
   consolida o _index ao final).
   ```

4. **Bootstrap (modo especial)**:
   - Validar `--since YYYY-MM-DD` (obrigatório). Sem, abortar.
   - Calcular lista de meses entre `--since` e hoje (formato `YYYY-MM`)
   - Alertar se já existem arquivos mensais nesse range (vão ser sobrescritos)
   - Pra cada mês: chamar passo 3 com `modo=bootstrap` e sinalizar pro brag-writer **não** atualizar `_index.md`
   - Ao final: atualizar `_index.md` uma única vez com a lista completa de meses gerados

5. **Reportar ao usuário**:
   - Lista de meses tocados + path absoluto de cada arquivo
   - `entries_count` final por mês
   - Notas sem `date` válido encontradas (precisam de correção manual)
   - Gaps de rubrica L12 reportados pelo writer
   - Wikilinks quebrados (se houver)

## Rules

- **NÃO** escrever o brag inline neste comando — sempre delegar ao agent `brag-writer`
- **NÃO** misturar evidência de meses diferentes num mesmo arquivo
- **NÃO** modificar arquivos de meses sem evidência nova no modo incremental
- Em `--dry-run`, output vai pra `<YYYY-MM>-brag.preview.md` (não tocar canônico)
- Em `--bootstrap`, alertar antes se já existem arquivos mensais (vão ser sobrescritos)
- Se brag-writer der erro pra um mês específico: reportar e continuar com os outros meses (não abortar o run inteiro)
