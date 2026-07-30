# PLACEHOLDER - regenerate this on the target machine during install!
#
# On the live ISO, after disko has mounted everything at /mnt, run:
#   nixos-generate-config --no-filesystems --root /mnt
# then copy the generated file over this one:
#   cp /mnt/etc/nixos/hardware-configuration.nix ./hardware-configuration.nix
#
# We pass --no-filesystems because disko already declares the filesystems;
# letting nixos-generate-config also declare them would cause a conflict.
#
# The real file will contain the correct kernel modules for YOUR hardware.
# The values below are only enough to let the flake evaluate before install.
{ config, lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
