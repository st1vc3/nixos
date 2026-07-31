# Desktop: Hyprland (Wayland) + SDDM (SilentSDDM theme), portals, lock, fonts,
# and the GTK/polkit integration bits.
{ inputs, pkgs, ... }:

{
  imports = [ inputs.silentSDDM.nixosModules.default ];

  # Compositor.
  programs.hyprland.enable = true;
  # UWSM's systemd user session fails to start here (bindpid unit exit 5),
  # blocking Hyprland before it launches. Use the plain Hyprland session,
  # which execs the compositor directly and is simpler to debug.
  programs.hyprland.withUWSM = false;

  # Login manager (Wayland greeter).
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # SilentSDDM theme (github:uiriansan/SilentSDDM). The module switches SDDM to
  # the Qt6 build, sets theme = "silent", and pulls the Qt6 deps + greeter env.
  programs.silentSDDM = {
    enable = true;
    theme = "catppuccin-mocha";
  };

  # Screen locker - the module wires up the PAM stack hyprlock needs.
  programs.hyprlock.enable = true;

  # A portal so screen-sharing / file pickers work under Hyprland.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Polkit + GTK/dconf + gvfs so the auth agent and nautilus (trash, mounts,
  # thumbnails, GSettings) all work properly.
  security.polkit.enable = true;
  programs.dconf.enable = true;
  services.gvfs.enable = true;

  # Fonts, including a Nerd Font for waybar/terminal glyphs (fc-cache provided
  # by fontconfig, which fonts.packages enables).
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
  ];
}
