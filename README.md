# nixos

My NixOS installation, configured declaratively with [flakes](https://nixos.wiki/wiki/Flakes),
[disko](https://github.com/nix-community/disko), and
[home-manager](https://github.com/nix-community/home-manager).

## Machine

| | |
|---|---|
| Host | `nixos` |
| User | `stivce` |
| CPU | AMD (Ryzen, with iGPU) |
| GPU | NVIDIA RTX 4070 Ti - **open** kernel module (hybrid: iGPU + dGPU, display on NVIDIA) |
| Firmware | UEFI (systemd-boot) |
| Filesystem | btrfs (subvolumes `@`, `@home`, `@nix`, `@log`, `@snapshots`), unencrypted |
| Display | Hyprland (Wayland) + SDDM, monitor at 3840×2160 @ 240 Hz |

## Inputs

| Input | Purpose |
|---|---|
| `nixpkgs` | `nixos-26.05` (stable) |
| `nixpkgs-unstable` | Selected user applications not available on stable |
| `disko` | Declarative disk partitioning |
| `home-manager` | `release-26.05` - per-user `$HOME` state |
| `wallpapers` | [`st1vc3/wallpaper`](https://github.com/st1vc3/wallpaper), pinned (not a flake) |
| `silentSDDM` | [`uiriansan/SilentSDDM`](https://github.com/uiriansan/SilentSDDM) - SDDM theme |
| `hyprquickframe` | [`Ronin-CK/HyprQuickFrame`](https://github.com/Ronin-CK/HyprQuickFrame) - region screenshot UI |
| `zen-browser` / `helium` | Community flakes packaging the two browsers |

## Layout

| Path | Purpose |
|---|---|
| `flake.nix` / `flake.lock` | Inputs and the `nixos` system definition (pinned) |
| `configuration.nix` | Thin entry point: boot, network, locale, users + `imports` |
| `hardware-configuration.nix` | Machine-specific, generated during install |
| `disko.nix` | Declarative disk layout - **set the target `device` before use** |
| `modules/nvidia.nix` | NVIDIA graphics, kernel driver, and video environment |
| `modules/desktop.nix` | Hyprland, SDDM + SilentSDDM theme, portals, lock, fonts |
| `modules/audio.nix` | PipeWire |
| `modules/apps.nix` | Small set of system-wide CLI/recovery tools |
| `modules/gaming.nix` | Steam, GameMode, and libvirt system services |
| `modules/snapshots.nix` | Snapper schedule and bounded root-snapshot retention |
| `home/default.nix` | home-manager wiring |
| `home/stivce.nix` | User identity and shared configuration-file deployment |
| `home/packages.nix`, `home/services.nix`, `home/theming.nix`, `home/neovim.nix` | Focused user packages, services, toolkit theme, and editor modules |
| `home/quickshell.nix` | Quickshell option, config deployment, palette seed, and user service |
| `config/hypr/`, `config/quickshell/`, `config/kitty/`, `config/nvim/`, `config/herdr/`, `config/zsh/`, `config/hyprquickframe/` | Configs deployed to `~/.config/` |
| `config/matugen/` | Theme templates, startup defaults, and ownership documentation |
| `config/agents/shared.md` | Shared global instructions deployed to Claude Code and Codex |
| `scripts/set-wallpaper.sh` | Wallpaper setter (awww) + matugen retheme → `~/Scripts/` |
| `scripts/misc/` | Output and region screenshot helpers → `~/.local/bin/misc/` |
| `docs/installation.md` | Step-by-step install from the NixOS live ISO |
| `docs/snapshots.md` | Snapshot scope, existing-system migration, and routine commands |
| `docs/rollback.md` | Safe rebuild workflow and system/file recovery procedures |
| `docs/review/` | Review checklist and implementation history |

## Desktop

Hyprland runs through **UWSM**. **Quickshell** provides the notch/status shell,
app launcher, power menu, wallpaper picker, notification popups, and notification
centre. Supporting services include **hyprlock**/**hypridle**,
**hyprpolkitagent**, and **awww**. Home Manager ties the Quickshell, Awww,
wallpaper initialization, idle, and PolicyKit services to the graphical session.
Clipboard history is limited to 200 entries in the private per-login runtime
directory and is erased at logout, so copied secrets are not retained on disk
across sessions.

Screenshot bindings are `ALT+SHIFT+3` for the focused output,
`ALT+SHIFT+4` for an interactive region, and `ALT+SHIFT+5` for
**HyprQuickFrame**. `SUPER+M` exits through **hyprshutdown** and
`SUPER+SHIFT+Q` locks the session.

Wallpapers are pinned by the flake and exposed at `~/Pictures/wallpapers`.
The SDDM login screen uses the same default image through **SilentSDDM** with
the `catppuccin-mocha` theme.

Reset to the default wallpaper: `~/Scripts/set-wallpaper.sh` or `SUPER+SHIFT+F1`.
Power menu: `SUPER+ESCAPE`.

### Theme switcher

`SUPER+F1` opens the native Quickshell picker over everything in
`~/Pictures/wallpapers`. Picking an image applies it through Awww and runs
Matugen to regenerate a Material dark palette for Hyprlock, Kitty, Quickshell,
and Hyprland's accent colors. Kitty instances are updated live through their
remote-control sockets; Quickshell watches its palette file, and Hyprland is
reloaded after generation.

The generated files are writable runtime state. Home Manager seeds them once
from `config/matugen/defaults/`, then leaves them under Matugen's ownership, so
a rebuild does not reset the selected theme. See
[`config/matugen/README.md`](config/matugen/README.md) for the complete template
and ownership lifecycle.

## Install

See the **[installation guide](docs/installation.md)**.

## Rebuild after install

```bash
sudo nixos-rebuild switch --flake ~/nixos#nixos
```

The interactive shell also provides `rebuild_test` for a temporary activation,
`rebuild` for a permanent switch, `generations` to list recovery points, and
`rollback_system` for the immediately previous NixOS generation. See
[`docs/rollback.md`](docs/rollback.md) before relying on Snapper for file recovery.

Update pinned inputs (nixpkgs, home-manager, wallpapers), then rebuild:

```bash
nix flake update            # or: nix flake update wallpapers
sudo nixos-rebuild switch --flake ~/nixos#nixos
```

### `upgrade`

The interactive shell provides `upgrade` as a one-shot full update. It:

1. Refreshes all pinned inputs (`nix flake update`).
2. Auto-commits the refreshed `flake.lock`, so every upgrade is recorded in
   Git history with the date.
3. Builds the new generation with `nixos-rebuild boot` - it becomes the **boot
   default** but is *not* activated on the running system, so a bad kernel or
   driver only takes effect once you deliberately reboot.
4. Runs `nix-collect-garbage --delete-older-than 14d`, pruning old store paths
   while keeping the last two weeks of generations as rollback targets.

```bash
upgrade   # then reboot to run the new kernel
```

Because it uses `boot` rather than `switch`, **reboot afterwards** to pick up
kernel and driver changes. Adjust the `14d` retention or the `boot`/`switch`
choice in [`config/zsh/aliases.zsh`](config/zsh/aliases.zsh).

## Formatting and linting

`nix fmt` (wired to `nixfmt`, the RFC 166 formatter) enforces consistent
style. Check tracked Nix files before committing so unrelated paths such as a
local `result` symlink are not traversed:

```bash
nix fmt -- --check $(git ls-files '*.nix')
```

`nix flake check` validates that the flake still evaluates. For deeper
style/dead-code checks, run `statix check .` and `deadnix .`
(`nix run nixpkgs#statix -- check .` / `nix run nixpkgs#deadnix -- .` if not
installed).

## Notes

- **NVIDIA hybrid gotcha:** do **not** set `GBM_BACKEND` or `AQ_DRM_DEVICES` in
  the environment - they crash Hyprland's aquamarine backend on this box. With
  `hardware.nvidia.open = true` + modesetting, the NVIDIA card is auto-selected.
- **Fresh accounts start locked.** The installation guide sets the `stivce`
  password interactively before reboot, so no credential is stored in Git.
  SSH password and root logins are disabled; add an authorized key before
  expecting remote access.
