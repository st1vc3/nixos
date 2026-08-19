{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./gaming.nix
    ./git.nix
    ./neovim.nix
    ./packages.nix
    ./quickshell.nix
    ./services.nix
    ./theming.nix
  ];

  # Quickshell desktop shell (notch, notification centre, status widgets).
  # See home/quickshell.nix for its deployment and service.
  myShell.enable = true;

  home = {
    username = "stivce";
    homeDirectory = "/home/stivce";
    stateVersion = "26.05";

    file = {
      "Pictures/wallpapers".source = inputs.wallpapers;

      ".zshenv".text = ''
        export ZDOTDIR="$HOME/.config/zsh"
      '';

      "Scripts/set-wallpaper.sh" = {
        source = ../scripts/set-wallpaper.sh;
        executable = true;
      };

      # Paths below must match what config/hypr/hyprland.lua binds to.
      ".local/bin/misc/screenshot-region" = {
        source = ../scripts/misc/screenshot-region;
        executable = true;
      };
      ".local/bin/misc/screenshot-output-save" = {
        source = ../scripts/misc/screenshot-output-save;
        executable = true;
      };
      # Keep Claude Code and Codex aligned from one declarative source.
      ".claude/CLAUDE.md".source = ../config/agents/shared.md;
      ".codex/AGENTS.md".source = ../config/agents/shared.md;

      # Own Claude Code's settings declaratively. Interactive changes (e.g.
      # /model, /theme) no longer persist across rebuilds - this file is the
      # source of truth. settings.local.json stays unmanaged for machine-local
      # permission grants.
      #
      # The status line prints the active model plus context-window usage read
      # straight from the payload's .context_window.used_percentage field, e.g.
      # "Opus | ctx: 20% used". Kept as a single inline command to match the
      # macosx dotfiles repo.
      ".claude/settings.json".text = builtins.toJSON {
        model = "opus";
        tui = "fullscreen";
        theme = "dark-daltonized";
        skipDangerousModePermissionPrompt = true;
        statusLine = {
          type = "command";
          command = ''input=$(cat); model=$(echo "$input" | jq -r '.model.display_name'); used=$(echo "$input" | jq -r '.context_window.used_percentage // empty'); if [ -n "$used" ]; then printf "%s | ctx: %.0f%% used" "$model" "$used"; else printf "%s" "$model"; fi'';
        };
      };
    };

    # Matugen writes Hyprlock and Kitty colors straight to these paths at
    # runtime (scripts/set-wallpaper.sh), so Home Manager can't manage them
    # as symlinks - it would either fail to write through a read-only Nix
    # store target, or fight matugen for ownership on every rebuild. Instead
    # seed each one from its checked-in default exactly once; after that,
    # matugen (or its absence, if you never run the picker) fully owns them.
    activation.seedMatugenDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      seed() {
        if [[ ! -e "$1" ]]; then
          $DRY_RUN_CMD install $VERBOSE_ARG -Dm644 "$2" "$1"
        fi
      }
      seed "$HOME/.config/hypr/hyprlock-colors.conf" "${../config/matugen/defaults/hyprlock-colors.conf}"
      seed "$HOME/.config/kitty/colors.conf" "${../config/matugen/defaults/kitty-colors.conf}"
    '';
  };

  xdg.configFile = {
    "kitty" = {
      source = ../config/kitty;
      recursive = true;
    };
    # Plugins are supplied by programs.neovim above and pinned by flake.lock;
    # the configuration is immutable and never downloads code at runtime.
    "nvim/lua" = {
      source = ../config/nvim/lua;
      recursive = true;
    };
    "herdr" = {
      source = ../config/herdr;
      recursive = true;
    };
    "hyprquickframe/theme.toml".source = ../config/hyprquickframe/theme.toml;

    # Voice dictation. The daemon watches this file and reloads on change, and
    # never writes it back, so a read-only store symlink is safe. Its sibling
    # `env` file (the Groq key, see modules/dictation.nix) stays unmanaged.
    "hyprwhspr-rs/config.jsonc".source = ../config/hyprwhspr-rs/config.jsonc;

    # Base config owns the Hyprlock and Kitty mappings. When the shell is
    # enabled, append its template so Matugen also writes colors.json.
    # Keeping it conditional means a disabled shell leaves Matugen
    # generating exactly the original set of colour files.
    "matugen/config.toml".text =
      builtins.readFile ../config/matugen/config.toml
      + lib.optionalString config.myShell.enable ''

        [templates.quickshell-colors]
        input_path = "~/.config/matugen/templates/quickshell-colors.json"
        output_path = "~/.config/quickshell/colors.json"
      '';
    "matugen/templates" = {
      source = ../config/matugen/templates;
      recursive = true;
    };

    "zsh/.zshrc".source = ../config/zsh/zshrc;
    "zsh/zshenv".source = ../config/zsh/zshenv;
    "zsh/aliases.zsh".source = ../config/zsh/aliases.zsh;
    "zsh/fzf.zsh".source = ../config/zsh/fzf.zsh;
    "zsh/bindings.zsh".source = ../config/zsh/bindings.zsh;
    "zsh/prompt.zsh".source = ../config/zsh/prompt.zsh;
    "zsh/starship.toml".source = ../config/zsh/starship.toml;

    # Plugins are Nix-managed packages, not git-cloned at shell startup, so
    # they're pinned by the flake lock like everything else. See README's
    # "Plugins" list for what each one does.
    "zsh/plugins.zsh".text = ''
      source "${pkgs.zsh-autosuggestions}/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
      source "${pkgs.zsh-history-substring-search}/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh"
      source "${pkgs.zsh-vi-mode}/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh"
      source "${pkgs.zsh-fast-syntax-highlighting}/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
    '';

    "hypr/hyprland.lua".source = ../config/hypr/hyprland.lua;
    "hypr/hypridle.conf".source = ../config/hypr/hypridle.conf;
    "hypr/hyprlock.conf".source = ../config/hypr/hyprlock.conf;
    "hypr/start-hyprlock" = {
      source = ../config/hypr/start-hyprlock;
      executable = true;
    };

  };
}
