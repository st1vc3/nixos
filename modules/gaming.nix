{
  programs.steam.enable = true;
  programs.gamemode.enable = true;

  virtualisation.libvirtd.enable = true;
  # libvirt-guests only exists to suspend/resume running VMs across reboots,
  # but it pulls libvirtd (~0.9s) onto the path to graphical.target. Nothing
  # here autostarts guests, and libvirtd.socket still starts the daemon on
  # demand when virsh or virt-manager connects.
  systemd.services.libvirt-guests.enable = false;
}
