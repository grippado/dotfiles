#!/usr/bin/env bash
#
# ide-adapter: gemini
#
# Fonte REAL: ~/.gemini/tmp/<project>/chats/*.jsonl
#   Ex.: ~/.gemini/tmp/claude-atlas/chats/session-2026-05-16T02-56-0d8575cb.jsonl
#   Cada arquivo = uma sessao do Gemini CLI.
#   Cada linha = um evento JSON:
#     - header: {sessionId, projectHash, startTime, lastUpdated, kind}
#     - {type:"user",   content:[{text:...}], timestamp}
#     - {type:"gemini", content:"<string>",  timestamp, model, tokens, thoughts}
#     - {"$set":{lastUpdated:...}}  (eventos de update, ignorados)
#
# Emite UM item normalizado kind=conversation por arquivo de sessao.
#
# CONTRATO:
#   - Invocado como: gemini.sh --since "<epoch_ms_ou_iso_ou_vazio>"
#   - SOMENTE JSONL normalizado em stdout (uma linha por item). Diagnostico -> stderr.
#   - SEMPRE exit 0 (fonte ausente, vazia, jq faltando, etc.).
#   - READ-ONLY absoluto. So lemos os *.jsonl de chats. NUNCA tocamos
#     oauth_creds.json, google_accounts.json, cli-config.json (tokens).
#   - PROIBIDO emitir segredos/blobs. title/summary capados e sumarizados.
#   - item_id = sha1(path) -> estavel entre runs.
#
# ---------------------------------------------------------------------------

set -euo pipefail

# ---- Parse de argumentos (contrato: --since "<epoch_ms_ou_iso_ou_vazio>") ----
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

GEMINI_TMP="${HOME}/.gemini/tmp"
PROJECTS_JSON="${HOME}/.gemini/projects.json"

# ---- Guards: nada pra fazer -> exit 0 silencioso ----
if [ ! -d "$GEMINI_TMP" ]; then
  echo "gemini adapter: ${GEMINI_TMP} ausente, nada a fazer" >&2
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "gemini adapter: jq nao encontrado, abortando sem itens" >&2
  exit 0
fi

# sha1 helper (macOS: shasum; linux: sha1sum). Best effort.
sha1_of() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 1 | awk '{print $1}'
  elif command -v sha1sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha1sum | awk '{print $1}'
  else
    # fallback improvavel: sem sha1, usa cksum (nao ideal mas estavel)
    printf '%s' "$1" | cksum | awk '{print $1}'
  fi
}

# ---- Normalizar --since para epoch_ms (filtro por data do arquivo) ----
# Aceita: vazio | epoch_ms (>=10^11 ~ ms) | epoch_s | ISO8601 | YYYY-MM-DD.
since_to_epoch_ms() {
  local raw="$1"
  [ -z "$raw" ] && { echo ""; return 0; }

  # Puramente numerico?
  if printf '%s' "$raw" | grep -Eq '^[0-9]+$'; then
    local n="$raw"
    # heuristica: >= 13 digitos -> ja em ms; senao trata como segundos.
    if [ "${#n}" -ge 13 ]; then
      echo "$n"
    else
      echo "$((n * 1000))"
    fi
    return 0
  fi

  # ISO / YYYY-MM-DD -> tenta date. macOS BSD date primeiro, depois GNU.
  local secs=""
  # normaliza YYYY-MM-DD puro pra meia-noite UTC
  local iso="$raw"
  case "$iso" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
      iso="${iso}T00:00:00Z"
      ;;
  esac

  # BSD date (macOS)
  secs=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "${iso%%.*}Z" "+%s" 2>/dev/null || true)
  if [ -z "$secs" ]; then
    secs=$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "${iso%%.*}" "+%s" 2>/dev/null || true)
  fi
  # GNU date fallback
  if [ -z "$secs" ]; then
    secs=$(date -u -d "$raw" "+%s" 2>/dev/null || true)
  fi

  if [ -n "$secs" ]; then
    echo "$((secs * 1000))"
  else
    echo ""  # nao deu pra parsear -> sem filtro
  fi
}

SINCE_MS="$(since_to_epoch_ms "$SINCE")"
[ -n "$SINCE_MS" ] && echo "gemini adapter: --since => ${SINCE_MS} ms" >&2

# Extrai epoch_ms de um nome de arquivo session-YYYY-MM-DDTHH-MM-<hash>.jsonl
# (timestamp do arquivo). Best effort; vazio se nao casar.
fname_to_epoch_ms() {
  local base="$1"
  # remove prefixo session- e sufixo .jsonl
  local body="${base#session-}"
  body="${body%.jsonl}"
  # body ~ 2026-05-16T02-56-0d8575cb  => data=2026-05-16, hora=02, min=56
  local ts
  ts=$(printf '%s' "$body" | sed -nE 's/^([0-9]{4}-[0-9]{2}-[0-9]{2})T([0-9]{2})-([0-9]{2}).*$/\1T\2:\3:00Z/p')
  [ -z "$ts" ] && { echo ""; return 0; }
  local secs
  secs=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$ts" "+%s" 2>/dev/null || true)
  [ -z "$secs" ] && secs=$(date -u -d "$ts" "+%s" 2>/dev/null || true)
  [ -n "$secs" ] && echo "$((secs * 1000))" || echo ""
}

# Map project dir -> cwd_hint via projects.json (READ-ONLY) ou heuristica.
# projects.json: {"projects":{"<abs_path>":"<projname>"}}
# Queremos o inverso: <projname> -> <abs_path>.
project_to_cwd() {
  local proj="$1"
  local path=""
  if [ -f "$PROJECTS_JSON" ]; then
    path=$(jq -rc --arg p "$proj" \
      '(.projects // {}) | to_entries[] | select(.value==$p) | .key' \
      "$PROJECTS_JSON" 2>/dev/null | head -1)
  fi
  if [ -n "$path" ] && [ "$path" != "null" ]; then
    echo "$path"
    return 0
  fi
  # heuristica: ~/www/personal/<project> se existir
  local guess="${HOME}/www/personal/${proj}"
  if [ -d "$guess" ]; then
    echo "$guess"
  else
    echo ""
  fi
}

emitted=0

# ---- Itera sessoes ----
# Usa find pra robustez com nomes; ordena por nome (timestamp embutido).
while IFS= read -r path; do
  [ -z "$path" ] && continue
  [ -f "$path" ] || continue

  base="$(basename "$path")"

  # timestamp do arquivo (nome). fallback: 1a linha (header.startTime).
  ts_ms="$(fname_to_epoch_ms "$base")"

  # Le valores via jq num unico passe (slurp). Tudo best-effort.
  # - header_start: startTime do header
  # - first_user: 1a mensagem do usuario (string)
  # - last_gemini: ultima resposta do gemini (string)
  # - n_user / n_gemini: contagens p/ summary
  parsed=$(jq -rcs '
    def txt(c): if (c|type)=="array"
                then ([c[]? | (.text? // empty)] | join(" "))
                else (c|tostring) end;
    {
      start: ( [ .[] | select(.startTime?) | .startTime ] | first // "" ),
      first_ts: ( [ .[] | select(.timestamp?) | .timestamp ] | first // "" ),
      first_user: ( [ .[] | select(.type=="user")   | txt(.content) ] | first // "" ),
      last_gemini: ( [ .[] | select(.type=="gemini") | txt(.content) ] | last // "" ),
      n_user:   ( [ .[] | select(.type=="user") ]   | length ),
      n_gemini: ( [ .[] | select(.type=="gemini") ] | length )
    } | @json
  ' "$path" 2>/dev/null || true)

  [ -z "$parsed" ] && { echo "gemini adapter: skip ${base} (parse falhou)" >&2; continue; }

  header_start=$(printf '%s' "$parsed" | jq -rc '.start // ""')
  first_ts=$(printf '%s' "$parsed" | jq -rc '.first_ts // ""')
  first_user=$(printf '%s' "$parsed" | jq -rc '.first_user // ""')
  last_gemini=$(printf '%s' "$parsed" | jq -rc '.last_gemini // ""')
  n_user=$(printf '%s' "$parsed" | jq -rc '.n_user // 0')
  n_gemini=$(printf '%s' "$parsed" | jq -rc '.n_gemini // 0')

  # timestamp: prioriza nome do arquivo; senao header.startTime; senao 1a linha.
  timestamp="$ts_ms"
  if [ -z "$timestamp" ]; then
    if [ -n "$header_start" ]; then
      timestamp="$header_start"
    elif [ -n "$first_ts" ]; then
      timestamp="$first_ts"
    fi
  fi

  # ---- filtro --since (por data do arquivo / melhor esforco) ----
  if [ -n "$SINCE_MS" ] && [ -n "$ts_ms" ]; then
    if [ "$ts_ms" -lt "$SINCE_MS" ]; then
      continue
    fi
  fi

  # ---- cwd_hint: derivar do <project> (dir pai do /chats) ----
  # path = .../tmp/<project>/chats/<file>.jsonl
  chats_dir="$(dirname "$path")"
  project="$(basename "$(dirname "$chats_dir")")"
  cwd_hint="$(project_to_cwd "$project")"

  # ---- title: 1a mensagem do usuario, ~80 chars, single-line ----
  title="$first_user"
  [ -z "$title" ] && title="Sessao Gemini ${project}"
  # colapsa whitespace/newlines
  title=$(printf '%s' "$title" | tr '\n\r\t' '   ' | sed -E 's/  +/ /g; s/^ +//; s/ +$//')
  # capa em 80 chars
  title=$(printf '%s' "$title" | cut -c1-80)

  # ---- summary: 2-3 linhas, max 500, sumarizado (sem blobs) ----
  # Estrutura: pedido inicial + sinal de fechamento + contagem de turnos.
  ask=$(printf '%s' "$first_user" | tr '\n\r\t' '   ' | sed -E 's/  +/ /g; s/^ +//; s/ +$//' | cut -c1-200)
  done_line=$(printf '%s' "$last_gemini" | tr '\n\r\t' '   ' | sed -E 's/  +/ /g; s/^ +//; s/ +$//' | cut -c1-200)
  summary="Pedido: ${ask}"
  if [ -n "$done_line" ]; then
    summary="${summary} | Fechamento: ${done_line}"
  fi
  summary="${summary} | Turnos: ${n_user} user / ${n_gemini} gemini."
  summary=$(printf '%s' "$summary" | cut -c1-500)

  # ---- item_id: sha1(path), estavel entre runs ----
  item_id="$(sha1_of "$path")"

  # ---- emite JSONL normalizado (jq monta com escaping correto) ----
  jq -nc \
    --arg tool "gemini" \
    --arg item_id "$item_id" \
    --arg title "$title" \
    --arg summary "$summary" \
    --arg timestamp "$timestamp" \
    --arg cwd_hint "$cwd_hint" \
    --arg source_path "$path" \
    --arg kind "conversation" \
    '{
       tool: $tool,
       item_id: $item_id,
       title: $title,
       summary: $summary,
       timestamp: $timestamp,
       cwd_hint: $cwd_hint,
       source_path: $source_path,
       kind: $kind
     }'

  emitted=$((emitted + 1))

done < <(find "$GEMINI_TMP" -type f -path '*/chats/*.jsonl' 2>/dev/null | sort)

echo "gemini adapter: ${emitted} item(s) emitido(s)" >&2
exit 0
