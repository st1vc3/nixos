# =========================================================
# Keybindings
# =========================================================

# History substring search (requires zsh-history-substring-search plugin)
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

# Ctrl-F: fzf file picker excluding hidden files (defined in fzf.zsh)
bindkey '^F' _fzf_file_no_hidden
