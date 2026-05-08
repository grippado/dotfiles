#!/usr/bin/env bash
# Claude Code statusLine v3 — 2 linhas, ANSI colors
#
# Layout:
#   linha 1: <model> | EFFORT: <lvl> | <basename> [<branch> ↑N ↓N *]
#   linha 2: CTX [bar] N% | 5H HH:MM [bar] N% | 7D DD/MM [bar] N%
#
# Cores: cinza p/ labels, verde ok, amarelo warn (>=60%), vermelho crit (>=80%),
#        azul para path, ciano para git ahead/behind, amarelo para dirty (*).

input=$(cat)

# ─── parse input ─────────────────────────────────────────────────────────────
cwd=$(echo "$input"      | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input"    | jq -r '.model.display_name // .model.id // "?"')
session_id=$(echo "$input" | jq -r '.session_id // ""')
transcript=$(echo "$input" | jq -r '.transcript_path // ""')
ctx_pct=$(echo "$input"  | jq -r '.context_window.used_percentage // 0')
# Schema oficial (docs.claude.com/statusline): total_input_tokens + total_output_tokens / context_window_size
ctx_used=$(echo "$input" | jq -r '((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0))')
ctx_total=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
# Effort vem direto no payload (.effort.level); fallback p/ effortLevel do settings.json
effort_in=$(echo "$input" | jq -r '.effort.level // empty' 2>/dev/null)
rl5_pct=$(echo "$input"  | jq -r '.rate_limits.five_hour.used_percentage // 0')
rl5_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // 0')
rl7_pct=$(echo "$input"  | jq -r '.rate_limits.seven_day.used_percentage // 0')
rl7_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // 0')

now=$(date +%s)

# ─── cache fallback (rate-limits) ────────────────────────────────────────────
# Os campos rate_limits.* vêm zerados no início da sessão (antes do 1º request).
# Cacheamos em disco os últimos valores válidos e usamos como fallback,
# desde que resets_at ainda não tenha vencido.
CACHE="$HOME/.claude/.statusline-cache.json"

# normaliza "0" / "null" / "" → 0
to_int() { case "${1:-0}" in ''|null) echo 0 ;; *) echo "$1" ;; esac; }
rl5_pct=$(to_int "$rl5_pct")
rl5_reset=$(to_int "$rl5_reset")
rl7_pct=$(to_int "$rl7_pct")
rl7_reset=$(to_int "$rl7_reset")

# Fallback: se input não trouxe nada útil para 5H/7D, lê do cache
need_5=0; need_7=0
[ "$rl5_reset" = "0" ] && [ "$(printf '%.0f' "${rl5_pct:-0}")" = "0" ] && need_5=1
[ "$rl7_reset" = "0" ] && [ "$(printf '%.0f' "${rl7_pct:-0}")" = "0" ] && need_7=1

if { [ $need_5 -eq 1 ] || [ $need_7 -eq 1 ]; } && [ -f "$CACHE" ]; then
  c5_pct=$(jq -r '.rl5_pct   // 0' "$CACHE" 2>/dev/null)
  c5_rst=$(jq -r '.rl5_reset // 0' "$CACHE" 2>/dev/null)
  c7_pct=$(jq -r '.rl7_pct   // 0' "$CACHE" 2>/dev/null)
  c7_rst=$(jq -r '.rl7_reset // 0' "$CACHE" 2>/dev/null)
  if [ $need_5 -eq 1 ] && [ "${c5_rst:-0}" -gt "$now" ] 2>/dev/null; then
    rl5_pct="$c5_pct"; rl5_reset="$c5_rst"
  fi
  if [ $need_7 -eq 1 ] && [ "${c7_rst:-0}" -gt "$now" ] 2>/dev/null; then
    rl7_pct="$c7_pct"; rl7_reset="$c7_rst"
  fi
fi

# Se temos dados válidos agora, persiste no cache (write atômico via mv)
if [ "$rl5_reset" != "0" ] || [ "$rl7_reset" != "0" ]; then
  printf '{"rl5_pct":%s,"rl5_reset":%s,"rl7_pct":%s,"rl7_reset":%s}\n' \
    "${rl5_pct:-0}" "${rl5_reset:-0}" "${rl7_pct:-0}" "${rl7_reset:-0}" \
    > "${CACHE}.tmp" 2>/dev/null && mv "${CACHE}.tmp" "$CACHE" 2>/dev/null
fi

# ─── ANSI colors ─────────────────────────────────────────────────────────────
GREY=$'\033[90m'
GRN=$'\033[32m'
YEL=$'\033[33m'
RED=$'\033[1;31m'
BLU=$'\033[34m'
CYA=$'\033[36m'
WHT=$'\033[37m'
RST=$'\033[0m'

# ─── progress bar ────────────────────────────────────────────────────────────
# bar <pct>
# Largura fixa de 10. Cada `|` = 10% completo. `-` = pelo menos 5% além
# do último 10 (aparece quando pct % 10 >= 5). `.` = vazio.
# Exemplos: 20→||........  24→||........  25→||-.......  29→||-.......  30→|||.......
# Cor automática: <60% verde, 60-79% amarelo, >=80% vermelho.
bar() {
  local pct=$1
  local width=10
  local pct_int filled remainder has_half empty c i
  pct_int=$(printf '%.0f' "${pct:-0}")
  [ "$pct_int" -gt 100 ] 2>/dev/null && pct_int=100
  [ "$pct_int" -lt 0 ]   2>/dev/null && pct_int=0
  filled=$(( pct_int / 10 ))
  remainder=$(( pct_int % 10 ))
  has_half=0
  if [ "$remainder" -ge 5 ] && [ "$filled" -lt "$width" ]; then
    has_half=1
  fi
  empty=$(( width - filled - has_half ))
  if   [ "$pct_int" -ge 80 ]; then c="$RED"
  elif [ "$pct_int" -ge 60 ]; then c="$YEL"
  else                              c="$GRN"
  fi
  printf '[%s' "$c"
  i=0; while [ $i -lt $filled ]; do printf '|'; i=$((i+1)); done
  [ "$has_half" -eq 1 ] && printf '-'
  i=0; while [ $i -lt $empty ];  do printf '.'; i=$((i+1)); done
  printf '%s]' "$RST"
}

# ─── format tokens ───────────────────────────────────────────────────────────
# 1234 → 1.2k · 12345 → 12k · 999999 → 999k · 1234567 → 1.2M · 1000000 → 1M
fmt_tokens() {
  local n=${1:-0}
  awk -v n="$n" 'BEGIN{
    n = n + 0
    if (n <= 0)        { print "0"; exit }
    if (n < 1000)      { printf "%d", n; exit }
    if (n < 1000000)   {
      k = n / 1000
      if (k >= 100) { printf "%dk", k }
      else if (k == int(k)) { printf "%dk", k }
      else { printf "%.1fk", k }
      exit
    }
    m = n / 1000000
    if (m == int(m)) { printf "%dM", m }
    else             { printf "%.1fM", m }
  }'
}

# ─── effort detection ────────────────────────────────────────────────────────
# Prioridade: 1) .effort.level do payload (sempre atual)
#             2) effortLevel do settings.json (default persistente)
#             3) "--" se modelo não suporta effort
effort="${effort_in:-}"
if [ -z "$effort" ]; then
  for f in "$HOME/.claude/settings.json" "$HOME/.claude/settings.local.json"; do
    [ -f "$f" ] || continue
    _e=$(jq -r '.effortLevel // empty' "$f" 2>/dev/null)
    [ -n "$_e" ] && { effort="$_e"; break; }
  done
fi
[ -z "$effort" ] && effort="--"
effort=$(printf '%s' "$effort" | tr '[:upper:]' '[:lower:]')

# Cor por nível
case "$effort" in
  low)         eff_color="$GRN" ;;
  medium|med)  eff_color="$YEL" ;;
  high)        eff_color="$RED" ;;
  xhigh|max)   eff_color="$RED" ;;
  *)           eff_color="$GREY" ;;
esac

# ─── path + git ──────────────────────────────────────────────────────────────
# Caminho completo, com $HOME → ~
short_path="${cwd/#$HOME/~}"
[ -z "$short_path" ] && short_path="~"

git_part=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
        || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)

  # ahead / behind vs upstream
  ahead=0; behind=0
  upstream=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref '@{u}' 2>/dev/null)
  if [ -n "$upstream" ]; then
    counts=$(git -C "$cwd" --no-optional-locks rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)
    behind=$(echo "$counts" | awk '{print $1+0}')
    ahead=$(echo  "$counts" | awk '{print $2+0}')
  fi

  # dirty?
  dirty=""
  if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null | head -1)" ]; then
    dirty=" ${YEL}*${RST}"
  fi

  arrows=""
  [ "$ahead"  -gt 0 ] 2>/dev/null && arrows="${arrows} ${CYA}↑${ahead}${RST}"
  [ "$behind" -gt 0 ] 2>/dev/null && arrows="${arrows} ${CYA}↓${behind}${RST}"

  git_part=" ${GREY}[${RST}${GRN}${branch}${RST}${arrows}${dirty}${GREY}]${RST}"
fi

# ─── reset times ─────────────────────────────────────────────────────────────
# 5H reset: HH:MM (hora local)
# 7D reset: DD/MM
fmt_time() {
  local epoch=$1
  [ "$epoch" -gt 0 ] 2>/dev/null || { echo "--:--"; return; }
  date -r "$epoch" "+%H:%M" 2>/dev/null || date -d "@$epoch" "+%H:%M" 2>/dev/null || echo "--:--"
}
fmt_date() {
  local epoch=$1
  [ "$epoch" -gt 0 ] 2>/dev/null || { echo "--/--"; return; }
  date -r "$epoch" "+%d/%m" 2>/dev/null || date -d "@$epoch" "+%d/%m" 2>/dev/null || echo "--/--"
}

rl5_when=$(fmt_time "$rl5_reset")
rl7_when=$(fmt_date "$rl7_reset")

# ─── format pct ──────────────────────────────────────────────────────────────
fmt_pct() {
  awk -v n="$1" 'BEGIN{
    s=sprintf("%.0f", n+0)
    print s
  }'
}

ctx_int=$(fmt_pct "$ctx_pct")
rl5_int=$(fmt_pct "$rl5_pct")
rl7_int=$(fmt_pct "$rl7_pct")

# Cor do número (acompanha o bar)
pct_color() {
  local p=$1
  if   [ "$p" -ge 80 ] 2>/dev/null; then printf '%s' "$RED"
  elif [ "$p" -ge 60 ] 2>/dev/null; then printf '%s' "$YEL"
  else                                    printf '%s' "$GRN"
  fi
}
ctx_c=$(pct_color "$ctx_int")
rl5_c=$(pct_color "$rl5_int")
rl7_c=$(pct_color "$rl7_int")

# ─── render ──────────────────────────────────────────────────────────────────
# Linha 1: model · EFFORT · path[git]
printf '%s%s%s | %sEFFORT%s %s%s%s | %s%s%s%s\n' \
  "$GREY" "$model" "$RST" \
  "$GREY" "$RST" "$eff_color" "$effort" "$RST" \
  "$BLU"  "$short_path" "$RST" "$git_part"

# Tokens do CTX: "(used/total)" — só mostra se temos total > 0
ctx_tokens=""
if [ "$(printf '%.0f' "${ctx_total:-0}")" -gt 0 ] 2>/dev/null; then
  ctx_tokens=" ${GREY}(${RST}$(fmt_tokens "$ctx_used")${GREY}/${RST}$(fmt_tokens "$ctx_total")${GREY})${RST}"
fi

# Linha 2: CTX bar N% (used/total) | 5H bar | 7D bar
printf '%sCTX%s %s %s%s%%%s%s | %s5H%s %s %s %s%s%%%s | %s7D%s %s %s %s%s%%%s\n' \
  "$GREY" "$RST" "$(bar "$ctx_int")" "$ctx_c" "$ctx_int" "$RST" "$ctx_tokens" \
  "$GREY" "$RST" "$rl5_when"   "$(bar "$rl5_int")" "$rl5_c" "$rl5_int" "$RST" \
  "$GREY" "$RST" "$rl7_when"   "$(bar "$rl7_int")" "$rl7_c" "$rl7_int" "$RST"
