{ lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ./modules/nvidia.nix
    ./modules/desktop.nix
    ./modules/audio.nix
    ./modules/dictation.nix
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
      # The initrd carries no HID drivers (see below), so its emergency shell has
      # no keyboard and this menu is the only way back into an older generation.
      timeout = 5;
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
      # btrfs asks the crypto API for a "crc32c" shash to check the csum when
      # it mounts. That provider is crc32c_cryptoapi, requested at runtime and
      # so absent from btrfs.ko's modules.dep - dropping the default set drops
      # it too, and root no longer mounts. Force-load it explicitly.
      kernelModules = [ "crc32c_cryptoapi" ];
    };
    supportedFilesystems = [ "btrfs" ];
  };
  services.fstrim.enable = true;
  services.tailscale = {
    enable = true;
    extraSetFlags = [ "--operator=stivce" ];
  };

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
      # The on-demand Stable Diffusion application uses a CUDA package from
      # nix-community. Without its cache, large CUDA dependencies such as NCCL
      # would be compiled locally.
      substituters = [ "https://nix-community.cachix.org" ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
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

  # On 2026-09-11 a Discord (Electron) SIGTRAP took systemd-coredump 62s of wall
  # clock, 34.6s of CPU and a 32G memory peak to handle, and because systemd
  # cannot reap the dying process until the handler is done, it stalled the
  # whole Hyprland session teardown and left a black screen behind.
  #
  # That 32G is not a coincidence: it is exactly ProcessSizeMax's default on
  # 64-bit, i.e. how much of the core systemd-coredump is willing to read in
  # order to generate a stack trace. Electron reserves an enormous address
  # space, so it hits that ceiling where a normal process never would. Cap the
  # sizes so a browser-engine crash is dumped cheaply or not at all.
  #
  # Deliberately not disabling coredumps outright - they are what made the
  # above diagnosable in the first place.
  systemd.coredump.settings.Coredump = {
    # Above this, no stack trace is generated. The core itself is still written
    # (that is unavoidable unless this is 0), it just stops being expensive.
    ProcessSizeMax = "2G";
    # Above this, the core is not kept on disk at all.
    ExternalSizeMax = "2G";
    # Total budget for /var/lib/systemd/coredump. The default is 10% of the
    # disk, which on this NVMe is far more than crash dumps deserve.
    MaxUse = "4G";
  };

  # Belt and braces for the memory spike specifically. The size limits above
  # bound how much of the core is *read*, but the core is written to disk
  # either way and that page cache is accounted to this cgroup, so the peak is
  # not fully bounded by ProcessSizeMax alone. A hard limit turns the balloon
  # into ordinary writeback; worst case the handler dies and we lose one core
  # dump, which beats putting 32G of pressure on a live desktop session.
  systemd.services."systemd-coredump@".serviceConfig.MemoryMax = "2G";

  nixpkgs.config.allowUnfree = true;
  services.openssh = {
    enable = true;
    # Opens port 22 on every interface, which here means the LAN and tailscale0.
    openFirewall = true;
    settings = {
      # Deliberately password auth rather than key-only: the point is to be able
      # to reach this box from any device without enrolling that device's public
      # key here first. The trade is that sshd becomes brute-forceable, which is
      # only acceptable because the host sits behind the router's NAT with no
      # port forward for 22.
      #
      # If this ever gets a public address or a :22 forward, flip this back to
      # false and enrol keys in users.users.stivce.openssh.authorizedKeys.keys
      # instead - do not leave both a public listener and password auth on.
      PasswordAuthentication = true;
      # Password auth above is the single interactive path; PAM's keyboard-
      # interactive is a second one that would also accept passwords, so leave
      # it off rather than widening the surface for no gain.
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  system.stateVersion = "26.05";
}
