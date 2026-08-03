{
  description = "stivce's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wallpapers = {
      url = "github:st1vc3/wallpaper";
      flake = false;
    };

    silentSDDM = {
      url = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprquickframe = {
      url = "github:Ronin-CK/HyprQuickFrame";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Neither browser is in nixpkgs yet (Zen is stuck on Firefox-fork
    # packaging issues, Helium's PR has been pending for a while), so both
    # come from community flakes that repackage the official binaries.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    helium = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, disko, ... }@inputs:
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          disko.nixosModules.disko
          ./configuration.nix
        ];
      };

      formatter = {
        x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
        aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
      };

      # Expose the Disko CLI from this flake's locked input. Installation docs
      # can use `nix run .#disko` without resolving an unrelated latest version.
      packages.x86_64-linux.disko = disko.packages.x86_64-linux.disko;
    };
}
