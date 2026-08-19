{ pkgs, ... }:

{
  # Battle.net is not a package this repo installs. It runs from a
  # Lutris-managed wine prefix at ~/Games/battlenet, and is what World of
  # Warcraft (installed inside that prefix) is launched from.
  #
  # Lutris keeps its games in its own database (~/.local/share/lutris/pga.db)
  # rather than as XDG desktop entries, so an app launcher that enumerates
  # desktop entries cannot see it at all. Lutris can write a shortcut itself,
  # but that is imperative state in ~/.local/share/applications that a
  # reinstall would lose. Declaring it here keeps it with the rest of the
  # configuration.
  #
  # Addressed by slug rather than by numeric id (`rungameid/1`): the id is a
  # local autoincrement that a reinstall would renumber, while the slug is
  # derived from the game name and stays stable.
  xdg.desktopEntries.battle-net = {
    name = "Battle.net";
    genericName = "Game Launcher";
    comment = "Blizzard game launcher, running in the Lutris wine prefix";
    exec = "${pkgs.lutris}/bin/lutris lutris:rungame/battlenet";
    # Lutris downloads this icon into ~/.local/share/icons when the game is
    # installed. That is imperative state this repo does not manage, so the
    # launcher falls back to a generic icon if the prefix was never set up.
    icon = "lutris_battlenet";
    terminal = false;
    type = "Application";
    categories = [ "Game" ];
    startupNotify = true;
  };
}
