{ pkgs, ... }:
{
  # GNOME Calendar depends on Evolution Data Server for its calendar sources,
  # timezone data and user-session DBus activation files. Installing the app
  # package alone leaves org.gnome.evolution.dataserver.Sources5 unavailable.
  services.gnome.evolution-data-server.enable = true;

  environment.systemPackages = with pkgs; [
    git
    wget
    curl
    jq
    psmisc
  ];
}
