#!/usr/bin/env bash
# Varredura read-only de apps graficos e binarios CLI parados/pesados.
# Uso: scan.sh [dias_limiar]  (default: 60)
set -uo pipefail

THRESHOLD_DAYS="${1:-60}"
NOW_EPOCH=$(date +%s)
THRESHOLD_EPOCH=$(( NOW_EPOCH - THRESHOLD_DAYS * 86400 ))

LOGIN_ITEMS=$(osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null || echo "")
BREW_CASKS=$(brew list --cask 2>/dev/null || echo "")
BREW_FORMULAE=$(brew list --formula 2>/dev/null || echo "")

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr -s ' ' '-'
}

echo "=== Login items detectados ==="
echo "${LOGIN_ITEMS:-'(nenhum ou osascript sem permissao)'}"
echo ""

echo "=== Apps graficos (/Applications, ~/Applications) — limiar: ${THRESHOLD_DAYS} dias ==="
printf "%-32s %-8s %-12s %-14s %-9s %-10s %s\n" "NOME" "TAMANHO" "ULT_USO" "BREW_CASK?" "RODANDO" "LOGIN_ITEM" "SINAL"
for app in /Applications/*.app ~/Applications/*.app; do
  [ -d "$app" ] || continue
  name=$(basename "$app" .app)
  size=$(du -sh "$app" 2>/dev/null | cut -f1)
  last_raw=$(mdls -name kMDItemLastUsedDate -raw "$app" 2>/dev/null)
  if [[ -z "$last_raw" || "$last_raw" == "(null)" ]]; then
    last_display="nunca-registrado"
    last_epoch=0
  else
    last_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$last_raw" +%s 2>/dev/null || echo 0)
    last_display="${last_raw%% *}"
  fi
  running="nao"
  pgrep -qif "$name" 2>/dev/null && running="SIM"
  is_login="nao"
  [[ -n "$LOGIN_ITEMS" && "$LOGIN_ITEMS" == *"$name"* ]] && is_login="SIM"
  slug=$(slugify "$name")
  brew_cask="nao"
  [[ -n "$BREW_CASKS" && "$BREW_CASKS" == *"$slug"* ]] && brew_cask="SIM(cask)"
  sinal="—"
  if [[ "$running" == "SIM" || "$is_login" == "SIM" ]]; then
    sinal="EM USO (nao sugerir remocao)"
  elif [[ "$last_epoch" -lt "$THRESHOLD_EPOCH" ]]; then
    sinal="CANDIDATO"
  fi
  printf "%-32s %-8s %-12s %-14s %-9s %-10s %s\n" "$name" "$size" "$last_display" "$brew_cask" "$running" "$is_login" "$sinal"
done

echo ""
echo "=== Binarios CLI standalone (~/.local/bin, ~/bin) — limiar: ${THRESHOLD_DAYS} dias ==="
printf "%-32s %-8s %-12s %-9s %s\n" "NOME" "TAMANHO" "ULT_ACESSO" "RODANDO" "SINAL"
for dir in "$HOME/.local/bin" "$HOME/bin"; do
  [ -d "$dir" ] || continue
  for bin in "$dir"/*; do
    [ -f "$bin" ] || continue
    name=$(basename "$bin")
    size=$(du -sh "$bin" 2>/dev/null | cut -f1)
    atime=$(stat -f "%a" "$bin" 2>/dev/null || echo 0)
    last_display=$(stat -f "%Sa" -t "%Y-%m-%d" "$bin" 2>/dev/null || echo "?")
    running="nao"
    pgrep -qif "$name" 2>/dev/null && running="SIM"
    sinal="—"
    if [[ "$running" == "SIM" ]]; then
      sinal="EM USO (nao sugerir remocao)"
    elif [[ "$atime" -lt "$THRESHOLD_EPOCH" ]]; then
      sinal="CANDIDATO"
    fi
    printf "%-32s %-8s %-12s %-9s %s\n" "$name" "$size" "$last_display" "$running" "$sinal"
  done
done

echo ""
echo "=== Homebrew leaves (formulas explicitas, sem dependentes) — heuristica por atime do binario ==="
printf "%-32s %-12s %s\n" "FORMULA" "ULT_ACESSO" "SINAL"
BREW_BIN=$(brew --prefix 2>/dev/null)/bin
if [[ -n "$BREW_FORMULAE" ]]; then
  brew leaves 2>/dev/null | while read -r f; do
    cand="$BREW_BIN/$f"
    if [ -e "$cand" ]; then
      atime=$(stat -f "%a" "$cand" 2>/dev/null || echo 0)
      last_display=$(stat -f "%Sa" -t "%Y-%m-%d" "$cand" 2>/dev/null || echo "?")
      sinal="—"
      [[ "$atime" -lt "$THRESHOLD_EPOCH" ]] && sinal="candidato (confirmar - atime de symlink pode nao refletir uso real)"
      printf "%-32s %-12s %s\n" "$f" "$last_display" "$sinal"
    fi
  done
fi

echo ""
echo "NOTA: 'CANDIDATO' e apenas sinal heuristico. NUNCA remover sem confirmacao explicita do usuario item a item ou por lista revisada."
