---
name: agentic-scout
description: >
  Diagnóstico de maturidade agêntica de um repo do workspace Isaac. Delega ao
  agent arco-agentic-scouter, que pontua o repo em 7 dimensões (total 100),
  classifica em 5 níveis (not-ready → exemplary), cross-mapeia no tier oficial do
  Agent Readiness Score (Bronze/Prata/Ouro/Platina + caminho até Platina), e
  produz glórias, dores, plano de readiness e veredito. Persiste a auditoria em
  ~/.notes/6-audits/. Use antes
  de investir tempo num repo (baseline), após melhorias (validação via --compare),
  ou em rotina de saúde do workspace. NÃO use para review de PR/doc (use /review-arco)
  nem para implementar feature (use /workflow).
user_invocable: true
---

# /agentic-scout

Command orquestrador que mede a maturidade agêntica de um repo do workspace e persiste
o diagnóstico no vault. É membro da família de orquestradores de workspace, ao lado de
`/review-arco`, `/review-arco-iterate` e `/workflow`. Opera sobre a estrutura
`agents/isaac/<repo>/` definida no AGENT_SPEC.md.

## Uso

```
/agentic-scout <repo> [--full] [--compare <YYYY-MM-DD>]
```

| Argumento | Descrição |
|-----------|-----------|
| `<repo>` | Slug do repo (pasta-filha do cwd): `backoffice`, `rf-monorepo`, `communication-api`, `backoffice-bff`, `gravity-design-system`, etc. Obrigatório. |
| `--full` | Scan profundo: lê agents individuais, rules/, hooks completos. Default lê só os sinais primários. |
| `--compare <data>` | Carrega a auditoria anterior do vault (mesmo repo, data dada) e mostra delta de score. |

### Exemplos

```
/agentic-scout backoffice
/agentic-scout rf-monorepo --full
/agentic-scout communication-api --compare 2026-06-25
```

---

## Step 0 — Resolver o alvo

1. Parse: primeiro token não-flag é `<repo>`. Flags `--full` e `--compare <data>` em qualquer posição.
2. Resolva o repo como pasta-filha do cwd:

```bash
REPO_PATH="$(pwd)/$REPO"
[ -d "$REPO_PATH" ] || REPO_PATH="$HOME/www/isaac/$REPO"
[ -d "$REPO_PATH" ] || { echo "repo '$REPO' não encontrado. Repos disponíveis:"; ls -d "$(pwd)"/*/ 2>/dev/null | xargs -n1 basename; exit 1; }
```

3. Confirme o slug canônico (deve casar com o diretório da suite):

```bash
REPO_SLUG=$(cd "$REPO_PATH" && gh repo view --json name -q .name 2>/dev/null || basename "$REPO_PATH")
```

4. Se `--compare`, resolva o path da auditoria anterior:

```bash
COMPARE_PATH=$(ls -t "$HOME/.notes/6-audits/<data>"*"agentic-scout-$REPO_SLUG.md" 2>/dev/null | head -1)
```

---

## Step 1 — Delegar ao arco-agentic-scouter

Invoque o agent `arco-agentic-scouter` via Task tool, passando:

- `REPO_SLUG` — o slug canônico resolvido
- `REPO_PATH` — o path absoluto
- `SCAN_MODE` — `full` se `--full`, senão `basic`
- `COMPARE_PATH` — o path da auditoria anterior, se houver

O agent devolve o `SCOUT_REPORT` no formato da seção 5 do agent (score por dimensão,
glórias, dores, plano, veredito). Ele é read-only — não escreve nada.

---

## Step 2 — Persistir no vault

Grave o `SCOUT_REPORT` em:

```
~/.notes/6-audits/<YYYY-MM-DD>-<HHMM>-agentic-scout-<repo-slug>.md
```

Não sobrescreva se existir — incremente HHMM. Frontmatter:

```yaml
---
date: "<YYYY-MM-DD>"
time: "<HH:MM>"
type: audit
context: "arco"
execution_status: "open"
pending_organize: true
tags: [agentic-readiness, agentic-scout, <repo-slug>, audit]
parent: "[[_index]]"
provenance:
  machine: "<$DOTFILES_AI_MACHINE ou personal>"
  hostname: "<hostname -s>"
  cwd: "<pwd>"
  scanned_repo: "<repo-slug>"
  scan_mode: "<basic|full>"
  invocation: "/agentic-scout <args>"
  generator: "agentic-scout"
  captured_at: "<ISO8601 com timezone>"
---
```

O corpo é o `SCOUT_REPORT` renderizado.

---

## Step 3 — Reportar inline

Mostre ao usuário, em formato enxuto:

- Score total + classificação (+ delta se `--compare`)
- O tier oficial (Agent Readiness Score) + bypasses confirmados
- A tabela das 7 dimensões
- O caminho até Platina (critérios faltantes por ID)
- Top 3 do plano de readiness
- O veredito Maria Bonita
- O path da auditoria salva no vault

---

## Rules

- Nunca modifique o repo inspecionado — o agent é read-only e o command só lê + grava no vault.
- Um repo por invocação. Para varrer o workspace inteiro, chame o command em sequência por repo.
- O slug do repo deve casar com o diretório da suite em `agents/isaac/<repo-slug>/` (quando existir).
- Persistência sempre em `~/.notes/6-audits/` com `pending_organize: true` — o /organize reconcilia depois.
- Acentuação PT-BR correta no relatório e no veredito.
