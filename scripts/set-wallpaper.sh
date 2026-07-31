#!/usr/bin/env bash
# Set the desktop wallpaper via awww (the wallpaper daemon, formerly swww).
#
# Usage:
#   set-wallpaper.sh [image]
#
# With no argument it uses red.png from the wallpaper repo, which home-manager
# syncs to ~/Pictures/wallpapers. Deployed by nix to ~/Scripts/set-wallpaper.sh.
#
# Safe to run from inside the Hyprland session (e.g. an exec-once) or over SSH -
# it discovers the Wayland display and starts awww-daemon if needed.
set -euo pipefail

WALLPAPER="${1:-$HOME/Pictures/wallpapers/abstract/red.png}"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# Outside the session WAYLAND_DISPLAY may be unset; find Hyprland's socket.
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
  for sock in "$XDG_RUNTIME_DIR"/wayland-[0-9]*; do
    case "$sock" in
      *.lock) continue ;;
    esac
    WAYLAND_DISPLAY="$(basename "$sock")"
    break
  done
  export WAYLAND_DISPLAY
fi

if [ -z "${WAYLAND_DISPLAY:-}" ]; then
  echo "set-wallpaper: no Wayland display found (is the compositor running?)" >&2
  exit 1
fi

if [ ! -f "$WALLPAPER" ]; then
  echo "set-wallpaper: image not found: $WALLPAPER" >&2
  exit 1
fi

# Start the wallpaper daemon if it isn't already up, then wait for its socket.
if ! pgrep -x awww-daemon >/dev/null 2>&1; then
  awww-daemon >/dev/null 2>&1 &
  for _ in $(seq 1 25); do
    [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY-awww-daemon.sock" ] && break
    sleep 0.2
  done
fi

awww img "$WALLPAPER"
