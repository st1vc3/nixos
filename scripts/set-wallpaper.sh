#!/usr/bin/env bash
# Set the desktop wallpaper via awww (the wallpaper daemon, formerly swww),
# then regenerate the Matugen color scheme and live-reload applications that
# support it. The Quickshell wallpaper picker calls this after a pick.
#
# Usage:
#   set-wallpaper.sh [image]
#
# With no argument it uses red.jpg from the wallpaper repo, which home-manager
# syncs to ~/Pictures/wallpapers. Deployed by nix to ~/Scripts/set-wallpaper.sh.
#
# Safe to run from inside the Hyprland session or over SSH: it discovers the
# Wayland display and waits for the systemd-managed awww daemon to become ready.
set -euo pipefail
shopt -s nullglob

WALLPAPER="${1:-$HOME/Pictures/wallpapers/abstract/red.jpg}"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# Serialize the complete apply-and-retheme operation so rapid picker or service
# invocations cannot interleave Matugen output and application reloads.
exec 9>"$XDG_RUNTIME_DIR/wallpaper-change.lock"
if ! flock -w 10 9; then
  echo "set-wallpaper: another wallpaper change is still running" >&2
  exit 1
fi

if [ ! -r "$WALLPAPER" ]; then
  echo "set-wallpaper: image not found or unreadable: $WALLPAPER" >&2
  exit 1
fi

WALLPAPER="$(realpath -- "$WALLPAPER")"
if ! magick identify -- "$WALLPAPER" >/dev/null 2>&1; then
  echo "set-wallpaper: not a readable image: $WALLPAPER" >&2
  exit 1
fi

# SSH commands do not inherit the graphical environment, and at login this
# service can start before UWSM finalises the compositor's variables and its
# Wayland socket. Resolve WAYLAND_DISPLAY to a ready socket, preferring the
# variable UWSM imports into the user service manager and falling back to
# unambiguous socket discovery (the first or newest socket can target another
# seat). Returns non-zero until a usable socket exists so the wait loop below
# can retry - a startup race must not leave the desktop on the black default.
resolve_wayland_display() {
  if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    WAYLAND_DISPLAY="$(systemctl --user show-environment 2>/dev/null \
      | sed -n 's/^WAYLAND_DISPLAY=//p' | tail -1)"
  fi

  if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    local sock display
    local -a wayland_sockets=()
    for sock in "$XDG_RUNTIME_DIR"/wayland-[0-9]*; do
      display="$(basename "$sock")"
      # Match wayland-<N> exactly so awww's own wayland-<N>-awww-daemon.sock
      # and the wayland-<N>.lock file are not miscounted as extra seats.
      [[ "$display" =~ ^wayland-[0-9]+$ ]] || continue
      [ -S "$sock" ] && wayland_sockets+=("$display")
    done
    [ "${#wayland_sockets[@]}" -eq 1 ] && WAYLAND_DISPLAY="${wayland_sockets[0]}"
  fi

  [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]
}

if ! resolve_wayland_display; then
  for _ in $(seq 1 100); do
    sleep 0.1
    resolve_wayland_display && break
  done
fi
if ! resolve_wayland_display; then
  echo "set-wallpaper: no Wayland socket became ready within 10 seconds" >&2
  exit 1
fi
export WAYLAND_DISPLAY

# hyprctl (used below to pick up the matugen accent in window borders) needs its
# own instance signature; prefer the UWSM-imported value before socket lookup.
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  HYPRLAND_INSTANCE_SIGNATURE="$(systemctl --user show-environment 2>/dev/null \
    | sed -n 's/^HYPRLAND_INSTANCE_SIGNATURE=//p' | tail -1)"
fi

# Fall back to socket discovery when the imported signature is missing or stale.
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] \
    || [ ! -S "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock" ]; then
  hypr_instances=()
  for socket in "$XDG_RUNTIME_DIR"/hypr/*/.socket.sock; do
    [ -S "$socket" ] && hypr_instances+=("$(basename "$(dirname "$socket")")")
  done
  if [ "${#hypr_instances[@]}" -ne 1 ]; then
    echo "set-wallpaper: expected one Hyprland instance, found ${#hypr_instances[@]}" >&2
    exit 1
  fi
  HYPRLAND_INSTANCE_SIGNATURE="${hypr_instances[0]}"
fi
export HYPRLAND_INSTANCE_SIGNATURE

# The daemon is owned by awww.service. Account for the small gap between the
# process starting and its Wayland socket becoming ready without spawning an
# unmanaged duplicate.
if ! awww query >/dev/null 2>&1; then
  for _ in $(seq 1 100); do
    awww query >/dev/null 2>&1 && break
    sleep 0.05
  done
fi

if ! awww query >/dev/null 2>&1; then
  echo "set-wallpaper: awww.service did not become ready within 5 seconds" >&2
  exit 1
fi

# -t none: awww's default "simple" transition fades in over ~250-300ms at
# its default transition-step; this makes the swap immediate instead
# (matches hyprland.lua's no-anim layer rule for the same surface).
awww img -t none "$WALLPAPER"

# Regenerate colors and hot-reload the apps that support it. Wallpaper setting
# remains successful even when theming fails, but the script returns a warning
# status so its service and callers can report the partial failure.
theme_status=0
if ! command -v matugen >/dev/null 2>&1; then
  echo "set-wallpaper: Matugen is not installed (wallpaper is still set)" >&2
  theme_status=1
elif matugen image "$WALLPAPER" --source-color-index 0; then
  expected_outputs=(
    "$HOME/.config/hypr/hyprlock-colors.conf"
    "$HOME/.config/kitty/colors.conf"
  )
  [ ! -e "$HOME/.config/quickshell/.enabled" ] \
    || expected_outputs+=("$HOME/.config/quickshell/colors.json")

  for output in "${expected_outputs[@]}"; do
    if [ ! -s "$output" ]; then
      echo "set-wallpaper: Matugen output is missing or empty: $output" >&2
      theme_status=1
    fi
  done

  if [ "$theme_status" -eq 0 ]; then
    # A config reload (SIGUSR1 or otherwise) only affects text kitty prints
    # after the reload - it does NOT repaint content already on screen
    # (verified directly: an already-printed colored string stayed the old
    # color after SIGUSR1, but updated instantly via remote control). Each
    # `kitty` launch is normally its own process, hence one socket per PID
    # (see kitty.conf's listen_on) - broadcast to all of them.
    for sock in "$XDG_RUNTIME_DIR"/kitty/kitty-*; do
      [ -S "$sock" ] || continue
      kitten @ --to "unix:$sock" set-colors --all -- "$HOME/.config/kitty/colors.conf" >/dev/null 2>&1 || true
    done

    # Picks up the new accent color in hyprland.lua's window borders.
    # Best-effort: fine if this isn't a live session.
    hyprctl reload config-only >/dev/null 2>&1 || true
  fi
else
  echo "set-wallpaper: Matugen failed for $WALLPAPER (wallpaper is still set)" >&2
  theme_status=1
fi

exit "$theme_status"
