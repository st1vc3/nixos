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
      # Clipboard history backend for the launcher's `cli` mode. cliphist keeps
      # a persistent history that wl-paste feeds; the launcher lists and
      # re-copies entries through it.
      home.packages = [
        pkgs.cliphist
        pkgs.wl-clipboard
      ];

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

      # Runtime state the shell writes itself (currently the notification
      # centre's do-not-disturb flag). Quickshell's FileView creates the file
      # but not its parent directory, so claim the directory here.
      home.file.".local/state/quickshell/.keep".text = "";

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

      # Persist clipboard history. Two watchers are the upstream-recommended
      # setup: wl-paste emits per MIME class, so text and image need separate
      # subscriptions to capture both. cliphist store dedupes and trims to its
      # configured max, backing the launcher's clipboard-manager mode.
      systemd.user.services.cliphist-text = {
        Unit = {
          Description = "Store text clipboard entries in cliphist";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      systemd.user.services.cliphist-image = {
        Unit = {
          Description = "Store image clipboard entries in cliphist";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    })
  ];
}
