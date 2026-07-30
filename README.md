# nixos

My NixOS installation, configured declaratively with [flakes](https://nixos.wiki/wiki/Flakes)
and [disko](https://github.com/nix-community/disko).

## Machine

| | |
|---|---|
| Host | `nixos` |
| User | `stivce` |
| CPU | AMD |
| GPU | NVIDIA |
| Firmware | UEFI (systemd-boot) |
| Filesystem | btrfs (subvolumes `@`, `@home`, `@nix`, `@log`), unencrypted |
| Desktop | Hyprland (Wayland) + SDDM |

## Layout

| File | Purpose |
|---|---|
| `flake.nix` | Inputs (nixpkgs unstable, disko) and the `nixos` system definition |
| `disko.nix` | Declarative disk layout - **set the target `device` before use** |
| `configuration.nix` | System config: boot, NVIDIA, Hyprland, audio, users, etc. |
| `hardware-configuration.nix` | Regenerated per-machine during install (placeholder in repo) |
| `INSTALL.md` | Step-by-step install from the NixOS live ISO |

## Install

See **[INSTALL.md](./INSTALL.md)**.

## Rebuild after install

```bash
sudo nixos-rebuild switch --flake ~/nixos#nixos
```
