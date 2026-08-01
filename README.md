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
| Filesystem | btrfs (subvolumes `@`, `@home`, `@nix`, `@log`), unencrypted |
| Display | Hyprland (Wayland) + SDDM, monitor at 3840×2160 @ 240 Hz |

## Inputs

| Input | Purpose |
|---|---|
| `nixpkgs` | `nixos-26.05` (stable) |
| `disko` | Declarative disk partitioning |
| `home-manager` | `release-26.05` - per-user `$HOME` state |
| `wallpapers` | [`st1vc3/wallpaper`](https://github.com/st1vc3/wallpaper), pinned (not a flake) |
| `silentSDDM` | [`uiriansan/SilentSDDM`](https://github.com/uiriansan/SilentSDDM) - SDDM theme |
| `hyprquickframe` | [`Ronin-CK/HyprQuickFrame`](https://github.com/Ronin-CK/HyprQuickFrame) - region screenshot UI |

## Layout

| Path | Purpose |
|---|---|
| `flake.nix` / `flake.lock` | Inputs and the `nixos` system definition (pinned) |
| `configuration.nix` | Thin entry point: boot, network, locale, users + `imports` |
| `hardware-configuration.nix` | Machine-specific, generated during install |
| `disko.nix` | Declarative disk layout - **set the target `device` before use** |
| `modules/nvidia.nix` | CPU microcode + NVIDIA graphics + GPU env |
| `modules/desktop.nix` | Hyprland, SDDM + SilentSDDM theme, portals, lock, fonts |
| `modules/audio.nix` | PipeWire |
| `modules/apps.nix` | System packages + Firefox + Starship |
| `home/default.nix` | home-manager wiring |
| `home/stivce.nix` | Per-user `$HOME` files (hypr, waybar, scripts, wallpaper) |
| `config/hypr/`, `config/waybar/`, `config/wofi/`, `config/swaync/`, `config/kitty/`, `config/nvim/`, `config/herdr/`, `config/zsh/`, `config/hyprquickframe/` | Configs deployed to `~/.config/` |
| `config/matugen/` | matugen config + templates (inputs to the theme switcher; see below) |
| `scripts/set-wallpaper.sh` | Wallpaper setter (awww) + matugen retheme → `~/Scripts/` |
| `scripts/wofi-menu/`, `scripts/misc/` | Power menu, region-screenshot, wallpaper-picker scripts → `~/.local/bin/` |
| `pkgs/cursebreaker.nix` | Custom package: WoW addon manager, not in nixpkgs |
| `INSTALL.md` | Step-by-step install from the NixOS live ISO |

## Desktop

Hyprland (via **UWSM**) with: **waybar** (bar), **wofi** (launcher),
**swaync** (notifications), **hyprlock**/**hypridle** (lock + idle),
**hyprpolkitagent** (auth), **awww** (wallpaper), **hyprshot** (full/output
screenshots), **hyprquickframe** (region screenshots, `ALT+SHIFT+3/4`),
**hyprshutdown** (graceful compositor exit, `SUPER+M`), **nautilus**,
**firefox**, **kitty**. Config lives in `config/hypr/`; wallpapers sync from
the `wallpapers` input to `~/Pictures/wallpapers`. Login screen themed with
**SilentSDDM** (`catppuccin-mocha`).

Reset to the default wallpaper: `~/Scripts/set-wallpaper.sh` or `SUPER+SHIFT+F1`.
Power menu: `SUPER+ESCAPE`.

### Theme switcher

`SUPER+F1` opens a wofi picker over everything in `~/Pictures/wallpapers`
(ported from [`stivce/arch.dot`](https://github.com/stivce/arch.dot)). Picking
one sets it and runs `matugen image` to regenerate a Material You palette for
hyprlock, kitty, and the waybar/wofi color partials, then reloads kitty
(`SIGUSR1`) and waybar (`SIGUSR2`) live. `config/matugen/` holds the templates
(Nix-managed, edit these); the generated files
(`~/.config/{hypr/hyprlock-colors.conf,kitty/colors.conf,waybar/colors.css,wofi/colors.css}`)
are seeded once from `config/matugen/defaults/` on first activation and then
left alone by home-manager - matugen fully owns them after that, so a
`nixos-rebuild switch` won't reset a theme you've already picked. swaync and
GTK/Qt apps aren't themed by this (upstream doesn't template them either).

## Install

See **[INSTALL.md](./INSTALL.md)**.

## Rebuild after install

```bash
sudo nixos-rebuild switch --flake ~/nixos#nixos
```

Update pinned inputs (nixpkgs, home-manager, wallpapers), then rebuild:

```bash
nix flake update            # or: nix flake update wallpapers
sudo nixos-rebuild switch --flake ~/nixos#nixos
```

## Notes

- **NVIDIA hybrid gotcha:** do **not** set `GBM_BACKEND` or `AQ_DRM_DEVICES` in
  the environment - they crash Hyprland's aquamarine backend on this box. With
  `hardware.nvidia.open = true` + modesetting, the NVIDIA card is auto-selected.
- **Default login is `stivce` / `changeme`** (`initialPassword` in
  `configuration.nix`, only applied on first account creation) - change it
  with `passwd` right after first login. This repo is public and SSH is
  enabled with password auth, so don't leave it as-is on an untrusted network.
