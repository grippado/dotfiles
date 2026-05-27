---
description: "Captura sessão atual + sessões órfãs recentes em uma nota executiva no inbox do vault, pronta pra ser processada pelo /organize"
argument-hint: "[slug-opcional]"
---

Persiste o contexto da sessão atual (conversa + agents que rodaram) como nota no vault `.notes`, em `0-inbox/` com flag `pending_organize: true`. O `/organize` cuida do roteamento pro contexto certo depois.

## Quando usar

- Fim de uma sessão de trabalho não-trivial (bug-hunt, refactor, exploração, decisão)
- Antes de fechar o terminal/contexto e perder o trabalho
- Quando você rodou um plan e quer registrar não só o plan (`/plan-save` já cobre isso) mas a sessão inteira ao redor
- Quando vários agents rodaram e você sabe que tem decisão valiosa que não vai sobreviver à próxima `/clear`

## Diferença vs `/plan-save`

- `/plan-save` persiste um plan aprovado específico (artefato concreto)
- `/context-save` persiste a sessão inteira como contexto (conversa, decisões, arquivos tocados, agents invocados)
- Use os dois juntos quando aplicável

## Steps

1. **Sintetizar conversa atual** (main thread):
   - Inspecionar as mensagens em memória nesta sessão
   - Extrair: pedido original, ações tomadas, decisões com rationale, arquivos tocados (paths), agents invocados, pendências abertas, links externos mencionados (PRs, issues Linear, RFCs)
   - Identificar se algo é **brag-worthy** (impacto técnico/de negócio relevante, decisão arquitetural não-trivial, mentoria, incidente resolvido)

2. **Varrer sessões órfãs** (bash, paralelo aos passos seguintes):
   - `pwd` → derivar encoded path (substituir `/` por `-`, prefixar `-Users-...`)
   - Diretório candidato: `~/.claude/projects/<encoded-cwd>/`
   - Se existir: `find <dir> -name "*.jsonl" -mtime -2 -type f` (últimas 48h)
   - Pra cada `.jsonl` encontrado, extrair session UUID do nome do arquivo
   - Heurística de "já persistido?": `grep -rl "<session-uuid>" ~/.notes/ 2>/dev/null`
     - Sem match → sessão órfã, vira input adicional
     - Com match → já tem nota, ignorar
   - Limitar a 5 sessões órfãs (evitar explosão de contexto). Se houver mais, listar e perguntar quais incluir.

3. **Detectar contexto sugerido** (main thread):
   - `pwd` + `git remote get-url origin 2>/dev/null` (best-effort, ignorar erro)
   - Mapeamento (mesmo do `/plan-save`):
     - cwd sob `~/www/isaac/*` → `suggested_context: arco` (subcontexto: nome do repo se houver convenção, senão deixar vazio)
     - cwd sob `~/www/personal/<repo>` → `suggested_context: pessoal/<repo>` (flagbridge, vozes, opengateway, guia-cumuru, gripp-link)
     - cwd em outro lugar (incluindo `~`) → `suggested_context: ""` (deixar pro /organize decidir/perguntar)
   - Subtipo inferido pelo tipo de trabalho:
     - Decisão arquitetural / trade-off resolvido → `decision`
     - Bug investigado → `bug-hunt`
     - Refactor / cleanup → `refactor`
     - Exploração / pergunta aberta / spike → `exploration`
     - Default → `session`

4. **Derivar slug**:
   - Se `$ARGUMENTS` foi passado, usar ele (kebab-case, sem timestamp)
   - Senão, gerar do conteúdo: 3-6 palavras descritivas, kebab-case, PT-BR sem acentos no slug (mas com acentuação correta no título dentro da nota)

5. **Spawn `context-keeper`** via Task tool com este prompt:

   ```
   Crie nota em ~/.notes/0-inbox/YYYY-MM-DD-HHMM-<slug>.md (NÃO sobrescrever se existir — incrementar HHMM).

   Frontmatter (exatamente este shape):
     ---
     date: "YYYY-MM-DD"
     time: "HH:MM"
     type: context-save
     tags: [context-save, pending-organize]
     pending_organize: true
     suggested_context: "<arco | pessoal/flagbridge | pessoal/vozes | ... | vazio>"
     suggested_subtype: "<decision | bug-hunt | refactor | exploration | session>"
     session_sources: ["<paths absolutos dos .jsonl varridos>"]
     cwd: "<pwd>"
     branch: "<git branch ou vazio>"
     brag_worthy: <true | false>
     ---

   Seções (PT-BR com acentuação correta, tom executivo sem narração):

     # <Título descritivo do contexto>

     ## TL;DR
     3-5 linhas: o que rolou nesta sessão e por quê importa.

     ## O que foi feito
     Bullets com ações concretas. Foco em decisões, não em "rodei X comando".
     Quando mencionar arquivo, usar path completo.

     ## Decisões
     Bullets no formato: **<escolha>** — <rationale curto>. Inclua trade-offs aceitos.

     ## Arquivos tocados
     Lista com paths absolutos. Se nenhum, omitir seção.

     ## Pendências / próximos passos
     Checklist `- [ ]` com itens acionáveis.

     ## Brag-worthy?
     Se `brag_worthy: true`: 1-2 linhas justificando qual dimensão da rubrica L12 isso evidencia
     (visão estratégica / planejamento-execução / gestão de parceiros / gestão de times).
     Se `false`: omitir esta seção inteira.

     ## Links
     - PRs, issues Linear, RFCs externos, plans relacionados
     - Notas internas via wikilinks `[[...]]`

   Conteúdo deve ser SÍNTESE, não dump. Se a sessão tem 200 mensagens, a nota tem 30-50 linhas.
   NÃO copiar diffs de código nem outputs longos — referenciar paths e descrever a mudança.
   ```

6. **Reportar ao usuário**:
   - Path absoluto da nota criada
   - `suggested_context` e `suggested_subtype` que foram inscritos
   - Quantas sessões órfãs foram incluídas
   - Sugestão: "Rode `/organize` quando quiser processar o inbox e mover pro contexto certo"

## Rules

- **NÃO** criar `.md` no repo de trabalho — sempre em `~/.notes/0-inbox/`
- **NÃO** mover a nota pra `1-contexts/` aqui — isso é trabalho do `/organize`
- **NÃO** remover `pending_organize: true` aqui — flag é consumida pelo `/organize`
- Se já existe nota com mesmo timestamp+slug, incrementar HH:MM (não sobrescrever)
- Acentuação PT-BR obrigatória no conteúdo (slug e tags ficam ASCII)
- Se a sessão atual está vazia/trivial (ex: usuário acabou de abrir e só perguntou uma coisa simples), **avisar** e perguntar se ainda assim deve salvar — não criar nota por reflexo
