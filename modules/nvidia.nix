{ config, ... }:

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

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
  };
}
