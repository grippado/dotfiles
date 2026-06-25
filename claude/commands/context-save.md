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

3. **Detectar contexto + tipo canônico** (main thread):
   - `pwd` + `git remote get-url origin 2>/dev/null` (best-effort, ignorar erro)
   - **Contexto** (melhor chute — o produtor commita o que sabe; `/organize` valida/move depois via `pending_organize`):
     - cwd sob `~/www/isaac/*` → `context: arco`
     - cwd sob `~/www/personal/<repo>` → `context: pessoal/<repo>` (flagbridge, vozes, opengateway, guia-cumuru, gripp-link)
     - cwd em outro lugar (incluindo `~`) → `context: ""` (vazio; deixar pro /organize decidir/perguntar)
   - **`type` canônico** (do enum do schema v2, eixo por tipo) inferido pelo tipo de trabalho. O `type` substitui o antigo `suggested_subtype` — o roteamento agora é por tipo:
     - Decisão arquitetural / trade-off resolvido → `type: decision` (`default_state: done`)
     - Bug investigado → `type: analysis` (`default_state: open`)
     - Exploração / pergunta aberta / spike → `type: analysis` (`default_state: open`)
     - Refactor / cleanup / sessão de trabalho → `type: thread` (`default_state: open`)
     - Default → `type: thread` (`default_state: open`)
   - **`execution_status`** = o `default_state` do `type` escolhido (regra acima, vinda de `lifecycle[type].default_state` no schema). NÃO inferir estado da execução além do default — o produtor é semi-burro, o estado fino é do scouter/organize.
   - **NÃO inferir `issue_id`/`related_issues`** — identidade é responsabilidade do `canonical-taxonomy-scouter` na Frente 1.0 do `/organize`. O produtor não toca isso.

4. **Derivar slug**:
   - Se `$ARGUMENTS` foi passado, usar ele (kebab-case, sem timestamp)
   - Senão, gerar do conteúdo: 3-6 palavras descritivas, kebab-case, PT-BR sem acentos no slug (mas com acentuação correta no título dentro da nota)

5. **Spawn `context-keeper`** via Task tool com este prompt:

   ```
   Crie nota em ~/.notes/0-inbox/YYYY-MM-DD-HHMM-<slug>.md (NÃO sobrescrever se existir — incrementar HHMM).

   Frontmatter (exatamente este shape — esqueleto v2, schema-aware):
     ---
     date: "YYYY-MM-DD"
     time: "HH:MM"
     type: "<decision | analysis | thread — o canônico decidido no passo 3>"
     context: "<arco | pessoal/flagbridge | pessoal/vozes | ... | vazio>"
     execution_status: "<default_state do type: done p/ decision, open p/ analysis/thread>"
     pending_organize: true
     tags: [<2-5 tags de conteúdo, ASCII, sem acento; SEM 'context-save'/'pending-organize'>]
     parent: "[[_index]]"
     brag_worthy: <true | false>
     provenance:
       machine: "<$DOTFILES_AI_MACHINE ou 'personal'>"
       hostname: "<hostname -s>"
       cwd: "<pwd>"
       branch: "<git branch atual ou vazio>"
       invocation: "/context-save <args>"
       generator: "context-save"
       captured_at: "<ISO8601 com timezone, ex: 2026-06-19T14:30:00-03:00>"
       session_sources: ["<paths absolutos dos .jsonl varridos>"]
     ---

   Regras do frontmatter (semi-burro):
   - `type` é o canônico do enum (NÃO `context-save` nem `session`); `context` é o melhor chute (pode ser vazio).
   - `execution_status` = `default_state` do `type` (não inferir além disso).
   - `pending_organize: true` SEMPRE — é o sinal pro /organize rotear e pro scouter resolver identidade.
   - `provenance` é o bloco de metadado de máquina (porque é doc gerado): machine/hostname/cwd/branch/invocation/generator/captured_at/session_sources.
   - **NÃO** emitir `issue_id`/`related_issues`/`issue_validated` — identidade é do scouter (Frente 1.0 do /organize).

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

6. **Push do vault pro origin** (SEMPRE, logo após a nota ser criada):

   Sincroniza o `~/.notes` inteiro com o origin pra que o `/organize` possa rodar em outra máquina (ex.: pessoal puxa o inbox que a arco produziu).

   ```bash
   cd ~/.notes
   git add -A
   # commitar só se houver algo staged:
   git commit -m "$(cat <<'EOF'
   chore(vault): sync inbox e pendências via context-save

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   git push
   ```

   Regras do push:
   - Commitar **tudo** que estiver pendente no vault (a nota recém-criada + qualquer coisa não-commitada de sessões anteriores) — o objetivo é deixar o origin completo, não só a nota desta sessão.
   - Se o working tree já estiver limpo E local em sync com `origin/main`, pular silenciosamente.
   - Mensagem: Conventional Commits + trailer `Co-Authored-By: Claude <noreply@anthropic.com>` via HEREDOC. Sem em-dashes.
   - **Best-effort**: se o push falhar (sem rede, conflito, sem auth), avisar o usuário e NÃO travar — a nota já está salva localmente. Reportar o erro pra resolução manual.

7. **Reportar ao usuário**:
   - Path absoluto da nota criada
   - `type` canônico, `context` (chute) e `execution_status` que foram inscritos
   - Quantas sessões órfãs foram incluídas
   - Resultado do push pro origin (commit SHA + branch, ou "nada pendente", ou o erro se falhou)
   - Sugestão: "Rode `/organize` quando quiser processar o inbox (rotear pro contexto + scouter resolver `issue_id`)"

## Rules

- **NÃO** criar `.md` no repo de trabalho — sempre em `~/.notes/0-inbox/`
- **NÃO** mover a nota pra `1-contexts/` aqui — isso é trabalho do `/organize`
- **NÃO** rotear fino nem resolver identidade aqui: o produtor é **semi-burro** — emite o esqueleto v2 (type canônico + context-chute + execution_status default + provenance + pending_organize) e deixa `issue_id`/roteamento pro scouter/organize
- **NÃO** remover `pending_organize: true` aqui — flag é consumida pelo `/organize`
- Se já existe nota com mesmo timestamp+slug, incrementar HH:MM (não sobrescrever)
- Acentuação PT-BR obrigatória no conteúdo (slug e tags ficam ASCII)
- Se a sessão atual está vazia/trivial (ex: usuário acabou de abrir e só perguntou uma coisa simples), **avisar** e perguntar se ainda assim deve salvar — não criar nota por reflexo
- **SEMPRE** fazer o push do `~/.notes` pro origin ao final (passo 6), best-effort. É o que permite rodar `/organize` em outra máquina. Nunca pular o push por iniciativa própria.
