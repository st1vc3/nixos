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
        ];
      };
    };
}
