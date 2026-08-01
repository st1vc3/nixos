{ inputs, pkgs, ... }:

{
  imports = [ inputs.silentSDDM.nixosModules.default ];

  programs.hyprland.enable = true;
  programs.hyprland.withUWSM = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  programs.silentSDDM = {
    enable = true;
    theme = "catppuccin-mocha";
    # Match the real desktop background instead of the theme's own default.
    # SDDM runs as its own system user before login, so it can't read
    # ~/Pictures/wallpapers (mode 0700) - copy the same file in at build time.
    backgrounds.wallpaper = "${inputs.wallpapers}/abstract/red.jpg";
    settings."LoginScreen".background = "red.jpg";
  };

  programs.hyprlock.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  security.polkit.enable = true;
  programs.dconf.enable = true;
  services.gvfs.enable = true;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
  ];
}
