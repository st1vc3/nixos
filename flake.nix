{
  description = "stivce's NixOS configuration";

  inputs = {
    # Stable branch. Switch to github:NixOS/nixpkgs/nixos-unstable if you want
    # the newest Hyprland/NVIDIA at the cost of more churn.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Wallpaper repo, tracked declaratively (not a flake, just files).
    wallpapers = {
      url = "github:st1vc3/wallpaper";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, disko, ... }@inputs:
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          disko.nixosModules.disko
          ./disko.nix
          ./hardware-configuration.nix
          ./configuration.nix
          ./home.nix
        ];
      };
    };
}
