{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myShell;
in
{
  options.myShell.enable = lib.mkEnableOption ''
    the quickshell desktop shell (macOS-style notch, notification centre and
    status widgets). Quickshell is the desktop's notification daemon; disabling
    it intentionally leaves no notification implementation'';

  config = lib.mkMerge [
    {
      home.packages = lib.optionals cfg.enable [ pkgs.quickshell ];
    }

    (lib.mkIf cfg.enable {
      xdg.configFile = {
        # Deploy the complete tracked source tree recursively. New components
        # only need to be added to config/quickshell and staged in Git before a
        # flake build, rather than duplicated in a Nix file list.
        "quickshell" = {
          source = ../config/quickshell;
          recursive = true;
        };

        # Marker used by set-wallpaper.sh to require the Quickshell Matugen
        # output only while this module is enabled.
        "quickshell/.enabled".text = "";
      };

      # colors.json is written at runtime by matugen (the quickshell-colors
      # template is wired into config.toml from home/stivce.nix) and watched live
      # by Colors.qml, so home-manager must not own it as a read-only store
      # symlink. Seed the checked-in default exactly once; after that matugen -
      # or its absence, if the wallpaper picker is never run - owns it. Mirrors
      # seedMatugenDefaults in home/stivce.nix.
      home.activation.seedQuickshellColors = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [[ ! -e "$HOME/.config/quickshell/colors.json" ]]; then
          $DRY_RUN_CMD install $VERBOSE_ARG -Dm644 \
            ${../config/matugen/defaults/quickshell-colors.json} \
            "$HOME/.config/quickshell/colors.json"
        fi
      '';

      systemd.user.services.quickshell = {
        Unit = {
          Description = "Quickshell desktop shell";
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = lib.getExe pkgs.quickshell;
          Restart = "on-failure";
          RestartSec = 1;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    })
  ];
}
