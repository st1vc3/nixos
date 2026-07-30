# Main system configuration.
# Host: nixos | User: stivce | AMD CPU + NVIDIA GPU + Hyprland (Wayland) + UEFI
{ config, pkgs, lib, ... }:

{
  # ---------------------------------------------------------------------------
  # Boot (UEFI / systemd-boot)
  # ---------------------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # btrfs root; disko provides the filesystems.
  boot.supportedFilesystems = [ "btrfs" ];

  # Weekly TRIM for SSD longevity (preferred over the discard=async mount option).
  services.fstrim.enable = true;

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
  # CPU (AMD) + firmware
  # ---------------------------------------------------------------------------
  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  # ---------------------------------------------------------------------------
  # GPU (NVIDIA) + graphics stack
  # ---------------------------------------------------------------------------
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # 32-bit libs for Steam/wine/etc.
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true; # required for Wayland/Hyprland
    nvidiaSettings = true;
    powerManagement.enable = false; # set true if you hit suspend/resume issues
    # RTX 4070 Ti (Ada) on the 595 driver: the open kernel module is the
    # recommended path for Turing+ cards and avoids black-screen issues.
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # ---------------------------------------------------------------------------
  # Desktop: Hyprland (Wayland) + SDDM greeter
  # ---------------------------------------------------------------------------
  programs.hyprland.enable = true;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # Wayland/NVIDIA environment hints for smooth Hyprland behaviour.
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Electron/Chromium apps run natively on Wayland
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    LIBVA_DRIVER_NAME = "nvidia";
    # This is a hybrid box (AMD iGPU + NVIDIA dGPU) with the monitor on the
    # NVIDIA card. Pin Hyprland's compositor backend (aquamarine) to the
    # NVIDIA GPU by its stable PCI path so it doesn't try to drive the display
    # through the unused iGPU (which black-screens on login).
    AQ_DRM_DEVICES = "/dev/dri/by-path/pci-0000:01:00.0-card";
  };

  # A portal so screen-sharing / file pickers work under Hyprland.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # ---------------------------------------------------------------------------
  # Audio (PipeWire)
  # ---------------------------------------------------------------------------
  security.rtkit.enable = true;
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ---------------------------------------------------------------------------
  # Users
  # ---------------------------------------------------------------------------
  users.users.stivce = {
    isNormalUser = true;
    description = "stivce";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    # CHANGE THIS after first boot with `passwd`. Needed to log in initially.
    initialPassword = "changeme";
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
  # Nix settings
  # ---------------------------------------------------------------------------
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true; # required for the NVIDIA driver

  # ---------------------------------------------------------------------------
  # Base packages (keep lean; add per-user tools via home-manager later)
  # ---------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    kitty # a terminal (Hyprland's default keybind expects one)
    wl-clipboard
    brightnessctl
  ];

  services.openssh.enable = true;

  # The release you first installed with. Do NOT change on upgrades.
  system.stateVersion = "26.05";
}
