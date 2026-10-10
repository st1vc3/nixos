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

# Full system upgrade: refresh pinned inputs and CurseForge, build successfully
# before committing those updates, then install the new generation as the *boot default*
# (activated on next reboot, so a bad kernel never touches the running system),
# then prune generations older than 14 days while keeping recent rollback
# targets. Reboot afterwards to run the new kernel.
upgrade() {
  local flake="$HOME/nixos"
  ( cd "$flake" && nix flake update ) || return
  nix run "$flake#update-curseforge" -- "$flake" || return
  nix build "$flake#nixosConfigurations.nixos.config.system.build.toplevel" --no-link || return
  git -C "$flake" add -- flake.lock pkgs/curseforge.nix || return
  git -C "$flake" diff --cached --quiet -- flake.lock pkgs/curseforge.nix
  local diff_result=$?
  if (( diff_result == 1 )); then
    git -C "$flake" commit -m "upgrade: refresh inputs and CurseForge $(date +%F)" -- flake.lock pkgs/curseforge.nix || return
  elif (( diff_result != 0 )); then
    return "$diff_result"
  fi
  sudo nixos-rebuild boot --flake "$flake#nixos" || return
  sudo nix-collect-garbage --delete-older-than 14d || return
  echo "Upgrade staged as boot default. Reboot to run the new kernel."
}

generations() {
  nixos-rebuild list-generations
}

rollback_system() {
  sudo nixos-rebuild switch --rollback || return
  rehash
}

# =========================================================
# AI agents
# =========================================================

alias cc="claude --dangerously-skip-permissions"
alias cx="codex --dangerously-bypass-approvals-and-sandbox"

# Launch or reattach to the persistent `cc` Herdr session on the lab
# controller. The server runs there, so agents keep working after the link
# drops; only the thin client is local, and it reads this machine's
# config/herdr/config.toml, so keybindings and theme stay the same.
rcc() {
  herdr --remote stivce@controller --session cc
}

# =========================================================
# misc
# =========================================================

alias ff="clear && fastfetch"
alias c="clear"
alias stream='mpv av://v4l2:/dev/video4 --fullscreen --demuxer-lavf-o=input_format=mjpeg,framerate=60 --profile=low-latency --untimed'
