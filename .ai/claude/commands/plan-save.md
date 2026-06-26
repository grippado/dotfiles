---
description: "Persiste o último plan aprovado em ~/.notes como fonte da verdade — rationale + resumo executivo + detalhes"
---

Persiste o plan mais recente de `~/.claude/plans/` como nota no vault `.notes`, no contexto correto.

## Steps

1. **Identificar plan mais recente** (main thread):
   - `ls -t ~/.claude/plans/*.md | head -1` para pegar o mais recente
   - Ler o conteúdo completo
   - Se o usuário passou um nome específico via argumento (`/plan-save <slug>`), usar `~/.claude/plans/<slug>.md` ao invés

2. **Detectar contexto (melhor chute)** (main thread):
   - `pwd` e `git remote get-url origin 2>/dev/null` para inferir
   - O produtor é **semi-burro**: NÃO roteia pra pasta de contexto. Computa só o **valor** de `context` (chute) e escreve no `0-inbox/`; o `/organize` valida/move depois via `pending_organize`.
     - cwd sob `~/www/isaac/*` → `context: arco`
     - cwd sob `~/www/personal/<repo>` → `context: pessoal/<repo>` (flagbridge, vozes, opengateway, guia-cumuru, gripp-link)
     - cwd em outro lugar / indefinido → `context: ""` (vazio; deixar pro /organize decidir)
   - **`execution_status`** derivado do `status` conhecido do plan (`type: plan` tem `default_state: open`):
     - `proposed` (ou ausente) → `open`
     - `in-progress` → `active`
     - `shipped` → `done`
   - **NÃO inferir `issue_id`/`related_issues`** — identidade é do `canonical-taxonomy-scouter` (Frente 1.0 do /organize). Links como `pr`/`rfc` são ponteiros, não identidade canônica, e podem ficar.

3. **Spawn `context-keeper`** com este prompt:
   ```
   Crie nota em ~/.notes/0-inbox/YYYY-MM-DD-HHMM-<slug>.md
   (NÃO sobrescrever se existir — incrementar HHMM).
   Slug derivado do título do plan (kebab-case, sem acento, sem timestamps redundantes).

   Frontmatter (esqueleto v2, schema-aware):
     ---
     date: "YYYY-MM-DD"
     time: "HH:MM"
     type: plan
     context: "<arco | pessoal/<repo> | vazio>"
     execution_status: "<open | active | done — derivado do status no passo 2>"
     pending_organize: true
     tags: [<2-5 tags de conteúdo, ASCII, sem acento>]
     parent: "[[_index]]"
     pr: "<URL se já existir, senão OMITIR a linha>"
     rfc: "<URL se houver, senão OMITIR>"
     provenance:
       machine: "<$DOTFILES_AI_MACHINE ou 'personal'>"
       hostname: "<hostname -s>"
       cwd: "<pwd>"
       branch: "<git branch atual ou vazio>"
       worktree: "<path se em worktree, senão OMITIR>"
       plan_file: "~/.claude/plans/<original>.md"
       invocation: "/plan-save <args>"
       generator: "plan-save"
       captured_at: "<ISO8601 com timezone>"
     ---

   Regras do frontmatter (semi-burro):
   - type: plan (canônico); execution_status derivado do status; pending_organize: true SEMPRE.
   - provenance é o bloco de metadado de máquina, e guarda o ponteiro plan_file de origem.
   - NÃO emitir issue_id/related_issues/issue_validated (identidade é do scouter).

   Seções:
     # <Título>
     ## TL;DR (3-5 linhas: o que e por quê)
     ## Por que (motivação, dor, contexto)
     ## Abordagem (decisão central)
     ## Mudanças (resumo dos arquivos/áreas afetadas)
     ## Onde (links: PR, RFC, Linear, worktree, plan_file)
     ## Próximos passos (checklist)
     ## Links relacionados (wikilinks)
   PT-BR com acentuação correta. Tom direto, sem cerimônia.
   Conteúdo deve ser executivo — não copiar o plan inteiro, sintetizar o rationale e os trade-offs.
   ```

4. **Reportar** ao usuário: path da nota criada, `type`, `context` (chute) e `execution_status` inscritos.

## Quando usar

- Após `ExitPlanMode` aprovado e antes de começar a execução pesada (registra a decisão como `execution_status: open`)
- Após executar o plan completamente (nova captura com `execution_status: done` + PR/links)
- A qualquer momento que queira ecoar um plan antigo no vault

## Rules

- NÃO criar `.md` no repo de trabalho — sempre em `~/.notes/0-inbox/`
- **NÃO** rotear pra `1-contexts/<ctx>/plans/` aqui — o produtor é semi-burro: escreve o esqueleto v2 no inbox com `pending_organize: true` e deixa o roteamento pro `/organize`
- **NÃO** resolver identidade (`issue_id`) — isso é do scouter na Frente 1.0 do /organize
- **Sem update-in-place automático:** cada `/plan-save` grava uma captura nova no inbox (incrementa HHMM em colisão same-day). Atualização de `execution_status` (ex.: `open` → `done` ao fechar) vira uma nova captura; a reconciliação/dedupe da nota já organizada é responsabilidade do `/organize`, não deste produtor. Pra editar a nota já organizada em `1-contexts/`, fazer à mão.
- Acentuação PT-BR obrigatória (slug e tags ficam ASCII)
