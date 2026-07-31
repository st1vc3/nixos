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

## Layout

| Path | Purpose |
|---|---|
| `flake.nix` / `flake.lock` | Inputs and the `nixos` system definition (pinned) |
| `disko.nix` | Declarative disk layout - **set the target `device` before use** |
| `configuration.nix` | System: boot, NVIDIA, Hyprland/SDDM, audio, packages, users |
| `hardware-configuration.nix` | Machine-specific, generated during install |
| `home.nix` | home-manager wiring (deploys `$HOME` files below) |
| `config/hypr/` | Hyprland + hyprlock + hypridle configs → `~/.config/hypr/` |
| `scripts/set-wallpaper.sh` | Wallpaper setter (awww) → `~/Scripts/` |
| `INSTALL.md` | Step-by-step install from the NixOS live ISO |

## Desktop

Hyprland (plain session, not UWSM) with: **waybar** (bar), **wofi** (launcher),
**swaync** (notifications), **hyprlock**/**hypridle** (lock + idle),
**hyprpolkitagent** (auth), **awww** (wallpaper), **hyprshot** (screenshots),
**nautilus**, **firefox**, **kitty**. Config lives in `config/hypr/`; wallpapers
sync from the `wallpapers` input to `~/Pictures/wallpapers`.

Set the wallpaper: `~/Scripts/set-wallpaper.sh` (default `red.png`) or `SUPER+F1`.

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
- Some Hyprland keybinds reference personal scripts under `~/.local/bin/` that
  are not (yet) tracked here; they no-op until those are added.
