#!/usr/bin/env bash
# Claude Code statusLine v4 — 2 linhas, ANSI colors
#
# Layout:
#   linha 1: <model> | EFFORT: <lvl> | <path> [<branch> ↑N ↓N *N +N]
#   linha 2: CTX ▓▓░░░░░░░░ N% (used/total) | 5H HH:MM ▓▓░░ N% | 7D DD/MM ▓▓░░ N%
#
# Thresholds de cor:  0–49% verde · 50–69% laranja · 70–100% vermelho

input=$(cat)

# ─── parse input ─────────────────────────────────────────────────────────────
cwd=$(echo "$input"      | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input"    | jq -r '.model.display_name // .model.id // "?"')
ctx_pct=$(echo "$input"  | jq -r '.context_window.used_percentage // 0')
ctx_used=$(echo "$input" | jq -r '((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0))')
ctx_total=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
effort_in=$(echo "$input" | jq -r '.effort.level // empty' 2>/dev/null)
rl5_pct=$(echo "$input"  | jq -r '.rate_limits.five_hour.used_percentage // 0')
rl5_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // 0')
rl7_pct=$(echo "$input"  | jq -r '.rate_limits.seven_day.used_percentage // 0')
rl7_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // 0')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

now=$(date +%s)

# ─── cache fallback (rate-limits) ────────────────────────────────────────────
CACHE="$HOME/.claude/.statusline-cache.json"

to_int() { case "${1:-0}" in ''|null) echo 0 ;; *) echo "$1" ;; esac; }
rl5_pct=$(to_int "$rl5_pct")
rl5_reset=$(to_int "$rl5_reset")
rl7_pct=$(to_int "$rl7_pct")
rl7_reset=$(to_int "$rl7_reset")

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

if [ "$rl5_reset" != "0" ] || [ "$rl7_reset" != "0" ]; then
  printf '{"rl5_pct":%s,"rl5_reset":%s,"rl7_pct":%s,"rl7_reset":%s}\n' \
    "${rl5_pct:-0}" "${rl5_reset:-0}" "${rl7_pct:-0}" "${rl7_reset:-0}" \
    > "${CACHE}.tmp" 2>/dev/null && mv "${CACHE}.tmp" "$CACHE" 2>/dev/null
fi

# ─── ANSI colors ─────────────────────────────────────────────────────────────
GREY=$'\033[90m'
GRN=$'\033[32m'
ORG=$'\033[33m'   # laranja/amarelo
RED=$'\033[1;31m'
BLU=$'\033[34m'
CYA=$'\033[36m'
MAG=$'\033[35m'
RST=$'\033[0m'

# ─── threshold color ─────────────────────────────────────────────────────────
# 0-49% verde · 50-69% laranja · 70-100% vermelho
threshold_color() {
  local p=$1
  if   [ "$p" -ge 70 ] 2>/dev/null; then printf '%s' "$RED"
  elif [ "$p" -ge 50 ] 2>/dev/null; then printf '%s' "$ORG"
  else                                    printf '%s' "$GRN"
  fi
}

# ─── unicode progress bar ─────────────────────────────────────────────────────
# bar <pct> [width=10]
# Usa blocos Unicode: ▓ cheio · ░ vazio
# Cor automática por threshold: verde / laranja / vermelho
bar() {
  local pct=$1
  local width=${2:-10}
  local pct_int filled empty c i

  pct_int=$(printf '%.0f' "${pct:-0}")
  [ "$pct_int" -gt 100 ] 2>/dev/null && pct_int=100
  [ "$pct_int" -lt 0   ] 2>/dev/null && pct_int=0

  filled=$(awk -v p="$pct_int" -v w="$width" 'BEGIN{printf "%d", int(p * w / 100 + 0.5)}')
  empty=$(( width - filled ))

  if   [ "$pct_int" -ge 70 ] 2>/dev/null; then c="$RED"
  elif [ "$pct_int" -ge 50 ] 2>/dev/null; then c="$ORG"
  else                                          c="$GRN"
  fi

  printf '%s' "$c"
  i=0; while [ $i -lt $filled ]; do printf '▓'; i=$((i+1)); done
  printf '%s' "$RST$GREY"
  i=0; while [ $i -lt $empty  ]; do printf '░'; i=$((i+1)); done
  printf '%s' "$RST"
}

# ─── format tokens ───────────────────────────────────────────────────────────
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

case "$effort" in
  low)         eff_color="$GRN" ;;
  medium|med)  eff_color="$ORG" ;;
  high)        eff_color="$RED" ;;
  xhigh|max)   eff_color="$RED" ;;
  *)           eff_color="$GREY" ;;
esac

# ─── path ────────────────────────────────────────────────────────────────────
short_path="${cwd/#$HOME/~}"
[ -z "$short_path" ] && short_path="~"

# ─── git ─────────────────────────────────────────────────────────────────────
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

  # staged + unstaged (diff stats mais ricos)
  staged=0; unstaged=0; untracked=0
  while IFS= read -r line; do
    xy="${line:0:2}"
    index="${xy:0:1}"
    worktree="${xy:1:1}"
    [ "$line" = "" ] && continue
    # untracked
    [ "$index" = "?" ] && untracked=$((untracked+1)) && continue
    # staged (index modificado)
    [ "$index" != " " ] && [ "$index" != "?" ] && staged=$((staged+1))
    # unstaged (worktree modificado)
    [ "$worktree" != " " ] && [ "$worktree" != "?" ] && unstaged=$((unstaged+1))
  done < <(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)

  # montar o bloco git
  git_part=" ${GREY}[${RST}${GRN}${branch}${RST}"

  # ahead/behind
  [ "$ahead"  -gt 0 ] 2>/dev/null && git_part="${git_part} ${CYA}↑${ahead}${RST}"
  [ "$behind" -gt 0 ] 2>/dev/null && git_part="${git_part} ${CYA}↓${behind}${RST}"

  # staged (verde com ✚), unstaged (laranja com ~), untracked (cinza com ?)
  [ "$staged"    -gt 0 ] && git_part="${git_part} ${GRN}✚${staged}${RST}"
  [ "$unstaged"  -gt 0 ] && git_part="${git_part} ${ORG}~${unstaged}${RST}"
  [ "$untracked" -gt 0 ] && git_part="${git_part} ${GREY}?${untracked}${RST}"

  git_part="${git_part}${GREY}]${RST}"
fi

# ─── diff stats da sessão ────────────────────────────────────────────────────
# Só mostra se há mudanças acumuladas na sessão
diff_part=""
la=$(printf '%.0f' "${lines_added:-0}")
lr=$(printf '%.0f' "${lines_removed:-0}")
if [ "$la" -gt 0 ] || [ "$lr" -gt 0 ]; then
  diff_part=" ${GREY}·${RST}"
  [ "$la" -gt 0 ] && diff_part="${diff_part} ${GRN}+${la}${RST}"
  [ "$lr" -gt 0 ] && diff_part="${diff_part} ${RED}-${lr}${RST}"
fi

# ─── reset times ─────────────────────────────────────────────────────────────
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

# ─── pct helpers ─────────────────────────────────────────────────────────────
fmt_pct() { awk -v n="$1" 'BEGIN{printf "%.0f", n+0}'; }

ctx_int=$(fmt_pct "$ctx_pct")
rl5_int=$(fmt_pct "$rl5_pct")
rl7_int=$(fmt_pct "$rl7_pct")

ctx_c=$(threshold_color "$ctx_int")
rl5_c=$(threshold_color "$rl5_int")
rl7_c=$(threshold_color "$rl7_int")

# ─── ctx token display ───────────────────────────────────────────────────────
ctx_tokens=""
if [ "$(printf '%.0f' "${ctx_total:-0}")" -gt 0 ] 2>/dev/null; then
  ctx_tokens=" ${GREY}(${RST}$(fmt_tokens "$ctx_used")${GREY}/${RST}$(fmt_tokens "$ctx_total")${GREY})${RST}"
fi

# ─── render ──────────────────────────────────────────────────────────────────
# Linha 1: model | EFFORT lvl | path[git] · +N -N
printf '%s%s%s | %sEFFORT%s %s%s%s | %s%s%s%s%s\n' \
  "$GREY" "$model" "$RST" \
  "$GREY" "$RST" "$eff_color" "$effort" "$RST" \
  "$BLU"  "$short_path" "$RST" \
  "$git_part" "$diff_part"

# Linha 2: CTX ▓▓░░ N% (tok/total) | 5H HH:MM ▓▓░░ N% | 7D DD/MM ▓▓░░ N%
printf '%sCTX%s %s %s%s%%%s%s | %s5H%s %s %s %s%s%%%s | %s7D%s %s %s %s%s%%%s\n' \
  "$GREY" "$RST" "$(bar "$ctx_int")" "$ctx_c" "$ctx_int" "$RST" "$ctx_tokens" \
  "$GREY" "$RST" "$rl5_when" "$(bar "$rl5_int" 8)" "$rl5_c" "$rl5_int" "$RST" \
  "$GREY" "$RST" "$rl7_when" "$(bar "$rl7_int" 8)" "$rl7_c" "$rl7_int" "$RST"