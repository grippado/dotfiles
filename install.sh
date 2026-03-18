#!/bin/bash

echo '
  ▄▀  █▄▄▄▄ ▄█ █ ▄▄  █ ▄▄  ██   ██▄   ████▄
▄▀    █  ▄▀ ██ █   █ █   █ █ █  █  █  █   █
█ ▀▄  █▀▀▌  ██ █▀▀▀  █▀▀▀  █▄▄█ █   █ █   █
█   █ █  █  ▐█ █     █     █  █ █  █  ▀████
 ███    █    ▐  █     █       █ ███▀
       ▀         ▀     ▀     █
                            ▀
██▄   ████▄    ▄▄▄▄▀ ▄████  ▄█ █     ▄███▄     ▄▄▄▄▄
█  █  █   █ ▀▀▀ █    █▀   ▀ ██ █     █▀   ▀   █     ▀▄
█   █ █   █     █    █▀▀    ██ █     ██▄▄   ▄  ▀▀▀▀▄
█  █  ▀████    █     █      ▐█ ███▄  █▄   ▄▀ ▀▄▄▄▄▀
███▀          ▀       █      ▐     ▀ ▀███▀
                       ▀
                                                       '

DFL="$(cd "$(dirname "$0")" && pwd)"

# Create secrets file if it doesn't exist
if [ ! -f "$HOME/.secrets" ]; then
    touch "$HOME/.secrets"
    echo "# Add your secrets here" > "$HOME/.secrets"
    echo "GITHUB_TOKEN=your_github_token_here" >> "$HOME/.secrets"
    echo "Created ~/.secrets file. Please add your secrets there."
fi

# Make scripts executable
chmod +x "$DFL/configs/secrets.sh"
chmod +x "$DFL/installers/"*.sh
chmod +x "$DFL/claude/install.sh" 2>/dev/null

# ── Core Setup ───────────────────────────────────────────────
source "$DFL/configs/git.sh"
source "$DFL/installers/package-manager.sh"
source "$DFL/installers/base.sh"
source "$DFL/installers/omzsh.sh"
source "$DFL/installers/fzf.sh"
source "$DFL/installers/zsh-plugins.sh"

# ── ZSH Configuration ───────────────────────────────────────
echo "Creating ZSH config files..."
rm -rf ~/.zshrc
touch ~/.zshrc
echo "#source zsh files" >> ~/.zshrc
echo "source $DFL/zsh/.zshrc_base" >> ~/.zshrc

# ── Local Overrides Scaffolding ──────────────────────────────
if [ ! -f "$HOME/.zshrc_local" ]; then
    cat > "$HOME/.zshrc_local" << 'LOCALEOF'
# Machine-specific ZSH configuration
# This file is NOT tracked by dotfiles — add your local overrides here.
#
# Examples:
#   export PATH="/opt/homebrew/Cellar/postgresql@15/15.12_1/bin:$PATH"
#   export GOROOT="/usr/local/go"
#   export GOPATH="$HOME/Documents/go"
#   export PATH="$GOPATH/bin:$GOROOT/bin:$PATH"
#   export JAVA_HOME="/opt/homebrew/opt/openjdk@21"
#   export PATH="$JAVA_HOME/bin:$PATH"

LOCALEOF
    echo "Created ~/.zshrc_local — add machine-specific paths and config there."
fi

if [ ! -f "$HOME/.zsh_aliases_local" ]; then
    cat > "$HOME/.zsh_aliases_local" << 'LOCALEOF'
# Machine-specific or org-specific aliases
# This file is NOT tracked by dotfiles — add your local aliases here.
#
# Examples (org-specific):
#   alias start-myapp='cd ~/projects/myapp && pnpm dev'
#   alias pnpmi="npx google-artifactregistry-auth && pnpm install"

LOCALEOF
    echo "Created ~/.zsh_aliases_local — add org-specific aliases there."
fi

if [ ! -f "$HOME/.zsh_functions_local" ]; then
    cat > "$HOME/.zsh_functions_local" << 'LOCALEOF'
# Machine-specific or org-specific functions
# This file is NOT tracked by dotfiles — add your local functions here.

LOCALEOF
    echo "Created ~/.zsh_functions_local — add org-specific functions there."
fi

# ── Claude Code Configuration ────────────────────────────────
if [ -f "$DFL/claude/install.sh" ]; then
    source "$DFL/claude/install.sh"
fi

echo '##################################################################'
echo '######################  Reload Configs  ##########################'
echo '##################################################################'

exec zsh -l

echo "Done!!"
