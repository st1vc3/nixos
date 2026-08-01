{ inputs, pkgs, lib, ... }:

{
  home.username = "stivce";
  home.homeDirectory = "/home/stivce";
  home.stateVersion = "26.05";
  home.file."Pictures/wallpapers".source = inputs.wallpapers;

  home.file.".zshenv".text = ''
    export ZDOTDIR="$HOME/.config/zsh"
  '';

  home.file."Scripts/set-wallpaper.sh" = {
    source = ../scripts/set-wallpaper.sh;
    executable = true;
  };

  # Power menu (SUPER+ESCAPE) and region-screenshot bindings (ALT+SHIFT+3/4),
  # ported from github.com/stivce/arch.dot to the ~/.local/bin layout that
  # config/hypr/hyprland.lua already expects.
  home.file.".local/bin/wofi-menu/powermenu" = {
    source = ../scripts/wofi-menu/powermenu;
    executable = true;
  };
  home.file.".local/bin/misc/screenshot-region" = {
    source = ../scripts/misc/screenshot-region;
    executable = true;
  };
  home.file.".local/bin/misc/screenshot-region-save" = {
    source = ../scripts/misc/screenshot-region-save;
    executable = true;
  };
  home.file.".local/bin/misc/wallpaper-picker" = {
    source = ../scripts/misc/wallpaper-picker;
    executable = true;
  };

  home.file.".claude/CLAUDE.md".source = ../config/AGENTS.md;

  # matugen writes hyprlock/kitty/waybar/wofi/swaync colors straight to these paths
  # at runtime (scripts/set-wallpaper.sh), so home-manager can't manage them
  # as symlinks - it would either fail to write through a read-only Nix
  # store target, or fight matugen for ownership on every rebuild. Instead
  # seed each one from its checked-in default exactly once; after that,
  # matugen (or its absence, if you never run the picker) fully owns them.
  home.activation.seedMatugenDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    seed() {
      if [[ ! -e "$1" ]]; then
        $DRY_RUN_CMD install $VERBOSE_ARG -Dm644 "$2" "$1"
      fi
    }
    seed "$HOME/.config/hypr/hyprlock-colors.conf" "${../config/matugen/defaults/hyprlock-colors.conf}"
    seed "$HOME/.config/kitty/colors.conf" "${../config/matugen/defaults/kitty-colors.conf}"
    seed "$HOME/.config/waybar/colors.css" "${../config/matugen/defaults/waybar-colors.css}"
    seed "$HOME/.config/wofi/colors.css" "${../config/matugen/defaults/wofi-colors.css}"
    seed "$HOME/.config/swaync/colors.css" "${../config/matugen/defaults/swaync-colors.css}"
  '';

  xdg.configFile = {
    "kitty" = {
      source = ../config/kitty;
      recursive = true;
    };
    "nvim" = {
      source = ../config/nvim;
      recursive = true;
    };
    "herdr" = {
      source = ../config/herdr;
      recursive = true;
    };
    "hyprquickframe/theme.toml".source = ../config/hyprquickframe/theme.toml;

    "matugen/config.toml".source = ../config/matugen/config.toml;
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

    "waybar/config.jsonc".source = ../config/waybar/config.jsonc;
    "waybar/style.css".source = ../config/waybar/style.css;

    "swaync/config.json".source = ../config/swaync/config.json;
    "swaync/style.css".source = ../config/swaync/style.css;

    "wofi/config".source = ../config/wofi/config;
    "wofi/style.css".source = ../config/wofi/style.css;
  };
}
