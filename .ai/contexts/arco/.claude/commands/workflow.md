---
name: workflow
description: >
  Dispatcher de workspace despachado por repo. Recebe o repo como verbo e dispara
  o /workflow nativo daquele repo (não reimplementa nada), passando a task adiante.
  Ponto de entrada único para trabalho cross-repo a partir do workspace mode. Local
  apenas — não envolve CI nem Forja (Forja é opt-in e fora desta orquestração).
user_invocable: true
---

# /workflow

Dispatcher da camada de workspace. A partir de `~/www/isaac` (workspace mode), recebe o
repo como primeiro argumento e delega ao `/workflow` nativo daquele repo — que é o dono
da pipeline de execução (pull do ticket → pattern-finder → implement → test → review → PR).

Este command **não executa a task** ele mesmo. Ele resolve o repo, carrega o contexto, e
dispara o workflow do repo. Toda a lógica de implementação continua sendo do repo.

É membro da família de orquestradores de workspace, ao lado de `/review-arco`,
`/review-arco-iterate` e `/agentic-scout`.

## Uso

```
/workflow <repo> <ticket-ou-descrição> [flags-do-workflow-do-repo]
```

| Argumento | Descrição |
|-----------|-----------|
| `<repo>` | Slug do repo (pasta-filha do cwd): `backoffice`, `backoffice-bff`, `communication-api`, `rf-monorepo`. Obrigatório. |
| `<ticket-ou-descrição>` | O que passar ao `/workflow` do repo: ID/URL de ticket Linear ou descrição da task. |
| flags | Repassadas verbatim ao workflow do repo (ex: `--no-review` onde suportado). |

### Exemplos

```
/workflow backoffice CPU-1234
/workflow communication-api https://linear.app/isaac/issue/MOM-2693
/workflow rf-monorepo "ajustar empty state do EventAnnouncement"
```

---

## Step 0 — Resolver o repo-alvo

1. Parse: primeiro token é `<repo>`; o resto (`$REST`) é a task + flags, repassada inteira.
2. Resolva o repo como pasta-filha do cwd:

```bash
REPO_PATH="$(pwd)/$REPO"
[ -d "$REPO_PATH" ] || REPO_PATH="$HOME/www/isaac/$REPO"
```

3. Se não existir, pare com erro claro listando os repos disponíveis:

```bash
[ -d "$REPO_PATH" ] || { echo "repo '$REPO' não encontrado em $(pwd). Disponíveis:"; ls -d "$(pwd)"/*/ 2>/dev/null | xargs -n1 basename; exit 1; }
```

4. Valide que o repo tem um `/workflow` nativo:

```bash
[ -f "$REPO_PATH/.claude/commands/workflow.md" ] || {
  echo "'$REPO' não tem /workflow nativo (.claude/commands/workflow.md ausente)."
  echo "Repos com workflow: backoffice, backoffice-bff, communication-api, rf-monorepo."
  echo "(e2e-tests não tem workflow — nada a despachar.)"
  exit 1
}
```

---

## Step 1 — Carregar o contexto do repo e despachar

1. Entre no contexto do repo (o cwd determina qual `.claude/` o Claude Code carrega):

```bash
cd "$REPO_PATH"
```

2. Dispare o `/workflow` nativo do repo com a task + flags repassadas:

```
/workflow $REST
```

A partir daqui, **o workflow do repo assume**. Ele conhece o próprio scope de testes,
verificação local (Figma/curl/browser), gates e padrão de PR. O dispatcher não interfere.

---

## Step 2 — Reportar a delegação

Antes de disparar, informe ao usuário, em uma linha:

> Despachando para `<repo>`: `/workflow <task>` (workflow nativo do repo assume daqui).

Ao final, o resultado é o do workflow do repo (tipicamente uma PR draft + monitoramento de CI).

---

## Rules

- Este command é só um dispatcher: **nunca** reimplementa lógica de workflow.
- Local apenas. Não chama `/workflow-cloud` nem aciona CI.
- **Forja fica de fora.** Qualquer `/forja:*` é opt-in e não entra nesta orquestração — nunca o invoque a partir daqui.
- Um repo por invocação.
- Se o repo não tem `/workflow` nativo (ex: `e2e-tests`), pare com mensagem clara — não tente improvisar.
- Repasse flags verbatim; não as interprete (cada repo define as suas, ex: `--no-review`).
