#!/usr/bin/env bash
# Set the desktop wallpaper via awww (the wallpaper daemon, formerly swww),
# then regenerate the matugen color scheme to match it (hyprlock, kitty,
# waybar, wofi - see config/matugen/) and live-reload the apps that support
# it. scripts/misc/wallpaper-picker calls this after an interactive pick.
#
# Usage:
#   set-wallpaper.sh [image]
#
# With no argument it uses red.jpg from the wallpaper repo, which home-manager
# syncs to ~/Pictures/wallpapers. Deployed by nix to ~/Scripts/set-wallpaper.sh.
#
# Safe to run from inside the Hyprland session (e.g. an exec-once) or over SSH -
# it discovers the Wayland display and starts awww-daemon if needed.
set -euo pipefail
shopt -s nullglob

WALLPAPER="${1:-$HOME/Pictures/wallpapers/abstract/red.jpg}"

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

# hyprctl (used below to pick up the matugen accent in window borders) needs
# its own instance signature, separate from WAYLAND_DISPLAY.
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -1)"
  export HYPRLAND_INSTANCE_SIGNATURE
fi

if [ ! -f "$WALLPAPER" ]; then
  echo "set-wallpaper: image not found: $WALLPAPER" >&2
  exit 1
fi

# Start the wallpaper daemon only if it isn't already responding. Using
# `awww query` (not pgrep) avoids spawning a second daemon that would abort
# because one is already bound to the socket.
if ! awww query >/dev/null 2>&1; then
  awww-daemon >/dev/null 2>&1 &
  for _ in $(seq 1 25); do
    awww query >/dev/null 2>&1 && break
    sleep 0.2
  done
fi

awww img "$WALLPAPER"

# Regenerate colors and hot-reload the apps that support it without a
# restart. hyprlock and wofi just re-read their color files next time they
# launch (a spawned-per-use client and an overlay respectively), so nothing
# to signal there.
#
# matugen picks its decoder from the file extension, so a mislabeled or
# corrupt image makes it hard-error - don't let that also abort wallpaper
# setting above, or skip reloading kitty/waybar for every other wallpaper.
if command -v matugen >/dev/null 2>&1; then
  if matugen image "$WALLPAPER" --source-color-index 0; then
    # `pgrep && pkill` at top level would trip `set -e` when the process
    # isn't running (pgrep's exit 1 isn't shielded there), so use `if`.
    if pgrep -x kitty >/dev/null 2>&1; then
      pkill -USR1 kitty
    fi
    if pgrep -x waybar >/dev/null 2>&1; then
      pkill -SIGUSR2 waybar
    fi
    if pgrep -x swaync >/dev/null 2>&1; then
      swaync-client --reload-css >/dev/null 2>&1 || true
    fi
    # Picks up the new accent color in hyprland.lua's window borders.
    # Best-effort: fine if this isn't a live session.
    hyprctl reload config-only >/dev/null 2>&1 || true
  else
    echo "set-wallpaper: matugen failed to generate a theme for $WALLPAPER (wallpaper is still set)" >&2
  fi
fi
