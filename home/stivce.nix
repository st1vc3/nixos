{ inputs, ... }:

{
  home.username = "stivce";
  home.homeDirectory = "/home/stivce";
  home.stateVersion = "26.05";
  home.file."Pictures/wallpapers".source = inputs.wallpapers;

  home.file."Scripts/set-wallpaper.sh" = {
    source = ../scripts/set-wallpaper.sh;
    executable = true;
  };

  xdg.configFile = {
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
