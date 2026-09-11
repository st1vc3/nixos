{
  inputs,
  lib,
  options,
  pkgs,
  ...
}:

let
  # The command nixpkgs would have used, read straight off the option
  # declaration so the weston.ini it generates from the libinput/xkb options
  # keeps tracking upstream instead of being copied here and drifting.
  upstreamCompositor = options.services.displayManager.sddm.wayland.compositorCommand.default;

  # SDDM's Wayland greeter is weston, which opens whichever /dev/dri/cardN it
  # enumerates first. Card numbering races between amdgpu (the Ryzen 780M iGPU)
  # and nvidia-drm (the RTX 4070 Ti the monitor is actually plugged into). When
  # the iGPU wins, weston opens a card whose connectors are all disconnected,
  # logs "Error: Could not enable any output" and exits - the greeter never
  # draws and the machine boots to a black screen. Hit on 2026-09-11.
  #
  # Pin weston to the card that actually has a display attached. Deliberately
  # driver-agnostic rather than hardcoding the NVIDIA PCI address, so it still
  # does the right thing if the monitor moves to the iGPU, a GPU is swapped, or
  # the cards get renumbered again.
  pickGpu = pkgs.writeShellScript "sddm-greeter-pick-gpu" ''
    # The greeter can start before nvidia-drm has finished probing, in which
    # case the connected connector does not exist yet. Poll for up to ~5s
    # rather than losing the race and giving up.
    attempt=0
    while [ "$attempt" -lt 50 ]; do
      for card in /sys/class/drm/card[0-9]*; do
        # The glob matches connectors (card2-DP-8) as well as cards; skip those.
        case "''${card##*/}" in
          *-*) continue ;;
        esac

        for connector in "$card"-*; do
          [ -r "$connector/status" ] || continue
          read -r status < "$connector/status"
          if [ "$status" = connected ]; then
            exec ${upstreamCompositor} --drm-device="''${card##*/}"
          fi
        done
      done

      attempt=$((attempt + 1))
      ${pkgs.coreutils}/bin/sleep 0.1
    done

    # Nothing connected anywhere. Fall back to weston's own choice rather than
    # refusing to start, so this wrapper can never be worse than the default.
    exec ${upstreamCompositor}
  '';
in
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
      wayland = {
        enable = true;
        compositorCommand = lib.mkForce "${pickGpu}";
      };
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
