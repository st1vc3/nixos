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
