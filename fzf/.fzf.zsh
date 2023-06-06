# Setup fzf
# ---------
if [[ ! "$PATH" == */Users/grippado/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/Users/grippado/.fzf/bin"
fi

# Auto-completion
# ---------------
# [[ $- == *i* ]] && source "/Users/grippado/.fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "/Users/grippado/.fzf/shell/key-bindings.zsh"
