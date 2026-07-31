{ inputs, ... }:

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

  home.file.".claude/CLAUDE.md".source = ../config/AGENTS.md;

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

    "zsh/.zshrc".source = ../config/zsh/zshrc;
    "zsh/zshenv".source = ../config/zsh/zshenv;
    "zsh/aliases.zsh".source = ../config/zsh/aliases.zsh;
    "zsh/fzf.zsh".source = ../config/zsh/fzf.zsh;
    "zsh/bindings.zsh".source = ../config/zsh/bindings.zsh;
    "zsh/plugins.zsh".source = ../config/zsh/plugins.zsh;
    "zsh/prompt.zsh".source = ../config/zsh/prompt.zsh;
    "zsh/starship.toml".source = ../config/zsh/starship.toml;

    "hypr/hyprland.lua".source = ../config/hypr/hyprland.lua;
    "hypr/hypridle.conf".source = ../config/hypr/hypridle.conf;
    "hypr/hyprlock.conf".source = ../config/hypr/hyprlock.conf;
    "hypr/hyprlock-colors.conf".source = ../config/hypr/hyprlock-colors.conf;
    "hypr/start-hyprlock" = {
      source = ../config/hypr/start-hyprlock;
      executable = true;
    };

    "waybar/config.jsonc".source = ../config/waybar/config.jsonc;
    "waybar/style.css".source = ../config/waybar/style.css;
  };
}
