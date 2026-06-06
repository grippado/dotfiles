#!/usr/bin/env bash
#
# ide-adapter: opencode
#
# Fonte: ~/.local/share/opencode/opencode.db (SQLite).
# Tabelas relevantes: project, session, message, part.
#
# Estrategia: para cada session com mensagens, emite UM item normalizado com
# kind="conversation":
#   - tool        = "opencode"
#   - item_id     = sha1(session.id), hex (estavel entre runs)
#   - title       = primeiro texto do usuario (capado 120) ou titulo/nome do projeto
#   - summary     = sintese 2-3 linhas (max 500), SEM dumpar 'part' cru
#   - timestamp   = session.time_updated (epoch ms; fallback time_created)
#   - cwd_hint    = session.directory (fallback project.worktree)
#   - source_path = caminho do opencode.db
#
# Contrato (ver ide-memory-harvest):
#   - Invocado como: opencode.sh --since "<epoch_ms_ou_iso_ou_vazio>"
#   - SOMENTE JSONL normalizado em stdout (uma linha por item). Nada mais.
#   - SEMPRE exit 0 (sem dados / db ausente / db vazio). Diagnostico -> stderr.
#   - READ-ONLY absoluto na fonte: o opencode.db tem WAL/SHM e pode estar locked,
#     entao COPIAMOS o db (+ -wal/-shm) pra $TMPDIR e lemos a copia. Nunca escreve
#     na fonte.
#   - PROIBIDO ler/emitir segredos: NUNCA tocar auth.json (tem sk-ant-). So lemos
#     project/session/message/part. Nunca emitimos tokens.
#   - PROIBIDO dumpar blobs: title/summary capados; 'part' cru jamais e emitido.
#   - Respeita --since: so emite sessions com timestamp > since.

set -euo pipefail

# --- parse de argumentos -----------------------------------------------------
SINCE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --since)
      SINCE="${2-}"
      shift 2 || shift
      ;;
    --since=*)
      SINCE="${1#--since=}"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# --- dependencias ------------------------------------------------------------
command -v sqlite3 >/dev/null 2>&1 || { echo "opencode adapter: sqlite3 ausente" >&2; exit 0; }
command -v jq       >/dev/null 2>&1 || { echo "opencode adapter: jq ausente" >&2; exit 0; }

# sha1: shasum (macOS) ou sha1sum (linux)
_sha1() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 1 | awk '{print $1}'
  else
    printf '%s' "$1" | sha1sum | awk '{print $1}'
  fi
}

# --- fonte -------------------------------------------------------------------
SRC="${OPENCODE_DB:-$HOME/.local/share/opencode/opencode.db}"
if [ ! -f "$SRC" ]; then
  echo "opencode adapter: db nao encontrado em $SRC" >&2
  exit 0
fi

# --- normaliza --since para epoch ms ----------------------------------------
# Aceita: vazio | epoch ms (>= 10^12) | epoch s | ISO8601. Best effort.
SINCE_MS=0
if [ -n "$SINCE" ]; then
  if printf '%s' "$SINCE" | grep -Eq '^[0-9]+$'; then
    if [ "${#SINCE}" -ge 13 ]; then
      SINCE_MS="$SINCE"                 # ja em ms
    else
      SINCE_MS=$(( SINCE * 1000 ))      # epoch s -> ms
    fi
  else
    # ISO8601 -> epoch s (tenta GNU date e BSD date), depois ms.
    _es=$(date -u -d "$SINCE" +%s 2>/dev/null \
          || date -u -j -f "%Y-%m-%dT%H:%M:%S" "${SINCE%%.*}" +%s 2>/dev/null \
          || date -u -j -f "%Y-%m-%d" "${SINCE%%T*}" +%s 2>/dev/null \
          || echo "")
    if [ -n "$_es" ]; then
      SINCE_MS=$(( _es * 1000 ))
    else
      echo "opencode adapter: --since '$SINCE' nao parseavel; ignorando" >&2
    fi
  fi
fi

# --- copia READ-ONLY pra $TMPDIR (db pode estar com WAL/lock) ----------------
WORK="$(mktemp -d "${TMPDIR:-/tmp}/opencode-adapter.XXXXXX")" || { echo "opencode adapter: mktemp falhou" >&2; exit 0; }
trap 'rm -rf "$WORK"' EXIT
DB="$WORK/opencode.db"
cp -f "$SRC" "$DB" 2>/dev/null || { echo "opencode adapter: copia do db falhou" >&2; exit 0; }
# WAL/SHM, se existirem, pra a copia ver dados ainda nao checkpointed.
[ -f "${SRC}-wal" ] && cp -f "${SRC}-wal" "${DB}-wal" 2>/dev/null || true
[ -f "${SRC}-shm" ] && cp -f "${SRC}-shm" "${DB}-shm" 2>/dev/null || true

# helper de query read-only sobre a copia.
# Saida TAB-separada (campos multi-coluna) e SEM "" pra NULL virar string vazia.
_q() {
  sqlite3 -noheader -separator $'\t' "file:${DB}?mode=ro" "$1" 2>/dev/null
}

# Guard: tabela session existe?
HAS_SESSION=$(_q "SELECT name FROM sqlite_master WHERE type='table' AND name='session';")
if [ -z "$HAS_SESSION" ]; then
  echo "opencode adapter: tabela session ausente; nada a emitir" >&2
  exit 0
fi

# --- itera sessions ----------------------------------------------------------
# Uma linha por session: id | ts(ms) | directory | title | worktree(do project)
# Filtra por --since via SQL. Sessions sao TAB-separadas (campos podem ter
# espacos, mas nao tabs neste schema).
ROWS=$(_q "
  SELECT
    s.id,
    COALESCE(s.time_updated, s.time_created, 0),
    COALESCE(s.directory, ''),
    COALESCE(s.title, ''),
    COALESCE(p.worktree, '')
  FROM session s
  LEFT JOIN project p ON p.id = s.project_id
  WHERE COALESCE(s.time_updated, s.time_created, 0) > ${SINCE_MS}
  ORDER BY COALESCE(s.time_updated, s.time_created, 0) ASC;
" || true)

if [ -z "$ROWS" ]; then
  echo "opencode adapter: nenhuma session nova (since_ms=${SINCE_MS})" >&2
  exit 0
fi

EMITTED=0
# IFS=tab para separar os 5 campos.
while IFS=$'\t' read -r SID STS SDIR STITLE SWORKTREE; do
  [ -z "$SID" ] && continue

  # cwd_hint: directory da session, fallback worktree do project.
  CWD="$SDIR"
  [ -z "$CWD" ] && CWD="$SWORKTREE"

  # --- primeiro texto do usuario nesta session --------------------------------
  # message.data tem "role"; part.data tem {"type":"text","text":...}.
  # Pegamos o texto do part do tipo "text" da primeira message com role=user,
  # via jq (nunca emitimos o blob cru — so derivamos title/summary).
  FIRST_USER_TEXT=""
  USER_MID=$(_q "
    SELECT m.id
    FROM message m
    WHERE m.session_id = '$(printf '%s' "$SID" | sed "s/'/''/g")'
      AND json_extract(m.data, '\$.role') = 'user'
    ORDER BY m.time_created ASC
    LIMIT 1;
  " || true)

  if [ -n "$USER_MID" ]; then
    FIRST_USER_TEXT=$(_q "
      SELECT data
      FROM part
      WHERE message_id = '$(printf '%s' "$USER_MID" | sed "s/'/''/g")'
        AND json_extract(data, '\$.type') = 'text'
      ORDER BY time_created ASC
      LIMIT 1;
    " | jq -r 'try .text // ""' 2>/dev/null || true)
  fi

  # contagem de mensagens (pra sintese do summary)
  MSG_COUNT=$(_q "SELECT COUNT(*) FROM message WHERE session_id = '$(printf '%s' "$SID" | sed "s/'/''/g")';" || echo 0)
  [ -z "$MSG_COUNT" ] && MSG_COUNT=0

  # --- title: 1o texto do usuario, fallback title da session, fallback id -----
  TITLE_SRC="$FIRST_USER_TEXT"
  [ -z "$TITLE_SRC" ] && TITLE_SRC="$STITLE"
  [ -z "$TITLE_SRC" ] && TITLE_SRC="opencode session ${SID}"
  # colapsa whitespace/newlines numa linha so e capa em 120
  TITLE=$(printf '%s' "$TITLE_SRC" | tr '\n\r\t' '   ' | sed 's/  */ /g; s/^ //; s/ $//' | cut -c1-120)

  # --- summary: sintese curta, SEM blob cru -----------------------------------
  if [ -n "$FIRST_USER_TEXT" ]; then
    SUM_BODY=$(printf '%s' "$FIRST_USER_TEXT" | tr '\n\r\t' '   ' | sed 's/  */ /g; s/^ //; s/ $//' | cut -c1-300)
    SUMMARY="Sessao opencode (${MSG_COUNT} msgs). Primeiro pedido do usuario: ${SUM_BODY}"
  elif [ -n "$STITLE" ]; then
    STITLE1=$(printf '%s' "$STITLE" | tr '\n\r\t' '   ' | sed 's/  */ /g')
    SUMMARY="Sessao opencode (${MSG_COUNT} msgs): ${STITLE1}"
  else
    SUMMARY="Sessao opencode (${MSG_COUNT} msgs) em ${CWD:-?}."
  fi
  SUMMARY=$(printf '%s' "$SUMMARY" | cut -c1-500)

  # --- item_id estavel: sha1(session.id) --------------------------------------
  ITEM_ID=$(_sha1 "$SID")

  # --- emite UMA linha JSON via jq (escaping seguro) --------------------------
  jq -nc \
    --arg tool "opencode" \
    --arg item_id "$ITEM_ID" \
    --arg title "$TITLE" \
    --arg summary "$SUMMARY" \
    --arg timestamp "$STS" \
    --arg cwd_hint "$CWD" \
    --arg source_path "$SRC" \
    --arg kind "conversation" \
    '{tool:$tool, item_id:$item_id, title:$title, summary:$summary, timestamp:$timestamp, cwd_hint:$cwd_hint, source_path:$source_path, kind:$kind}'

  EMITTED=$((EMITTED+1))
done <<EOF
$ROWS
EOF

echo "opencode adapter: ${EMITTED} item(s) emitido(s)" >&2
exit 0
