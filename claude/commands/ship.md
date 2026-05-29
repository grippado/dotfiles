---
description: "Full feature shipping workflow — delega subagents e persiste resumo executivo da PR no vault .notes"
---

After implementing the requested feature:

1. Spawn `doc-writer` to generate PR description from the diff
2. Spawn `test-writer` to generate tests for changed files
3. Spawn `git-assistant` to prepare conventional commit messages
4. Spawn `memory-extractor` to save key decisions

5. **Garantir PR em DRAFT e persistir resumo executivo no vault** (main thread + context-keeper):
   - Run `gh pr view --json number,title,url,headRefName,baseRefName,body,isDraft 2>/dev/null` para detectar PR aberta na branch atual.
   - **Se NÃO houver PR aberta**, criar como **rascunho**: `gh pr create --draft --title "<do doc-writer>" --body "<do doc-writer>"` (ou `--fill` se faltar título/corpo).
   - **Se houver PR aberta e não for draft** (`isDraft=false`), convertê-la para rascunho: `gh pr ready --undo`.
   - **Regra inegociável:** toda PR aberta/gerida pelo `/ship` é **draft** por padrão. O autor marca como "ready for review" manualmente, depois de revisar. (status no frontmatter da nota = `draft`.)
   - Identificar o repo (`basename $(git rev-parse --show-toplevel)`) e mapear pro contexto do vault:
     - Repos sob `~/www/isaac/*` → `~/.notes/1-contexts/arco/pr-reviews/<repo>/`
     - Outros → perguntar ao usuário o contexto, ou usar `~/.notes/0-inbox/`
   - Spawn `context-keeper` com este prompt:
     ```
     Crie nota em ~/.notes/1-contexts/arco/pr-reviews/<repo>/YYYY-MM-DD-<repo>-PR<N>.md (timestamp = hoje, PR<N> = número da PR).
     Frontmatter padrão do vault: date, repo, pr, title, url, status (draft/open), author, tags.
     Seções obrigatórias:
       ## Resumo executivo (3-5 linhas: o que mudou e por quê)
       ## Diff (commits, arquivos, +/-)
       ## Arquivos tocados (tabela: arquivo | mudança)
       ## Contexto (motivação, plan/RFC/Linear se houver)
       ## Como testar
       ## Links
     PT-BR com acentuação correta. Wikilinks pra notas relacionadas em 1-contexts/arco/plans/ ou decisions/ se aplicável.
     Use os outputs do doc-writer, git-assistant e memory-extractor desta run como insumo.
     ```
   - Se não houver PR aberta, pular este passo e avisar o usuário.

6. Spawn `context-keeper` to write a session summary (escopo conversa, separado da nota da PR)

Execute all subagents. Do not skip any step.
Present the results in order when all complete, including o path da nota da PR criada no vault.
