{ lib, pkgs, ... }:

{
  systemd.user.services = {
    awww = {
      Unit = {
        Description = "Awww Wayland wallpaper daemon";
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = lib.getExe' pkgs.awww "awww-daemon";
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    set-wallpaper = {
      Unit = {
        Description = "Apply the default wallpaper and generated colour theme";
        PartOf = [ "graphical-session.target" ];
        Requires = [ "awww.service" ];
        After = [ "awww.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "%h/Scripts/set-wallpaper.sh";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    hypridle = {
      Unit = {
        Description = "Hyprland idle management daemon";
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = lib.getExe pkgs.hypridle;
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    hyprpolkitagent = {
      Unit = {
        Description = "Hyprland PolicyKit authentication agent";
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.tmpfiles.rules = [
    "d %h/Pictures/Screenshots 0755 - -"
    "d %t/kitty 0700 - -"
  ];
}
