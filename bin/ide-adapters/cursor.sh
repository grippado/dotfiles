#!/usr/bin/env bash
#
# ide-adapter: cursor
#
# Fontes (macOS, READ-ONLY):
#   1. ~/Library/Application Support/Cursor/User/globalStorage/state.vscdb
#      (SQLite, ~278MB, com WAL). Tabela ItemTable, chaves:
#        - 'cursor/pendingMemories'
#        - 'cursorPendingMemories'
#      Cada uma e um array JSON de:
#        {id, memory, title, requestId, composerId, timestamp}
#      -> emite um item normalizado por memoria (kind=memory).
#   2. ~/.cursor/prompt_history.json  (array JSON de strings)
#      -> um item por prompt com >40 chars (kind=prompt).
#
# Contrato:
#   - Invocado como: cursor.sh --since "<epoch_ms_ou_iso_ou_vazio>"
#   - Emite SOMENTE JSONL normalizado em stdout. Diagnostico -> stderr.
#   - SEMPRE exit 0 (sem dados / ferramenta ausente / DB vazio).
#   - READ-ONLY: o state.vscdb tem WAL e pode estar locked, entao copiamos
#     a copia pra $TMPDIR e lemos com sqlite3 mode=ro. NUNCA escreve na fonte.
#   - Sem segredos (nao toca auth.json/oauth/mcp-oauth-attempts). Sem blobs.
#   - item_id estavel entre runs (sha1 de conteudo+source).
# ---------------------------------------------------------------------------

set -uo pipefail

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
if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "cursor adapter: sqlite3 ausente, pulando" >&2
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "cursor adapter: jq ausente, pulando" >&2
  exit 0
fi

# sha1 -> hex (sha1sum ou shasum, o que existir)
if command -v sha1sum >/dev/null 2>&1; then
  _sha1() { sha1sum | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
  _sha1() { shasum -a 1 | awk '{print $1}'; }
else
  echo "cursor adapter: sha1sum/shasum ausente, pulando" >&2
  exit 0
fi

# --- filtro de ruido ---------------------------------------------------------
# True (exit 0) se o texto parece output de maquina e nao prompt humano:
# log AWS/CloudWatch, stacktrace JS, paste de terminal. Conservador: so dropa
# quando >=3 linhas batem assinaturas fortes que nao ocorrem em prompt legitimo
# (assim um "corrige esse erro: <1-2 linhas>" continua passando).
_is_log_noise() {
  local n
  n="$(printf '%s\n' "$1" | grep -cE \
    -e '\[\$LATEST\]' \
    -e 'file:///var/task/' \
    -e 'node:internal/' \
    -e 'processTicksAndRejections' \
    -e '^[[:space:]]*at [A-Za-z0-9_.<>]+ ?\(' \
    -e '^[[:space:]]*at async ' \
    -e '^[0-9]{4}/[0-9]{2}/[0-9]{2}' \
    -e $'\xe2\x9d\xaf[[:space:]]' 2>/dev/null)"
  [ "${n:-0}" -ge 3 ]
}

# --- normalizacao de --since para epoch_ms -----------------------------------
# Aceita epoch_ms (so digitos), ISO8601, ou vazio. Vazio => sem filtro (0).
since_ms() {
  local raw="$1"
  [ -z "$raw" ] && { echo 0; return; }
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    # ja e epoch. Se parecer segundos (10 digitos), converte pra ms.
    if [ "${#raw}" -le 11 ]; then
      echo $(( raw * 1000 ))
    else
      echo "$raw"
    fi
    return
  fi
  # ISO8601 -> epoch s (BSD date no macOS). Melhor esforco.
  local epoch
  epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${raw%%.*}" "+%s" 2>/dev/null)
  if [ -z "$epoch" ]; then
    epoch=$(date -j -f "%Y-%m-%d" "${raw%%T*}" "+%s" 2>/dev/null)
  fi
  if [ -z "$epoch" ]; then
    echo 0
  else
    echo $(( epoch * 1000 ))
  fi
}

SINCE_MS="$(since_ms "$SINCE")"

CURSOR_STATE="$HOME/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
PROMPT_HISTORY="$HOME/.cursor/prompt_history.json"

TMP_DB=""
cleanup() { [ -n "$TMP_DB" ] && rm -f "$TMP_DB" "$TMP_DB-wal" "$TMP_DB-shm" 2>/dev/null; }
trap cleanup EXIT

# ============================================================================
# Fonte 1: memorias inferidas (state.vscdb)
# ============================================================================
if [ -f "$CURSOR_STATE" ]; then
  # Copia pra $TMPDIR (WAL pode estar locked). Leitura na copia, mode=ro.
  TMP_DB="${TMPDIR:-/tmp}/cursor-state-$$.vscdb"
  if cp "$CURSOR_STATE" "$TMP_DB" 2>/dev/null; then
    # Copia tambem WAL/SHM se existirem, pra ver dados nao-checkpointed.
    [ -f "$CURSOR_STATE-wal" ] && cp "$CURSOR_STATE-wal" "$TMP_DB-wal" 2>/dev/null
    [ -f "$CURSOR_STATE-shm" ] && cp "$CURSOR_STATE-shm" "$TMP_DB-shm" 2>/dev/null

    # Extrai os arrays JSON das duas chaves e concatena.
    raw_mem="$(sqlite3 "file:${TMP_DB}?mode=ro" \
      "SELECT value FROM ItemTable WHERE key IN ('cursor/pendingMemories','cursorPendingMemories');" \
      2>/dev/null)"

    if [ -n "$raw_mem" ]; then
      # Cada linha do sqlite e um array JSON. jq -c -s junta todos, achata,
      # filtra por --since e emite um objeto normalizado por memoria.
      printf '%s\n' "$raw_mem" \
        | jq -c -R 'fromjson? // empty | (if type=="array" then .[] else . end)' 2>/dev/null \
        | jq -c --argjson since "$SINCE_MS" \
            'select((.memory // "") != "")
             | (.timestamp // 0) as $ts
             | select(($ts | tonumber? // 0) >= $since)
             | {
                 id: (.id // ""),
                 title: ((.title // .memory // "") | tostring),
                 memory: (.memory | tostring),
                 timestamp: $ts
               }' 2>/dev/null \
        | while IFS= read -r row; do
            [ -z "$row" ] && continue
            mid="$(jq -r '.id' <<<"$row")"
            title="$(jq -r '.title' <<<"$row")"
            memory="$(jq -r '.memory' <<<"$row")"
            ts="$(jq -r '.timestamp' <<<"$row")"

            # item_id = sha1(id + memory), estavel entre runs.
            item_id="$(printf '%s' "${mid}${memory}" | _sha1)"

            # title capado em 120, summary capado em 500.
            title_c="$(printf '%s' "$title" | cut -c1-120)"
            summary_c="$(printf '%s' "$memory" | cut -c1-500)"

            jq -nc \
              --arg item_id "$item_id" \
              --arg title "$title_c" \
              --arg summary "$summary_c" \
              --arg ts "$ts" \
              --arg src "$CURSOR_STATE" \
              '{
                 tool: "cursor",
                 item_id: $item_id,
                 title: $title,
                 summary: $summary,
                 timestamp: $ts,
                 cwd_hint: "",
                 source_path: $src,
                 kind: "memory"
               }'
          done
    fi
  else
    echo "cursor adapter: falha ao copiar state.vscdb" >&2
  fi
else
  echo "cursor adapter: state.vscdb ausente em $CURSOR_STATE" >&2
fi

# ============================================================================
# Fonte 2: prompt_history.json
# Sem timestamp por item -> usa mtime do arquivo (epoch ms) pra todos.
# ============================================================================
if [ -f "$PROMPT_HISTORY" ]; then
  # mtime em segundos (BSD stat) -> ms.
  mtime_s="$(stat -f %m "$PROMPT_HISTORY" 2>/dev/null || echo 0)"
  mtime_ms=$(( mtime_s * 1000 ))

  # --since: se o arquivo inteiro for mais velho que o watermark, pula tudo
  # (so ha o mtime do arquivo como timestamp).
  if [ "$mtime_ms" -ge "$SINCE_MS" ]; then
    # jq -c: UM elemento do array por linha (JSON-encoded, newline-safe).
    # Antes era jq -r + `read`, que fragmentava prompts multi-linha (um paste
    # de log/stacktrace virava dezenas de "prompts"). Agora cada elemento e'
    # um item unico; pastes de log sao descartados por _is_log_noise.
    jq -c 'if type=="array" then .[] else empty end
           | select(type=="string")
           | select((. | length) > 40)' "$PROMPT_HISTORY" 2>/dev/null \
      | while IFS= read -r prompt_json; do
          [ -z "$prompt_json" ] && continue
          # decodifica a string JSON (preserva newlines internos do prompt)
          prompt="$(jq -r '.' <<<"$prompt_json")"
          [ -z "$prompt" ] && continue

          if _is_log_noise "$prompt"; then
            echo "cursor adapter: prompt ignorado (log/terminal output)" >&2
            continue
          fi

          item_id="$(printf '%s' "$prompt" | _sha1)"
          # title = 1a linha (capada em 80); summary = 500 chars, newline->espaco
          title_c="$(printf '%s' "$prompt" | head -1 | cut -c1-80)"
          summary_c="$(printf '%s' "$prompt" | tr '\n' ' ' | cut -c1-500)"

          jq -nc \
            --arg item_id "$item_id" \
            --arg title "$title_c" \
            --arg summary "$summary_c" \
            --arg ts "$mtime_ms" \
            --arg src "$PROMPT_HISTORY" \
            '{
               tool: "cursor",
               item_id: $item_id,
               title: $title,
               summary: $summary,
               timestamp: $ts,
               cwd_hint: "",
               source_path: $src,
               kind: "prompt"
             }'
        done
  fi
else
  echo "cursor adapter: prompt_history.json ausente em $PROMPT_HISTORY" >&2
fi

exit 0
