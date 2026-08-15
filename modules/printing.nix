{ pkgs, ... }:

{
  # CUPS handles local and network printers. Modern wireless printers normally
  # use IPP Everywhere and work without a vendor-specific driver.
  services.printing = {
    enable = true;
    drivers = [ pkgs.gutenprint ];
  };

  # Discover printers advertising themselves over DNS-SD/mDNS on the local
  # network. openFirewall permits the multicast discovery traffic.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Provides a graphical way to discover, add, configure, and test printers.
  programs.system-config-printer.enable = true;
}
