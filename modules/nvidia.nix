{
  config,
  lib,
  pkgs,
  ...
}:

{
  hardware = {
    enableRedistributableFirmware = true;
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    nvidia = {
      modesetting.enable = true;
      nvidiaSettings = true;
      powerManagement.enable = false;
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  # `hardware.nvidia.open` makes nixpkgs put `nvidia_uvm` in boot.kernelModules,
  # because the `softdep nvidia post: nvidia-uvm` modprobe rule it normally
  # relies on is unreliable with the open kernel modules (NixOS#334180). The
  # side effect is that systemd-modules-load.service - which is ordered before
  # sysinit.target, so the entire boot waits on it - blocks ~2.9s while the RM
  # brings the GPU up. Keep loading it eagerly, just not on the critical path:
  # drop it from modules-load.d and hand it to a service systemd considers
  # started the moment it forks.
  #
  # If nixpkgs ever renames this file the mkForce stops matching and we simply
  # get the upstream blocking behaviour back, which is the safe direction.
  environment.etc."modules-load.d/nixos.conf".text = lib.mkForce (
    lib.concatStringsSep "\n" (lib.filter (m: m != "nvidia_uvm") config.boot.kernelModules)
  );

  systemd.services.nvidia-uvm = {
    description = "Load the nvidia_uvm kernel module";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      # Deliberately not oneshot: oneshot would make multi-user.target wait for
      # the modprobe to return, which is the delay we are trying to get rid of.
      Type = "simple";
      RemainAfterExit = true;
      ExecStart = "${pkgs.kmod}/bin/modprobe nvidia_uvm";
    };
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
  };
}
