# CPU microcode + NVIDIA graphics stack.
{ config, ... }:

{
  # CPU (AMD) microcode + redistributable firmware.
  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  # Graphics stack.
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

  # Wayland/NVIDIA environment hints.
  # NOTE: GBM_BACKEND=nvidia-drm and AQ_DRM_DEVICES were REMOVED - on this
  # hybrid box (AMD iGPU + NVIDIA dGPU) they made aquamarine's CBackend::create()
  # crash. With modesetting on, aquamarine auto-selects the NVIDIA card and
  # drives the 4K display fine on its own. Keep this minimal.
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Electron/Chromium apps run natively on Wayland
    LIBVA_DRIVER_NAME = "nvidia"; # hardware video decode via NVIDIA VA-API
  };
}
