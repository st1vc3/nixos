{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ./modules/nvidia.nix
    ./modules/desktop.nix
    ./modules/audio.nix
    ./modules/printing.nix
    ./modules/apps.nix
    ./modules/gaming.nix
    ./modules/snapshots.nix
    ./home
  ];

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
    supportedFilesystems = [ "btrfs" ];
  };
  services.fstrim.enable = true;

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  time.timeZone = "Europe/Vienna";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_TIME = "de_AT.UTF-8";
      LC_MONETARY = "de_AT.UTF-8";
      LC_MEASUREMENT = "de_AT.UTF-8";
    };
  };
  console.keyMap = "us";

  users.users.stivce = {
    isNormalUser = true;
    description = "stivce";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "libvirtd"
    ];
    # Keep fresh installations locked until docs/installation.md's interactive passwd
    # step. This avoids embedding even a temporary credential in source control.
    initialHashedPassword = "!";
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  nixpkgs.config.allowUnfree = true;
  services.openssh = {
    enable = true;
    settings = {
      # Remote access is key-only. Add an authorized key before expecting SSH
      # access to work.
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  system.stateVersion = "26.05";
}
