# Configuration review handoff

Last updated: 2026-08-03

## Working agreement

- Work through `tofix` one item at a time.
- Explain the proposed change and wait for approval before implementing it.
- Preserve unrelated working-tree changes and do not commit automatically.

## Completed review items

1. Hardened the lock screen to fail closed, serialize captures, use a fallback,
   and clean up temporary screenshots.
2. Bounded notification history and visible popups, added queuing and stable
   identities, and verified a burst of 20 notifications.
3. Added Quickshell and Awww user services plus wallpaper initialization.
4. Made Neovim plugins reproducible through Home Manager and removed runtime
   Lazy installation state.
5. Exposed the flake-pinned Disko package and added installation preflight
   checks.
6. Made Quickshell deployment recursive and formatted the Nix files.
7. Separated system and user package ownership.
8. Removed silent Hyprland Lua error suppression.
9. Implemented the requested Alt+Shift screenshot bindings and hardened the
   screenshot scripts.
10. Corrected the GNOME Calendar matching rule and verified centered floating.
11. Removed duplicate Hypridle and policy-agent startup in favor of explicit
    Home Manager services.
12. Hardened wallpaper application with locking, validation, service readiness,
    Matugen output checks, and correct runtime paths.
13. Replaced Wofi with native Quickshell app launcher, power menu, and wallpaper
    picker. Removed Wofi packages, scripts, configuration, and templates.
14. Added keyboard navigation to the power menu and wallpaper picker. The
    deployed files did not initially take effect because Quickshell had not
    reloaded; restarting `quickshell.service` resolved it.
15. Shell cleanup approved with a reduced scope:
    - `GPG_TTY` is set only for an interactive terminal.
    - Completion checks and excludes insecure completion directories while
      retaining the cached XDG completion dump.
    - FZF excludes `.git`, avoids `eval`, safely quotes selected paths, and uses
      `--` for preview paths.
    - Optional FZF, Zoxide, and Starship integrations are guarded.
    - Zsh and Bash interactive/non-interactive startup tests passed.

The user explicitly asked to leave the `grep=rg` alias, NVM configuration, and
CurseBreaker addon alias unchanged.
16. Cleaned up the Neovim configuration:
    - Removed the duplicate system-level Neovim package; Home Manager remains
      its sole owner.
    - Restored Escape's normal cancel behavior and moved save to `<leader>w`.
    - Replaced the raw visual-mode paste command with `vim.keymap.set` while
      preserving the clipboard-safe behavior.
    - Verified the updated configuration in an isolated headless startup.
17. Removed Waybar completely: package, configuration, Hyprland startup/layer
    rules, Matugen output, wallpaper reload handling, and fallback wording.
    Nix evaluation confirms no Waybar package or deployed config remains.
18. Removed SwayNC completely: conditional package fallback, configuration,
    Hyprland startup/layer rules, Matugen output, and wallpaper reload handling.
    Quickshell is now the sole notification implementation. Nix evaluation
    confirms no SwayNC package or deployed config remains.
19. Documented the Matugen template/default/runtime ownership lifecycle in
    `config/matugen/README.md`, corrected seed-file wording, and clarified the
    Home Manager mapping comments. TOML parsing, JSON structure, template/default
    pairing, and the final rendered configuration all passed validation.
20. Updated `README.md` for the current Quickshell desktop, services, bindings,
    repository layout, inputs, and Matugen behavior. Corrected the installation
    guide so
    the installer checkout is preserved before reboot and moved into the user's
    home with correct ownership afterward. All documented paths and stale-name
    checks passed.
21. Replaced the plain-text `tofix` list with `docs/review/todo.md`, preserving completed
    review history and the established order of the four remaining tasks.
22. Made the machine-specific hardware configuration the sole owner of the
    explicit AMD microcode setting and removed the duplicate from the NVIDIA
    module. AMD microcode and redistributable firmware both evaluate enabled.
23. Configured the Hyprland portal preference order explicitly: Hyprland first,
    GTK fallback, with GTK forced for file picking. Removed the duplicate GTK
    provider; evaluation now contains exactly one Hyprland and one GTK backend,
    and the generated `hyprland-portals.conf` matches the intended routing.
24. Added a dedicated `@snapshots` subvolume mounted at `/.snapshots`, a Snapper
    root configuration with bounded hourly/daily/weekly/monthly and numbered
    retention, and `docs/snapshots.md` covering scope, migration, and routine use.
    The evaluated mount and Snapper config pass, and the full NixOS closure built
    successfully at `/nix/store/5mfkvch34jmjm069n6044lyn1v22pm47-nixos-system-nixos-26.05.20260730.21ea275`.
25. Added an explicit rollback strategy with temporary test activation,
    generation listing, previous-generation rollback helpers, systemd-boot and
    specific-generation recovery, Git-state guidance, and scoped Snapper file
    recovery. Shell parsing/loading passed and the final system closure built at
    `/nix/store/2x5jx8268c8wsbbfiaca10by65y37dq0-nixos-system-nixos-26.05.20260730.21ea275`.

## Current state

- The shell changes build successfully as part of the full NixOS closure:
  `/nix/store/v8kyf62ylrd3g5z8ysg4shdv6wlg1zh7-nixos-system-nixos-26.05.20260730.21ea275`
- `zsh -n`, interactive Zsh, non-interactive Zsh, interactive Bash,
  non-interactive Bash, and `git diff --check` passed.
- The latest shell changes have not yet been activated. Run `rebuild` before
  judging the live shell behavior.
- The worktree is intentionally dirty and contains all review work. Do not
  reset or discard it.
- Some newly added files are staged because Nix flakes ignore wholly untracked
  source files. Nothing has been committed.

## Resume point

All items in `docs/review/todo.md` are complete. The existing installation still needs the
one-time `@snapshots` migration documented in `docs/snapshots.md` before activating
the new system closure.

After that, continue in this order:

No review items remain.
