# home-manager configuration, wired into the system flake so a single
# `nixos-rebuild switch` deploys both the system and per-user ($HOME) state.
{ inputs, ... }:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };

    users.stivce = {
      home.username = "stivce";
      home.homeDirectory = "/home/stivce";
      # Matches the system stateVersion; do not bump on upgrades.
      home.stateVersion = "26.05";

      # The wallpaper repo (github.com/st1vc3/wallpaper), pinned as a flake
      # input, symlinked into ~/Pictures/wallpapers. Updating it is a
      # `nix flake update wallpapers` + rebuild - no manual git clone.
      home.file."Pictures/wallpapers".source = inputs.wallpapers;

      # Wallpaper-setter script, deployed to ~/Scripts/set-wallpaper.sh.
      home.file."Scripts/set-wallpaper.sh" = {
        source = ./scripts/set-wallpaper.sh;
        executable = true;
      };
    };
  };
}
