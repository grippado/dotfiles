#!/bin/bash

echo '##################################################################'
echo '################  Installing Claude Code Configs  ################'
echo '##################################################################'

DFL="${HOME}/.dotfiles"
CLAUDE_DIR="${HOME}/.claude"

# Create ~/.claude directory if it doesn't exist
if [ ! -d "$CLAUDE_DIR" ]; then
    mkdir -p "$CLAUDE_DIR"
    echo "Created ~/.claude directory"
fi

# Symlink agnostic agents
if [ -d "$DFL/claude/agents" ] && [ "$(ls -A "$DFL/claude/agents" 2>/dev/null)" ]; then
    mkdir -p "$CLAUDE_DIR/agents"
    for agent in "$DFL/claude/agents"/*.md; do
        [ -f "$agent" ] || continue
        name=$(basename "$agent")
        target="$CLAUDE_DIR/agents/$name"
        # Don't overwrite if already exists and is not a symlink from dotfiles
        if [ -L "$target" ]; then
            rm "$target"
        elif [ -f "$target" ]; then
            echo "  Skipping agent '$name' (local file exists, not overwriting)"
            continue
        fi
        ln -s "$agent" "$target"
        echo "  Linked agent: $name"
    done
fi

# Symlink agnostic commands
if [ -d "$DFL/claude/commands" ] && [ "$(ls -A "$DFL/claude/commands" 2>/dev/null)" ]; then
    mkdir -p "$CLAUDE_DIR/commands"
    for cmd in "$DFL/claude/commands"/*.md; do
        [ -f "$cmd" ] || continue
        name=$(basename "$cmd")
        target="$CLAUDE_DIR/commands/$name"
        if [ -L "$target" ]; then
            rm "$target"
        elif [ -f "$target" ]; then
            echo "  Skipping command '$name' (local file exists, not overwriting)"
            continue
        fi
        ln -s "$cmd" "$target"
        echo "  Linked command: $name"
    done
fi

# Symlink agnostic skills
if [ -d "$DFL/claude/skills" ] && [ "$(ls -A "$DFL/claude/skills" 2>/dev/null)" ]; then
    mkdir -p "$CLAUDE_DIR/skills"
    for skill in "$DFL/claude/skills"/*.md; do
        [ -f "$skill" ] || continue
        name=$(basename "$skill")
        target="$CLAUDE_DIR/skills/$name"
        if [ -L "$target" ]; then
            rm "$target"
        elif [ -f "$target" ]; then
            echo "  Skipping skill '$name' (local file exists, not overwriting)"
            continue
        fi
        ln -s "$skill" "$target"
        echo "  Linked skill: $name"
    done
fi

# Merge base settings (agnostic only) if no settings.json exists yet
if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
    cp "$DFL/claude/settings.json" "$CLAUDE_DIR/settings.json"
    echo "  Copied base settings.json"
else
    echo "  settings.json already exists, skipping (manage manually)"
fi

# Symlink CLAUDE.md to home directory if it exists
if [ -f "$DFL/claude/CLAUDE.md" ]; then
    target="$HOME/CLAUDE.md"
    if [ -L "$target" ]; then
        rm "$target"
    elif [ -f "$target" ]; then
        echo "  Skipping ~/CLAUDE.md (local file exists, not overwriting)"
    fi
    if [ ! -f "$target" ]; then
        ln -s "$DFL/claude/CLAUDE.md" "$target"
        echo "  Linked ~/CLAUDE.md"
    fi
fi

echo "Claude Code configuration complete!"
