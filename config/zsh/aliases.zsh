alias ls='eza --icons'
alias ll='eza -lh --icons --git'
alias la='eza -lah --icons --git'
alias tree='eza --tree --icons'

# Reuse ls completions for eza (avoids defining a separate completion function)
compdef eza=ls

alias cat='bat'

# =========================================================
# Core utilities
# =========================================================

alias grep='rg --color=auto'
alias diff='diff --color=auto'
alias df='df -h'

# =========================================================
# Navigation
# =========================================================

alias -- -='cd -'  # -- prevents - being parsed as a flag; cd - jumps to previous directory

# =========================================================
# Editor
# =========================================================

alias vim='nvim'
alias v='nvim'

# =========================================================
# Git
# =========================================================

alias glog='PAGER="less -F -X" git log'                              # -F quit if one screen, -X no clear on exit
alias gadog='PAGER="less -F -X" git log --all --decorate --oneline --graph'
alias gs="git status"
alias gd="git diff"

# =========================================================
# NIX
# =========================================================

rebuild() {
  sudo nixos-rebuild switch --flake "$HOME/nixos#nixos" || return
  # Package ownership can move commands between /run/current-system and the
  # Home Manager profile. Drop Zsh's cached absolute command paths afterward.
  rehash
}

# Activate a candidate without changing the boot default. Rebooting returns to
# the most recent `rebuild` generation if the candidate is unusable.
rebuild_test() {
  sudo nixos-rebuild test --flake "$HOME/nixos#nixos" || return
  rehash
}

generations() {
  nixos-rebuild list-generations
}

rollback_system() {
  sudo nixos-rebuild switch --rollback || return
  rehash
}

# =========================================================
# Claude Code
# =========================================================

# Launch Claude Code without the per-action permission prompts.
alias cc="claude --dangerously-skip-permissions"

# =========================================================
# misc
# =========================================================

alias ff="clear && fastfetch"
alias c="clear"
alias stream='mpv av://v4l2:/dev/video4 --fullscreen --demuxer-lavf-o=input_format=mjpeg,framerate=60 --profile=low-latency --untimed'
alias addon="~/Games/battlenet/drive_c/Program\ Files\ \(x86\)/World\ of\ Warcraft/_retail_/CurseBreaker"
