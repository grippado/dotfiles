#!/usr/bin/env bash
#
# ide-adapter: copilot-chat (GitHub Copilot Chat dentro do VS Code)
#
# Emite UM item normalizado kind="conversation" por sessao de chat.
# Fontes (macOS, VS Code estavel):
#   $CODE/User/workspaceStorage/<id>/chatSessions/*.json(l)
#       -> JSON unico com .v.requests[] (mensagens do usuario em .message.text),
#          .v.creationDate em epoch ms.
#   $CODE/User/workspaceStorage/<id>/GitHub.copilot-chat/.../transcripts/*.jsonl
#       -> JSONL real; eventos {"type":"user.message","data":{"content":...}}.
#   $CODE/User/workspaceStorage/<id>/workspace.json
#       -> {"folder":"file:///path"} usado como cwd_hint.
#
# Contrato:
#   - Invocado como: copilot-chat.sh --since "<epoch_ms|iso|vazio>"
#   - SOMENTE JSONL normalizado em stdout (1 linha por sessao). Diagnostico -> stderr.
#   - SEMPRE exit 0 (Code ausente / sem sessions / arquivo corrompido).
#   - READ-ONLY: estas fontes sao arquivos JSON/JSONL planos (sem state.vscdb
#     aqui), entao basta nunca escrever. Nada e modificado na fonte.
#   - Nunca dumpa transcript cru: title/summary capados e sumarizados.
#   - Nunca emite segredos (tokens/keys); o conteudo capturado e so a 1a msg do
#     usuario + contagem de turnos, jamais arquivos de credencial.
#   - item_id estavel = sha1(source_path).
#
set -euo pipefail

# --- args -------------------------------------------------------------------
SINCE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --since)    SINCE="${2-}"; shift 2 || shift ;;
    --since=*)  SINCE="${1#--since=}"; shift ;;
    *)          shift ;;  # forward-compat: ignora desconhecidos
  esac
done

# --- helpers ----------------------------------------------------------------
CODE_BASE="$HOME/Library/Application Support/Code/User/workspaceStorage"

if ! command -v jq >/dev/null 2>&1; then
  echo "copilot-chat adapter: jq ausente; nada a fazer" >&2
  exit 0
fi
if [ ! -d "$CODE_BASE" ]; then
  echo "copilot-chat adapter: VS Code workspaceStorage nao encontrado ($CODE_BASE)" >&2
  exit 0
fi

# sha1 hex de stdin
sha1_hex() { shasum -a 1 | awk '{print $1}'; }

# Normaliza --since para epoch ms (vazio => 0). Aceita epoch ms ou ISO8601.
since_ms() {
  local s="$1"
  [ -z "$s" ] && { echo 0; return; }
  if printf '%s' "$s" | grep -Eq '^[0-9]+$'; then
    # epoch: se parecer segundos (10 digitos), converte pra ms
    if [ "${#s}" -le 11 ]; then echo $(( s * 1000 )); else echo "$s"; fi
    return
  fi
  # ISO8601 -> epoch ms (best effort, macOS date nao parseia ISO; usa python)
  python3 - "$s" <<'PY' 2>/dev/null || echo 0
import sys,datetime
try:
    t=sys.argv[1].replace('Z','+00:00')
    print(int(datetime.datetime.fromisoformat(t).timestamp()*1000))
except Exception:
    print(0)
PY
}
SINCE_MS="$(since_ms "$SINCE")"

# mtime do arquivo em epoch ms (macOS stat)
mtime_ms() { echo $(( $(stat -f %m "$1" 2>/dev/null || echo 0) * 1000 )); }

# Decodifica file:///path -> /path (com percent-decoding). Vazio se nao for file://
folder_to_path() {
  local raw="$1"
  case "$raw" in
    file://*) : ;;
    *) echo ""; return ;;
  esac
  python3 - "$raw" <<'PY' 2>/dev/null || echo ""
import sys,urllib.parse
u=urllib.parse.urlparse(sys.argv[1])
print(urllib.parse.unquote(u.path))
PY
}

# cwd_hint a partir do workspace.json no diretorio do workspace (2 niveis acima
# do arquivo de sessao para chatSessions; transcripts ficam mais fundo, entao
# subimos ate achar workspace.json).
cwd_for_session() {
  local f="$1" dir
  dir="$(dirname "$f")"
  # sobe ate o root do workspace (onde mora workspace.json), max 6 niveis
  local i=0
  while [ "$i" -lt 6 ] && [ "$dir" != "/" ] && [ "$dir" != "$CODE_BASE" ]; do
    if [ -f "$dir/workspace.json" ]; then
      local folder
      folder="$(jq -r '.folder // empty' "$dir/workspace.json" 2>/dev/null)"
      [ -n "$folder" ] && { folder_to_path "$folder"; return; }
    fi
    dir="$(dirname "$dir")"
    i=$(( i + 1 ))
  done
  echo ""
}

# --- emissao de um item -----------------------------------------------------
# Constroi e imprime a linha JSONL normalizada (uma so).
emit_item() {
  local source_path="$1" title="$2" summary="$3" ts_ms="$4" cwd="$5"
  local item_id
  item_id="$(printf '%s' "$source_path" | sha1_hex)"
  # cap title 120, summary 500 -> feito em jq pra lidar com unicode/escape
  jq -cn \
    --arg tool "copilot" \
    --arg item_id "$item_id" \
    --arg title "$title" \
    --arg summary "$summary" \
    --arg ts "$ts_ms" \
    --arg cwd "$cwd" \
    --arg src "$source_path" \
    --arg kind "conversation" \
    '{
       tool: $tool,
       item_id: $item_id,
       title: ($title | gsub("\\s+";" ") | .[0:120]),
       summary: ($summary | gsub("\\s+";" ") | .[0:500]),
       timestamp: ($ts | tonumber),
       cwd_hint: $cwd,
       source_path: $src,
       kind: $kind
     }'
}

# --- 1) transcripts JSONL (GitHub.copilot-chat) -----------------------------
# Estes tem o conteudo real das conversas neste setup.
while IFS= read -r T; do
  [ -n "$T" ] || continue
  ts_ms="$(mtime_ms "$T")"
  [ "$ts_ms" -gt "$SINCE_MS" ] 2>/dev/null || continue

  # 1a mensagem do usuario -> title; conta turnos do usuario -> summary
  first_user="$(jq -rs '
      [ .[] | select(.type=="user.message") | .data.content // empty ] as $u
      | ($u[0] // "")' "$T" 2>/dev/null)"
  n_user="$(jq -rs '[ .[] | select(.type=="user.message") ] | length' "$T" 2>/dev/null || echo 0)"
  n_asst="$(jq -rs '[ .[] | select(.type=="assistant.message") ] | length' "$T" 2>/dev/null || echo 0)"

  # pula transcripts sem nenhuma fala do usuario (so ruido)
  [ -n "$first_user" ] || { echo "copilot-chat: transcript sem user.message, pulado: $T" >&2; continue; }

  cwd="$(cwd_for_session "$T")"
  title="$first_user"
  summary="Sessao Copilot Chat (VS Code): ${n_user} msg(s) do usuario, ${n_asst} resposta(s). Inicio: ${first_user}"
  emit_item "$T" "$title" "$summary" "$ts_ms" "$cwd"
done < <(find "$CODE_BASE" -type f -path '*GitHub.copilot-chat*transcripts*.jsonl' 2>/dev/null)

# --- 2) chatSessions (.json / .jsonl, JSON unico com .v.requests) -----------
while IFS= read -r S; do
  [ -n "$S" ] || continue
  ts_ms="$(mtime_ms "$S")"
  [ "$ts_ms" -gt "$SINCE_MS" ] 2>/dev/null || continue

  # Valida JSON e extrai 1a msg do usuario. Schema VS Code: .v.requests[].message.text
  # (fallback pra .v.requests[].message quando for string).
  if ! first_user="$(jq -r '
      ( .v.requests // [] ) as $r
      | ( [ $r[]
            | (.message.text // (if (.message|type)=="string" then .message else empty end))
            | select(. != null and . != "") ] ) as $u
      | ($u[0] // "")' "$S" 2>/dev/null)"; then
    # jq falhou (arquivo nao-JSON / corrompido) -> pula
    echo "copilot-chat: chatSession invalido, pulado: $S" >&2
    continue
  fi

  n_user="$(jq -r '( .v.requests // [] ) | length' "$S" 2>/dev/null || echo 0)"

  # creationDate (epoch ms) preferido sobre mtime, quando presente
  cdate="$(jq -r '.v.creationDate // empty' "$S" 2>/dev/null)"
  if printf '%s' "$cdate" | grep -Eq '^[0-9]+$'; then ts_ms="$cdate"; fi

  if [ -z "$first_user" ]; then
    echo "copilot-chat: chatSession sem requests do usuario, pulado: $S" >&2
    continue
  fi

  cwd="$(cwd_for_session "$S")"
  title="$first_user"
  summary="Sessao Copilot Chat (VS Code): ${n_user} request(s) do usuario. Inicio: ${first_user}"
  emit_item "$S" "$title" "$summary" "$ts_ms" "$cwd"
done < <(find "$CODE_BASE" -type f -path '*chatSessions*' \( -name '*.json' -o -name '*.jsonl' \) 2>/dev/null)

exit 0
