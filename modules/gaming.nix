{ lib, ... }:

{
  programs.steam.enable = true;
  programs.gamemode.enable = true;

  virtualisation.libvirtd.enable = true;
  # libvirt-guests only exists to suspend/resume running VMs across reboots,
  # but it pulls libvirtd (~0.9s) onto the path to graphical.target. Nothing
  # here autostarts guests, and libvirtd.socket still starts the daemon on
  # demand when virsh or virt-manager connects.
  systemd.services.libvirt-guests.enable = false;
  # Same reasoning for libvirtd itself: nixpkgs makes it WantedBy
  # multi-user.target, so its ~0.9s startup is on the path to graphical.target
  # even though nothing needs a running daemon at boot. libvirtd.socket stays
  # WantedBy sockets.target and starts it on the first client connection.
  systemd.services.libvirtd.wantedBy = lib.mkForce [ ];
}
