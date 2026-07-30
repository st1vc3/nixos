# Declarative disk layout for disko.
#
# IMPORTANT: set `device` below to the real target disk BEFORE running disko.
# On the live ISO, find it with `lsblk -o NAME,SIZE,TYPE,MODEL`.
#   - NVMe SSDs are typically /dev/nvme0n1
#   - SATA/USB disks are typically /dev/sda
#
# WARNING: disko will WIPE this entire disk. Double-check the device.
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1"; # <-- CHANGE ME to your target disk
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              size = "1G";
              type = "EF00"; # EFI System Partition
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # force overwrite existing signatures
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
