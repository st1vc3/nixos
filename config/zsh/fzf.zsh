# =========================================================
# fzf
# =========================================================

# strip-cwd-prefix removes the leading ./ from results. Exclude repository
# metadata even when hidden files are included.
export FZF_DEFAULT_COMMAND='fd --type f --hidden --strip-cwd-prefix --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

export FZF_DEFAULT_OPTS='
  --height=60%
  --layout=reverse
  --border=rounded
  --prompt="  "
  --pointer="  "
  --preview-window=right:65%:wrap:border-left
'

export _FZF_PREVIEW_CMD='bat --color=always --style=plain,numbers --line-range=:500 -- {}'
export FZF_CTRL_T_OPTS="--preview '$_FZF_PREVIEW_CMD'"

# Ctrl+F: file picker excluding hidden files
_fzf_file_no_hidden() {
  local result
  local -a fd_command=(fd --type f --strip-cwd-prefix --exclude .git)
  result=$("${fd_command[@]}" | fzf --preview "$_FZF_PREVIEW_CMD") \
    && LBUFFER+="${(q)result}"  # Quote the selected path for safe shell insertion.
  zle reset-prompt
}
zle -N _fzf_file_no_hidden
