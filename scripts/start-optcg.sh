#!/usr/bin/env bash
# Install and launch the newest OPTCGSim version found in the game directory.

set -euo pipefail

root="${OPTCG_ROOT:-$HOME/Games/OPTCGSim}"
mkdir -p "$root"

# Consider both installed directories and downloaded archives. Version sorting
# makes 1.52a_Linux newer than 1.42c_Linux without hard-coding the current
# release. The desktop entry always invokes this script, so it never needs a
# per-version update.
newest=$(
  {
    find "$root" -mindepth 1 -maxdepth 1 -type d -name '*_Linux' -printf '%f\n'
    find "$root" -mindepth 1 -maxdepth 1 -type f -name '*_Linux.zip' -printf '%f\n' |
      sed 's/\.zip$//'
  } | sort -Vu | tail -n1
)

if [[ -z "$newest" ]]; then
  echo "start-optcg: no OPTCGSim release found under $root" >&2
  echo "             place a <version>_Linux.zip archive there" >&2
  exit 1
fi

release_dir="$root/$newest"
build="$release_dir/Builds_Linux"
archive="$root/$newest.zip"

if [[ ! -f "$build/OPTCGSim.x86_64" ]]; then
  if [[ -e "$release_dir" ]]; then
    echo "start-optcg: incomplete release directory: $release_dir" >&2
    echo "             remove or repair it before launching" >&2
    exit 1
  fi
  if [[ ! -f "$archive" ]]; then
    echo "start-optcg: $newest has no runnable binary or matching ZIP" >&2
    exit 1
  fi
  if ! command -v unzip >/dev/null; then
    echo "start-optcg: unzip is not installed" >&2
    exit 1
  fi

  # Serialize extraction and publish the finished directory atomically. A
  # cancelled or failed unzip leaves no half-installed version for the next
  # launcher invocation to mistake for a valid release.
  exec 9>"$root/.extract.lock"
  flock 9
  if [[ ! -f "$build/OPTCGSim.x86_64" ]]; then
    temporary_dir=$(mktemp -d "$root/.extract-$newest.XXXXXX")
    cleanup() {
      rm -rf -- "$temporary_dir"
    }
    trap cleanup EXIT HUP INT TERM

    echo "start-optcg: installing $newest" >&2
    unzip -q "$archive" -d "$temporary_dir"
    if [[ ! -f "$temporary_dir/Builds_Linux/OPTCGSim.x86_64" ]]; then
      echo "start-optcg: $archive does not contain the expected Linux build" >&2
      exit 1
    fi
    mv -- "$temporary_dir" "$release_dir"
    trap - EXIT HUP INT TERM
  fi
fi

# The ZIP ships the binary without the executable bit.
[[ -x "$build/OPTCGSim.x86_64" ]] || chmod +x "$build/OPTCGSim.x86_64"

# Retain complete artifacts for only the newest two release names. A release
# can have both an archive and an extracted directory; those count as one
# version and are removed together when they rotate out.
mapfile -t versions < <(
  {
    find "$root" -mindepth 1 -maxdepth 1 -type d -name '*_Linux' -printf '%f\n'
    find "$root" -mindepth 1 -maxdepth 1 -type f -name '*_Linux.zip' -printf '%f\n' |
      sed 's/\.zip$//'
  } | sort -Vru
)
for ((i = 2; i < ${#versions[@]}; i++)); do
  old_version=${versions[$i]}
  # The list above only accepts direct children ending in _Linux. Keep that
  # invariant explicit at the destructive boundary as a final safety check.
  [[ "$old_version" == *_Linux && "$old_version" != */* ]] || continue
  echo "start-optcg: removing old release $old_version" >&2
  rm -rf -- "${root:?}/$old_version"
  rm -f -- "$root/$old_version.zip"
done

if ! command -v steam-run >/dev/null; then
  echo "start-optcg: steam-run not found - enable programs.steam in the NixOS config" >&2
  exit 1
fi

# One instance only, regardless of how the running copy was started.
if pgrep -u "$(id -u)" -f 'OPTCGSim\.x86_64' >/dev/null; then
  echo "start-optcg: OPTCGSim is already running" >&2
  exit 0
fi

echo "start-optcg: launching $newest" >&2

# A transient user service outlives the launcher process, and the fixed unit
# name makes simultaneous launch attempts converge on one instance.
if command -v systemd-run >/dev/null && [[ -d "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/systemd" ]]; then
  setenv=()
  for var in DISPLAY WAYLAND_DISPLAY XAUTHORITY XDG_RUNTIME_DIR XDG_SESSION_TYPE \
    XDG_CURRENT_DESKTOP DBUS_SESSION_BUS_ADDRESS; do
    [[ -n "${!var:-}" ]] && setenv+=("--setenv=$var=${!var}")
  done

  systemctl --user reset-failed optcg.service 2>/dev/null || true
  exec systemd-run --user --quiet --collect --unit=optcg \
    --description="OPTCGSim $newest" \
    --working-directory="$build" \
    "${setenv[@]}" \
    steam-run ./OPTCGSim.x86_64 "$@"
fi

# Fallback for environments without a user systemd manager.
log="${XDG_STATE_HOME:-$HOME/.local/state}/optcg.log"
mkdir -p "$(dirname "$log")"
cd "$build"
setsid -f steam-run ./OPTCGSim.x86_64 "$@" </dev/null >>"$log" 2>&1
