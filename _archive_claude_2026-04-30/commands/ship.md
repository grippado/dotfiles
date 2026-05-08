---
description: "Full feature shipping workflow — from diff to merged PR with ClickUp traceability"
---

# /ship

Fecha um ciclo de entrega de feature com rastreabilidade completa entre código (Git/GitHub) e produto (ClickUp).

**Premissa:** feature já implementada localmente, testes verdes, commit(s) no branch de trabalho. `/ship` leva daí até PR merged + task ClickUp fechada.

## Quando usar

- Terminou uma task do ClickUp e tem 1+ commits no branch
- Precisa formalizar a entrega com PR + rastreabilidade
- NÃO usar pra work-in-progress (use `/quick-commit` pra commits intermediários)

## Input esperado

Ao invocar, o usuário deve informar:
- **Task ID do ClickUp** (ex: `86e0xbf0d`) — se não fornecer, `/ship` tenta inferir pelo último comentário/commit message
- Branch alvo do merge (default: `main`)

## Fluxo (executar em ordem, não pular)

### 1. Pre-flight — verificar estado
- `git status` limpo no branch de trabalho? Se não, parar e pedir confirmação.
- Branch não é `main`? Se estiver em `main`, criar branch seguindo padrão (ver §3).
- Commits têm mensagem conventional + emoji (ver `~/.dotfiles/zsh/.zsh_git` types)? Se não, sugerir amend.
- Tests passam? Rodar a suite relevante.

### 2. Validar task no ClickUp
- `clickup_get_task` com o ID fornecido — confirmar existência, status atual, list.
- Se task está em `to do`, atualizar pra `in progress` (feature já está codada, status deve refletir).

### 3. Branch naming (se ainda estiver em main)
Padrão: `<type>/<task-suffix>-<slug>`

- `<type>`: `feat` | `fix` | `refactor` | `docs` | `chore` | `test`
- `<task-suffix>`: últimos 5-6 chars do task ID ClickUp (ex: `xbf0d` de `86e0xbf0d`)
- `<slug>`: kebab-case do escopo (ex: `context-builder`)

Exemplo: `feat/xbf0d-context-builder`

```bash
git checkout -b feat/xbf0d-context-builder
```

### 4. Spawn subagents (em paralelo)

1. **`doc-writer`** → PR description a partir do diff `git diff <base>..HEAD`
2. **`test-writer`** → validar/ampliar coverage de arquivos tocados
3. **`memory-extractor`** → salvar decisões-chave em auto-memory
4. **`context-keeper`** → session summary se relevante

### 5. Push branch
```bash
git push -u origin <branch-name>
```

### 6. Abrir PR com rastreabilidade ClickUp

**Título do PR:**
```
<emoji> <type>(<scope>): <message> [CU-<task_id>]
```
Exemplo: `✨ feat(api): add AI PromptContext builder [CU-86e0xbf0d]`

O `[CU-<task_id>]` aciona ClickUp GitHub Integration — a task linka o PR automaticamente.

**Body do PR** (via `gh pr create --body-file`):
```markdown
## Summary
<1-3 bullets do que muda>

## ClickUp
Closes [CU-<task_id>](https://app.clickup.com/t/<task_id>) — <task name>

## Related ADRs
- [ADR-000X — <título>](docs/adr/000X-<slug>.md)

## Test plan
- [ ] Unit tests: `<comando>`
- [ ] Integration tests: `<comando>` (quando aplicável)
- [ ] Manual smoke test: <descrever>
- [ ] `go vet ./...` / `pnpm lint` / equivalente

## Breaking changes
<"None" ou lista>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

Comando:
```bash
gh pr create --title "..." --body-file /tmp/pr-body.md --base main
```

### 7. Atualizar ClickUp com link do PR

`clickup_create_task_comment` na task:
```
🔀 PR aberto: <PR URL>
Branch: `<branch-name>`
Status: Review pendente

Commits:
- <hash> <commit subject>
- ...
```

### 8. Aguardar merge (ou merge direto se solo + permissão)

- Se time colaborativo: pedir review, esperar approval, merge via GitHub.
- Se solo + sem branch protection: `gh pr merge --squash --delete-branch` após checks verdes.
- Se bypass de branch protection como no FlagBridge atual: ainda abrir PR pra histórico, merge com bypass documentado.

### 9. Pós-merge — fechar task no ClickUp

`clickup_update_task` → status `complete`.

`clickup_create_task_comment` na task:
```
✅ Merged em <PR URL> (commit `<hash>` no main)
Deploy status: <pending | deployed | N/A>
```

### 10. Deploy (se aplicável)

Se a task entrega coisa que precisa ir pra produção:
- API → Fly.io (ver `feedback_deploy_flyio.md` na auto-memory)
- Admin/Landing/Docs → Vercel (auto-deploy em push to main)
- SDKs → npm publish via GitHub Actions

Atualizar ClickUp comment com deploy URL + hash.

## Exceções

- **Commit de emergency/hotfix** (produção down): pode pular PR temporariamente, mas abrir PR retroativo documentando a correção
- **Docs-only changes**: ADRs, CLAUDE.md updates, READMEs — podem ir direto pra main SE o repo permite, mas ainda criar task ClickUp pra auditoria
- **Backup branches** (ex: `wip/*`): push direto sem PR é aceitável — são snapshots, não candidatos a merge

## Regras

- NUNCA fazer direct push em `main` quando a task tem código funcional — PR sempre
- NUNCA fechar task ClickUp sem PR merged (ou exceção documentada)
- NUNCA mergear PR com CI vermelho
- NUNCA skipar comment final no ClickUp — rastreabilidade vive nos dois sentidos (PR→task, task→PR)

## Lembrete

Este workflow **dogfood rastreabilidade**. Cada task tem uma história completa: spec (ClickUp) → ADR (se houver) → PR (GitHub) → merge (commit) → deploy (status no ClickUp). Quebrar a cadeia perde contexto futuro.
