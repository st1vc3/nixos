# =========================================================
# Keybindings
# =========================================================

# zsh-vi-mode (plugins.zsh) sets up its own keymaps lazily on the first
# prompt and clobbers plain `bindkey` calls made earlier in .zshrc, so custom
# bindings live in its documented zvm_after_init hook instead.
function zvm_after_init() {
  # History substring search (requires zsh-history-substring-search plugin)
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
  bindkey -M vicmd 'k' history-substring-search-up
  bindkey -M vicmd 'j' history-substring-search-down

  # Delete the previous word. vi insert mode leaves both of these on
  # single-character deletes (Ctrl-Backspace arrives as ^H) or unbound
  # (Alt-Backspace as ^[^?, which otherwise falls through to the ^[ prefix
  # and merely switches to normal mode).
  bindkey '^[^?' backward-kill-word
  bindkey '^H' backward-kill-word

  # Ctrl-F: fzf file picker excluding hidden files (defined in fzf.zsh)
  bindkey '^F' _fzf_file_no_hidden

  # fzf binds these when `fzf --zsh` is sourced in .zshrc, but that runs
  # before zsh-vi-mode rebuilds its keymaps here - which wipes them and
  # leaves Ctrl-R on plain zsh reverse search. Re-apply them in the hook.
  bindkey '^R' fzf-history-widget
  bindkey '^T' fzf-file-widget
}
