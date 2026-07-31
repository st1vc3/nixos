# home-manager wiring, imported into the system so one `nixos-rebuild switch`
# deploys both system and per-user ($HOME) state.
{ inputs, ... }:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    # Back up (not clobber) any pre-existing files home-manager takes over.
    backupFileExtension = "hm-bak";

    users.stivce = import ./stivce.nix;
  };
}
