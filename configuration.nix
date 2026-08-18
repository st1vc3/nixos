{ lib, pkgs, ... }:

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
      # The menu is waited out in full on every boot. Hold space during POST to
      # bring it back when an older generation needs picking.
      timeout = 1;
    };
    # Root is NVMe + btrfs, so the initrd only needs the nvme driver. The
    # default set costs ~1s probing four empty SATA ports and ~3s in
    # switch-root, where systemd waits for udev to finish enumerating USB;
    # both buses come up in userspace instead, off the critical path. The
    # trade-off is no USB keyboard in an initrd emergency shell - recover by
    # rebooting and picking an older generation from the boot menu.
    #
    # This deliberately overrides the list nixos-generate-config detected;
    # hardware-configuration.nix stays as generated so it can be regenerated.
    initrd = {
      includeDefaultModules = false;
      availableKernelModules = lib.mkForce [ "nvme" ];
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
