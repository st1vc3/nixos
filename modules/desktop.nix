{ inputs, pkgs, ... }:

{
  imports = [ inputs.silentSDDM.nixosModules.default ];

  programs = {
    hyprland = {
      enable = true;
      withUWSM = true;
    };
    hyprlock.enable = true;
    dconf.enable = true;

    silentSDDM = {
      enable = true;
      theme = "catppuccin-mocha";
      # Match the real desktop background instead of the theme's own default.
      # SDDM runs as its own system user before login, so it can't read
      # ~/Pictures/wallpapers (mode 0700) - copy the same file in at build time.
      backgrounds.wallpaper = "${inputs.wallpapers}/abstract/red.jpg";
      # SilentSDDM shows its own idle "lock screen" (clock + "press any key")
      # before the actual login form - two independent sections, each with
      # their own background/use-background-color, so both need setting or
      # you only see the real wallpaper after the first keypress.
      settings."LoginScreen" = {
        background = "red.jpg";
        # The theme's own default sets this true (solid background-color
        # fill), which silently wins over `background` since overrides are
        # appended as a second [LoginScreen] section, not a replacement -
        # without this, the image is copied in but never actually shown.
        "use-background-color" = false;
      };
      settings."LockScreen" = {
        background = "red.jpg";
        "use-background-color" = false;
      };
    };
  };

  services = {
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };

    gvfs.enable = true;

    # Removable-media backend. udisks2 exposes the mount/unmount D-Bus API and
    # polkit rules; udiskie (a per-user service in home/services.nix) listens
    # for hotplugged drives and mounts them under /run/media/$USER.
    udisks2.enable = true;
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  xdg.portal = {
    enable = true;
    config.hyprland = {
      default = [
        "hyprland"
        "gtk"
      ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };

  security.polkit.enable = true;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
  ];
}
