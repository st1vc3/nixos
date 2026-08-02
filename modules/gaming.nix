{ pkgs, ... }:

let
  cursebreaker = pkgs.callPackage ../pkgs/cursebreaker.nix { };
in
{
  environment.systemPackages = with pkgs; [
    prismlauncher
    lutris
    winetricks
    virt-manager
    cursebreaker
  ];

  programs.steam.enable = true;
  programs.gamemode.enable = true;

  virtualisation.libvirtd.enable = true;
}
