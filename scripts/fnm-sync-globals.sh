#!/usr/bin/env bash
# fnm-sync-globals — keep npm globals consistent across fnm node versions
#
# Common pain: npm globals don't follow you across node versions. Install
# something in v22, switch to v25, and it's gone. This script keeps a
# registry of "blessed" globals (~/.dotfiles-ai/npm-globals.txt) and ensures
# they're installed in every fnm-managed node version.
#
# Usage:
#   fnm-sync-globals                   # sync (install missing in all versions)
#   fnm-sync-globals sync              # same
#   fnm-sync-globals check             # report drift, no install (exit 1 if any)
#   fnm-sync-globals discover          # show which packages live in which versions
#   fnm-sync-globals auto-populate     # add to registry packages found in 2+ versions
#   fnm-sync-globals add <pkg>         # add to registry + sync
#   fnm-sync-globals list              # show registry
#
# Flags:
#   --quiet     suppress per-action output
#   --verbose   show npm install output
#
# Compatible with macOS default bash 3.2 (no associative arrays).

set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY="$REPO/npm-globals.txt"
NODE_VERS_DIR="$HOME/.local/share/fnm/node-versions"
TODAY=$(date +%Y-%m-%d)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/fnm-sync.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

QUIET=0
VERBOSE=0
CMD=""
ADD_PKG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --quiet)   QUIET=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    sync|check|discover|auto-populate|list) CMD="$1"; shift ;;
    add) CMD="add"; shift; ADD_PKG="${1:?missing package name}"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done
[ -z "$CMD" ] && CMD="sync"

log() { [ "$QUIET" -eq 1 ] || echo "$@"; }
info() { [ "$QUIET" -eq 1 ] || echo "  $@"; }

# ── Helpers ─────────────────────────────────────────────────────────────

list_versions() {
  [ -d "$NODE_VERS_DIR" ] || { echo "ERROR: $NODE_VERS_DIR not found" >&2; exit 1; }
  for d in "$NODE_VERS_DIR"/*/installation; do
    [ -d "$d" ] || continue
    basename "$(dirname "$d")"
  done
}

list_packages_in_version() {
  local ver="$1"
  local node_modules="$NODE_VERS_DIR/$ver/installation/lib/node_modules"
  [ -d "$node_modules" ] || return 0
  local entry name sub
  for entry in "$node_modules"/*; do
    [ -d "$entry" ] || continue
    name=$(basename "$entry")
    case "$name" in
      npm|corepack|.*) continue ;;
      @*)
        for sub in "$entry"/*; do
          [ -d "$sub" ] && echo "${name}/$(basename "$sub")"
        done ;;
      *) echo "$name" ;;
    esac
  done
}

build_pkg_version_map() {
  # Print "<pkg>\t<version>" per line for every (pkg, version) pair
  local v
  while read -r v; do
    [ -z "$v" ] && continue
    while IFS= read -r p; do
      [ -z "$p" ] && continue
      printf "%s\t%s\n" "$p" "$v"
    done < <(list_packages_in_version "$v")
  done < <(list_versions)
}

read_registry() {
  [ -f "$REGISTRY" ] || return 0
  grep -v '^[[:space:]]*#' "$REGISTRY" | grep -v '^[[:space:]]*$' | awk '{print $1}'
}

is_installed_in() {
  local ver="$1" pkg="$2"
  [ -d "$NODE_VERS_DIR/$ver/installation/lib/node_modules/$pkg" ]
}

ensure_registry_file() {
  if [ ! -f "$REGISTRY" ]; then
    cat > "$REGISTRY" <<'EOF'
# fnm-sync-globals registry
# One npm package per line. Lines starting with # are comments.
# Use scoped names like @scope/pkg for scoped packages.
# Add packages with: fnm-sync-globals add <pkg>
# Or auto-detect packages already installed in 2+ fnm versions:
#   fnm-sync-globals auto-populate
EOF
  fi
}

# ── Commands ────────────────────────────────────────────────────────────

cmd_discover() {
  log "[discover] scanning $NODE_VERS_DIR"
  build_pkg_version_map > "$TMP/map"
  echo "PACKAGE                          | COUNT | VERSIONS"
  echo "---------------------------------+-------+----------"
  # group by package, count, list versions
  sort "$TMP/map" | awk -F'\t' '
    {
      if ($1 != prev && prev != "") {
        printf "%-32s | %5d | %s\n", prev, count, vers
        count = 0; vers = ""
      }
      prev = $1; count++; vers = (vers ? vers " " : "") $2
    }
    END {
      if (prev != "") printf "%-32s | %5d | %s\n", prev, count, vers
    }
  ' | sort -t'|' -k2,2nr -k1,1
}

cmd_auto_populate() {
  ensure_registry_file
  log "[auto-populate] adding packages found in ≥2 fnm versions"
  build_pkg_version_map > "$TMP/map"

  # Get current registry (just package names)
  read_registry | sort -u > "$TMP/existing"

  # Find packages with count ≥2 not already in registry
  local added=0 skipped=0
  while IFS=$'\t' read -r pkg count; do
    if grep -qx "$pkg" "$TMP/existing"; then
      skipped=$((skipped+1))
      continue
    fi
    echo "$pkg  # auto-detected: present in $count versions ($TODAY)" >> "$REGISTRY"
    info "+ $pkg (in $count versions)"
    added=$((added+1))
  done < <(awk -F'\t' '{c[$1]++} END {for (p in c) if (c[p] >= 2) printf "%s\t%d\n", p, c[p]}' "$TMP/map")

  log "[auto-populate] added $added, skipped $skipped (already in registry)"
}

cmd_list() {
  ensure_registry_file
  log "[list] $REGISTRY"
  read_registry | sort -u | sed 's/^/  /'
}

cmd_add() {
  ensure_registry_file
  if read_registry | grep -qx "$ADD_PKG"; then
    info "$ADD_PKG already in registry"
  else
    echo "$ADD_PKG  # added manually ($TODAY)" >> "$REGISTRY"
    info "+ $ADD_PKG added to $REGISTRY"
  fi
  cmd_sync
}

cmd_sync() {
  ensure_registry_file
  read_registry | sort -u > "$TMP/pkgs"
  if [ ! -s "$TMP/pkgs" ]; then
    log "[sync] registry empty (run 'auto-populate' or 'add <pkg>')"
    return 0
  fi
  list_versions > "$TMP/versions"

  local n_pkgs n_vers total=0
  n_pkgs=$(wc -l < "$TMP/pkgs" | tr -d ' ')
  n_vers=$(wc -l < "$TMP/versions" | tr -d ' ')
  log "[sync] ensuring $n_pkgs package(s) across $n_vers node version(s)"

  local v p
  while IFS= read -r v; do
    [ -z "$v" ] && continue
    : > "$TMP/missing"
    while IFS= read -r p; do
      is_installed_in "$v" "$p" || echo "$p" >> "$TMP/missing"
    done < "$TMP/pkgs"

    if [ ! -s "$TMP/missing" ]; then
      info "✓ $v: all present"
      continue
    fi
    local n_missing; n_missing=$(wc -l < "$TMP/missing" | tr -d ' ')
    info "→ $v: installing $n_missing missing"
    while IFS= read -r p; do
      if [ "$VERBOSE" -eq 1 ]; then
        fnm exec --using="$v" npm install -g "$p"
      else
        if fnm exec --using="$v" npm install -g "$p" >/dev/null 2>&1; then
          info "  ✓ $p"
        else
          info "  ✗ $p (install failed)"
        fi
      fi
      total=$((total+1))
    done < "$TMP/missing"
  done < "$TMP/versions"
  log "[sync] done ($total install(s))"
}

cmd_check() {
  ensure_registry_file
  read_registry | sort -u > "$TMP/pkgs"
  [ ! -s "$TMP/pkgs" ] && { log "[check] registry empty"; return 0; }
  list_versions > "$TMP/versions"

  local drift=0 v p
  while IFS= read -r v; do
    [ -z "$v" ] && continue
    while IFS= read -r p; do
      if ! is_installed_in "$v" "$p"; then
        echo "  drift: $v missing $p"
        drift=$((drift+1))
      fi
    done < "$TMP/pkgs"
  done < "$TMP/versions"

  if [ "$drift" -eq 0 ]; then
    local n; n=$(wc -l < "$TMP/pkgs" | tr -d ' ')
    log "[check] ✓ all $n packages present in all versions"
    return 0
  else
    log "[check] ✗ $drift drift(s) (run 'fnm-sync-globals sync' to fix)"
    return 1
  fi
}

# ── Dispatch ────────────────────────────────────────────────────────────

command -v fnm >/dev/null || { echo "ERROR: fnm not in PATH" >&2; exit 1; }

case "$CMD" in
  sync)          cmd_sync ;;
  check)         cmd_check ;;
  discover)      cmd_discover ;;
  auto-populate) cmd_auto_populate ;;
  list)          cmd_list ;;
  add)           cmd_add ;;
  *) echo "unknown command: $CMD" >&2; exit 1 ;;
esac
