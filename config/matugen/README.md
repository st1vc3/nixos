# Matugen theme files

The wallpaper setter runs Matugen after Awww applies an image. Matugen derives a
Material dark palette from that image and renders the files in `templates/` to
writable paths below `~/.config`.

## Templates and runtime outputs

| Template | Runtime output | Consumer |
| --- | --- | --- |
| `hyprlock-colors.conf` | `~/.config/hypr/hyprlock-colors.conf` | Hyprlock and Hyprland accent colors |
| `kitty-colors.conf` | `~/.config/kitty/colors.conf` | Kitty |
| `quickshell-colors.json` | `~/.config/quickshell/colors.json` | Quickshell |

The Hyprlock and Kitty mappings live in `config.toml`. Home Manager appends the
Quickshell mapping only when `myShell.enable` is true, so disabling the shell
does not leave an unused output requirement.

## Checked-in defaults

Files in `defaults/` are startup seeds, not generated build artifacts. Home
Manager copies them into place only when the corresponding writable runtime
output does not exist. This gives every consumer a complete palette before the
first wallpaper selection while preserving the user's last generated theme
across rebuilds.

Runtime outputs deliberately cannot be ordinary Home Manager-managed symlinks:
their Nix store targets would be read-only, while Matugen must replace their
contents whenever the wallpaper changes. After the one-time seed, Matugen owns
the runtime files.

When adding or removing a themed consumer, update all of these together:

1. its template and checked-in default;
2. the template mapping in `config.toml` or Home Manager;
3. the seed activation in `home/stivce.nix` or `home/quickshell.nix`;
4. the expected-output check in `scripts/set-wallpaper.sh`.
