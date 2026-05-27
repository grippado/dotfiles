---
description: "Persiste o último plan aprovado em ~/.notes como fonte da verdade — rationale + resumo executivo + detalhes"
---

Persiste o plan mais recente de `~/.claude/plans/` como nota no vault `.notes`, no contexto correto.

## Steps

1. **Identificar plan mais recente** (main thread):
   - `ls -t ~/.claude/plans/*.md | head -1` para pegar o mais recente
   - Ler o conteúdo completo
   - Se o usuário passou um nome específico via argumento (`/plan-save <slug>`), usar `~/.claude/plans/<slug>.md` ao invés

2. **Detectar contexto** (main thread):
   - `pwd` e `git remote get-url origin 2>/dev/null` para inferir
   - Mapeamento:
     - cwd sob `~/www/isaac/*` → `~/.notes/1-contexts/arco/plans/`
     - cwd sob `~/www/personal/*` ou repos pessoais → `~/.notes/1-contexts/pessoal/plans/` (ou subcontexto se identificável: flagbridge, vozes, opengateway)
     - Indefinido → perguntar ao usuário qual contexto usar

3. **Spawn `context-keeper`** com este prompt:
   ```
   Crie nota em ~/.notes/1-contexts/<context>/plans/YYYY-MM-DD-<slug>.md.
   Slug derivado do título do plan (kebab-case, sem timestamps redundantes).
   Frontmatter:
     title: <título descritivo PT-BR>
     date: YYYY-MM-DD (hoje)
     context: <context>/<repo>
     status: proposed | in-progress | shipped
     plan_file: ~/.claude/plans/<original>.md
     pr: <URL se já existir, senão omitir>
     branch: <nome branch atual>
     worktree: <path se estiver em worktree>
     tags: [<derivados do conteúdo>]
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

4. **Reportar** path da nota criada ao usuário.

## Quando usar

- Após `ExitPlanMode` aprovado e antes de começar a execução pesada (registra a decisão)
- Após executar o plan completamente (atualiza `status: shipped` e adiciona PR/links)
- A qualquer momento que queira ecoar um plan antigo no vault

## Rules

- NÃO criar `.md` no repo de trabalho — sempre em `~/.notes/`
- Reusar nota existente se já houver uma com mesmo slug (`status` atualiza, conteúdo merge)
- Acentuação PT-BR obrigatória
