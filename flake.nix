{
  description = "stivce's NixOS configuration";

  inputs = {
    # Using unstable for up-to-date Hyprland/NVIDIA. Pin to a stable branch
    # (e.g. github:NixOS/nixpkgs/nixos-25.05) if you prefer fewer surprises.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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
