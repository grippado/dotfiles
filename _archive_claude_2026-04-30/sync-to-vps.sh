#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# Sync Claude Code configs from LOCAL machine → VPS
#
# Run this from your LOCAL machine (macOS).
# Syncs: global agents/commands, project configs, memory, MCPs.
#
# Usage:
#   ~/.dotfiles/claude/sync-to-vps.sh [host]
#   ~/.dotfiles/claude/sync-to-vps.sh       # defaults to "hq"
#   ~/.dotfiles/claude/sync-to-vps.sh hq
# ──────────────────────────────────────────────────────────────

VPS_HOST="${1:-hq}"
LOCAL_CLAUDE="${HOME}/.claude"
LOCAL_PROJECT="${HOME}/www/personal/flagbridge"

# Resolve remote home dir via SSH
REMOTE_HOME="$(ssh "${VPS_HOST}" 'echo $HOME')"
REMOTE_CLAUDE="${REMOTE_HOME}/.claude"
REMOTE_WORKSPACE="${REMOTE_HOME}/www/flagbridge"

echo ">>> Syncing Claude Code configs to ${VPS_HOST}..."
echo "    Remote home: ${REMOTE_HOME}"
echo "    Remote workspace: ${REMOTE_WORKSPACE}"

# ── 1. Global CLAUDE.md ─────────────────────────────────────
echo ">>> [1/6] Global CLAUDE.md..."
ssh "${VPS_HOST}" "mkdir -p ${REMOTE_CLAUDE}"
scp "${LOCAL_CLAUDE}/CLAUDE.md" "${VPS_HOST}:${REMOTE_CLAUDE}/CLAUDE.md"

# ── 2. Global settings ──────────────────────────────────────
echo ">>> [2/6] Global settings..."
scp "${LOCAL_CLAUDE}/settings.json" "${VPS_HOST}:${REMOTE_CLAUDE}/settings.json"
scp "${LOCAL_CLAUDE}/settings.local.json" "${VPS_HOST}:${REMOTE_CLAUDE}/settings.local.json"

# ── 3. Local agents (non-symlink, FlagBridge-specific) ──────
echo ">>> [3/6] Local agents..."
ssh "${VPS_HOST}" "mkdir -p ${REMOTE_CLAUDE}/agents"

# These are local agents, not from dotfiles (dotfiles install.sh handles the symlinked ones)
for agent in context-keeper doc-writer git-assistant memory-extractor refactor-scout; do
  src="${LOCAL_CLAUDE}/agents/${agent}.md"
  if [ -f "${src}" ] || [ -L "${src}" ]; then
    # Resolve symlinks and copy actual content
    scp "$(readlink -f "${src}" 2>/dev/null || echo "${src}")" \
      "${VPS_HOST}:${REMOTE_CLAUDE}/agents/${agent}.md"
    echo "  Copied agent: ${agent}"
  fi
done

# ── 4. Local commands (non-symlink) ─────────────────────────
echo ">>> [4/6] Local commands..."
ssh "${VPS_HOST}" "mkdir -p ${REMOTE_CLAUDE}/commands"

for cmd in qa ship; do
  src="${LOCAL_CLAUDE}/commands/${cmd}.md"
  if [ -f "${src}" ]; then
    scp "${src}" "${VPS_HOST}:${REMOTE_CLAUDE}/commands/${cmd}.md"
    echo "  Copied command: ${cmd}"
  fi
done

# ── 5. FlagBridge project configs ───────────────────────────
echo ">>> [5/6] FlagBridge project configs..."

# Workspace-level files
ssh "${VPS_HOST}" "mkdir -p ${REMOTE_WORKSPACE}/.claude/commands"

for f in CLAUDE.md CONTEXT.md CONTROL.md docker-compose.yml flagbridge.code-workspace .gitignore; do
  src="${LOCAL_PROJECT}/${f}"
  if [ -f "${src}" ]; then
    scp "${src}" "${VPS_HOST}:${REMOTE_WORKSPACE}/${f}"
    echo "  Copied: ${f}"
  fi
done

# Project .claude/ directory
scp "${LOCAL_PROJECT}/.claude/settings.local.json" \
  "${VPS_HOST}:${REMOTE_WORKSPACE}/.claude/settings.local.json"
echo "  Copied: .claude/settings.local.json"

# Project commands (all 17)
rsync -av --delete \
  "${LOCAL_PROJECT}/.claude/commands/" \
  "${VPS_HOST}:${REMOTE_WORKSPACE}/.claude/commands/"
echo "  Synced: .claude/commands/ ($(ls "${LOCAL_PROJECT}/.claude/commands/" | wc -l | tr -d ' ') files)"

# ── 6. Memory files ─────────────────────────────────────────
echo ">>> [6/6] Memory files..."

# Claude Code auto-resolves the project memory path based on the working directory.
# On VPS the path encodes the absolute workspace path with dashes instead of slashes.
# e.g. /home/grippado/www/flagbridge → -home-grippado-www-flagbridge
REMOTE_MEMORY_PATH=$(echo "${REMOTE_WORKSPACE}" | sed 's|/|-|g')
REMOTE_MEMORY_BASE="${REMOTE_CLAUDE}/projects/${REMOTE_MEMORY_PATH}/memory"

echo "  Memory path on VPS: ${REMOTE_MEMORY_BASE}"
ssh "${VPS_HOST}" "mkdir -p '${REMOTE_MEMORY_BASE}'"

LOCAL_MEMORY="${LOCAL_CLAUDE}/projects/-Users-grippado-www-personal-flagbridge/memory"
rsync -av \
  "${LOCAL_MEMORY}/" \
  "${VPS_HOST}:${REMOTE_MEMORY_BASE}/"
echo "  Synced: $(ls "${LOCAL_MEMORY}" | wc -l | tr -d ' ') memory files"

echo "
>>> Sync complete!
    To start working: ssh hq && cd ~/www/flagbridge && claude
    To re-sync:       ~/.dotfiles/claude/sync-to-vps.sh
"
