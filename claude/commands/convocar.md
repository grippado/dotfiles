---
description: "Convoca um mutirão: lê tasks (issues.md SDD, lista direta, arquivo ou Linear via MCP), delega ao agent mutirao-planner pra computar levas com segurança, e grava a pauta revisável em ~/.notes/0-inbox/."
argument-hint: "[caminho do issues.md | --tasks \"...\" | --linear <ids> ] [--repo-map repo=path,...]"
alias_global: true
---

# /convocar — preparar a pauta de um mutirão

Transforma um conjunto de tasks numa **pauta** pronta pro `mutirao run`: mãos normalizadas, agrupadas em `levas` paralelizáveis com segurança (sem colisão de arquivo entre irmãs), com triagem AFK/HITL e prompts envelopados. A pauta nasce como **proposta revisável** — você lê e ajusta antes de executar.

> A análise (grafo, conflito, levas, envelope) mora no agent `mutirao-planner`. Este comando é orquestração: detectar a fonte, resolver paths de repo, invocar o planner e persistir a pauta.

## Argumentos

`$ARGUMENTS`

Fontes de input (detectar qual foi passada):
- **Arquivo `issues.md`** (caminho): fonte primária SDD. Parser direto do formato `technical-refining`.
- `--tasks "<texto>"`: lista de tasks com descrição direta no contexto.
- `--file <path>`: outro arquivo de tasks (markdown livre).
- `--linear <ids|url>`: **opt-in**. Só usar se o MCP do Linear estiver conectado; senão, avisar e pedir uma das outras fontes.
- `--repo-map repo=path,...`: mapa explícito repo→path local. Se ausente, inferir de `~/www/{personal,isaac}/<repo>` e confirmar.

## Fluxo

1. **Detectar a fonte** a partir de `$ARGUMENTS`. Se nenhuma fonte clara, pedir ao usuário (issues.md é o caminho recomendado).

2. **Resolver o mapa repo→path**:
   - Se `--repo-map` foi passado, usar.
   - Senão, para cada repo referenciado, procurar em `~/www/personal/<repo>` e `~/www/isaac/<repo>`. Listar o que encontrou e **confirmar com o usuário** antes de seguir. Se algum repo não resolver, parar e perguntar.

3. **Footprint (junta scout↔planner)** — só para fontes SEM footprint declarado (lista, `--file`, Linear; o `issues.md` SDD já traz "Arquivos a criar/alterar"):
   - Fan-out de **`Explore`** (Task tool, 1 por task, em paralelo): cada um inspeciona o repo da task e infere os arquivos/módulos prováveis que ela toca. Output por task: lista de `files` (inferida) + breve justificativa.
   - Esse é o ponto de extração futura: hoje é `Explore`; se a inferência sair ruidosa num run real, vira um `mutirao-scout` dedicado sem mexer no resto.

4. **Invocar o agent `mutirao-planner`** (Task tool) passando: a fonte (conteúdo ou caminho), o tipo de fonte, o mapa repo→path resolvido, e **os footprints do passo 3** (quando houver). O planner CONSOLIDA: grafo de dependência, detecção de conflito de arquivo entre irmãs, levas, triagem AFK/HITL, envelope de prompt. Devolve a pauta (bloco json + rationale).

5. **Montar o arquivo da pauta** e gravar em:
   `~/.notes/0-inbox/YYYY-MM-DD-HHMM-mutirao-<slug>.md`
   Frontmatter (pra o /organize Frente 1.0 adotar depois):
   ```yaml
   ---
   title: "Pauta — <slug>"
   date: "YYYY-MM-DD"
   time: "HH:MM"
   type: mutirao-run
   status: planned
   pending_organize: true
   suggested_context: <inferir do repo/domínio; ex. arco se isaac/*>
   suggested_subtype: mutirao-run
   repos: [<lista>]
   source: <issues.md path | tasks | linear>
   tags: [mutirao, pauta, orchestration, pending-organize]
   ---
   ```
   Corpo: o rationale humano do planner (tabela leva×mão + "Decisões de paralelização") seguido do bloco ` ```json ` canônico (o que o `mutirao run` parseia).

6. **Apresentar a proposta** ao usuário no chat:
   - Resumo: N mãos, M levas, quantas AFK vs HITL.
   - As **decisões de paralelização** (especialmente irmãs serializadas por conflito de arquivo).
   - O caminho da pauta gravada.
   - A linha pronta pra executar: `mutirao run <caminho-da-pauta> [--simulate] [--max-parallel N]`.

## Regras
- A pauta é **proposta**, não execução. Este comando nunca chama `mutirao run` — só prepara e persiste.
- **Não inventar tasks nem requisitos**. Só normalizar o que veio da fonte.
- Linear é **opt-in**: nunca assumir MCP conectado; se `--linear` sem MCP, parar e orientar.
- Acentuação PT-BR correta no que for escrito.
- Recomendar `--simulate` no primeiro run de uma pauta nova (valida levas/worktrees sem rodar IA).
- Se houver mãos HITL, deixar explícito que elas não rodam headless e precisam de tratamento humano.
