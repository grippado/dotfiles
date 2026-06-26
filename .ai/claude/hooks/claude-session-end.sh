#!/usr/bin/env bash
# Claude Code SessionEnd hook — auto-save da sessão no vault .notes.
#
# Quando uma sessão com TRABALHO REAL termina (clear/logout/exit/fechar terminal),
# dispara em background um `claude` headless que RESUME a sessão encerrada e roda
# o `/context-save` nela — reusando o comando existente como motor de síntese.
# Sessões triviais (só perguntas, sem edits/agents/commits) são puladas, sem spam.
#
# Wire em ~/.claude/settings.json (gerado de ~/.dotfiles-ai/claude/settings.base.json):
#
#   {
#     "hooks": {
#       "SessionEnd": [
#         { "matcher": "", "hooks": [
#           { "type": "command",
#             "command": "$HOME/.dotfiles-ai/claude/hooks/claude-session-end.sh" }
#         ]}
#       ]
#     }
#   }
#
# Stdin = payload do hook (JSON). Campos confirmados empiricamente:
#   session_id, transcript_path, cwd, hook_event_name, reason
#
# Sempre `exit 0` — nunca bloqueia o shutdown do Claude. Trabalho é fire-and-forget.

LOG="$HOME/.context-autosave.log"
SENTINEL_DIR="$HOME/.cache/context-autosave"
CLAUDE_BIN="${CLAUDE_BIN:-$HOME/.local/bin/claude}"
# Modelo da síntese: Sonnet (alinhado à regra de roteamento "context saving → Sonnet").
# Tunável via env CONTEXT_AUTOSAVE_MODEL.
MODEL="${CONTEXT_AUTOSAVE_MODEL:-claude-sonnet-4-6}"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG"; }

# --- 1. Guarda anti-fork-bomb -------------------------------------------------
# O próprio run headless dispara SessionEnd (reason "other"). Sem isso, recursão.
if [ "$CONTEXT_AUTOSAVE" = "1" ]; then
    exit 0
fi

# --- 2. Ler payload -----------------------------------------------------------
PAYLOAD="$(cat)"
if ! command -v jq >/dev/null 2>&1; then
    log "[skip] jq não encontrado"
    exit 0
fi

SESSION_ID="$(printf '%s' "$PAYLOAD" | jq -r '.session_id // empty')"
TRANSCRIPT="$(printf '%s' "$PAYLOAD" | jq -r '.transcript_path // empty')"
CWD="$(printf '%s' "$PAYLOAD" | jq -r '.cwd // empty')"
REASON="$(printf '%s' "$PAYLOAD" | jq -r '.reason // empty')"

# Fallback: derivar transcript path de session_id + cwd se não veio no payload.
if [ -z "$TRANSCRIPT" ] && [ -n "$SESSION_ID" ] && [ -n "$CWD" ]; then
    ENCODED="$(printf '%s' "$CWD" | sed 's:/:-:g')"
    TRANSCRIPT="$HOME/.claude/projects/${ENCODED}/${SESSION_ID}.jsonl"
fi

if [ -z "$SESSION_ID" ] || [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
    log "[skip] sem session_id/transcript válido (id='$SESSION_ID' reason='$REASON')"
    exit 0
fi

# --- 3. Filtro de reason ------------------------------------------------------
case "$REASON" in
    clear|logout|prompt_input_exit|other) : ;;
    resume|bypass_permissions_disabled)
        log "[skip] reason='$REASON' (não dispara) sid=$SESSION_ID"
        exit 0 ;;
    *) : ;;  # reason desconhecido → tratar como válido (conservador: não perder)
esac

# --- 4. Anti-duplicata --------------------------------------------------------
mkdir -p "$SENTINEL_DIR"
SENTINEL="$SENTINEL_DIR/${SESSION_ID}.done"
if [ -f "$SENTINEL" ]; then
    log "[skip] já processada (dup) sid=$SESSION_ID"
    exit 0
fi

# --- 5. Gate de relevância ----------------------------------------------------
# Salva só se houve edição de arquivo, spawn de agent, plan aprovado, ou git commit.
# Nomes de tool confirmados no transcript .jsonl (blocos tool_use).
GATE_RE='"name":"(Edit|MultiEdit|Write|NotebookEdit|Agent|ExitPlanMode)"'
GIT_RE='"command":"[^"]*git (commit|add|push)'
if grep -qE "$GATE_RE" "$TRANSCRIPT" 2>/dev/null || grep -qE "$GIT_RE" "$TRANSCRIPT" 2>/dev/null; then
    : # relevante
else
    log "[skip] trivial (sem edit/agent/plan/commit) sid=$SESSION_ID reason=$REASON"
    exit 0
fi

# --- 6. Verificar binário -----------------------------------------------------
if [ ! -x "$CLAUDE_BIN" ]; then
    log "[skip] claude bin não executável em $CLAUDE_BIN"
    exit 0
fi

# --- 7. Disparar síntese headless (fire-and-forget) ---------------------------
touch "$SENTINEL"   # marca antes de disparar (idempotência mesmo se SessionEnd repetir)
log "[fire] autosave sid=$SESSION_ID reason=$REASON model=$MODEL cwd=$CWD"

SYS_PROMPT='Modo nao-interativo (SessionEnd autosave): voce NUNCA pode perguntar ao usuario. Se a sessao for borderline, salve mesmo assim. Gere o slug automaticamente. Nao espere confirmacao.'

(
    sleep 0.3   # garante flush do transcript da sessão recém-encerrada
    CONTEXT_AUTOSAVE=1 nohup "$CLAUDE_BIN" \
        --resume "$SESSION_ID" --fork-session \
        --model "$MODEL" \
        --append-system-prompt "$SYS_PROMPT" \
        --dangerously-skip-permissions \
        -p "/context-save" \
        >> "$LOG" 2>&1
    log "[done] autosave finalizado sid=$SESSION_ID rc=$?"
) &
disown

exit 0
