# Host entry point: basics + imports of the topical modules.
# Host: nixos | User: stivce | AMD CPU + NVIDIA GPU + Hyprland (Wayland) + UEFI
{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ./modules/nvidia.nix
    ./modules/desktop.nix
    ./modules/audio.nix
    ./modules/apps.nix
    ./home
  ];

  # ---------------------------------------------------------------------------
  # Boot (UEFI / systemd-boot) + storage
  # ---------------------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "btrfs" ]; # disko provides the filesystems
  services.fstrim.enable = true; # weekly SSD TRIM

  # ---------------------------------------------------------------------------
  # Networking
  # ---------------------------------------------------------------------------
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # ---------------------------------------------------------------------------
  # Locale / time
  # ---------------------------------------------------------------------------
  time.timeZone = "Europe/Vienna";
  i18n.defaultLocale = "en_US.UTF-8";
  # Vienna machine: German regional formats, US keyboard. Change if you like.
  i18n.extraLocaleSettings = {
    LC_TIME = "de_AT.UTF-8";
    LC_MONETARY = "de_AT.UTF-8";
    LC_MEASUREMENT = "de_AT.UTF-8";
  };
  console.keyMap = "us";

  # ---------------------------------------------------------------------------
  # Users
  # ---------------------------------------------------------------------------
  users.users.stivce = {
    isNormalUser = true;
    description = "stivce";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    # Password hash read from a file kept OUTSIDE this (public) repo. Generate on
    # the target with:  mkpasswd -m sha-512 > /etc/secrets/stivce.hash  (chmod 600)
    # Never put the hash inline here - the repo is public and it would be crackable.
    hashedPasswordFile = "/etc/secrets/stivce.hash";
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;

  # ---------------------------------------------------------------------------
  # Swap: zram (compressed RAM swap) instead of a disk partition.
  # ---------------------------------------------------------------------------
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # ---------------------------------------------------------------------------
  # Nix + misc
  # ---------------------------------------------------------------------------
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true; # required for the NVIDIA driver
  services.openssh.enable = true;

  # The release you first installed with. Do NOT change on upgrades.
  system.stateVersion = "26.05";
}
