{
  inputs,
  pkgs,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  unstable = inputs.nixpkgs-unstable.legacyPackages.${system};
  # Not in nixpkgs; repackaged from the official AppImage. See the header of
  # pkgs/curseforge.nix for why it needs a manual bump when upstream ships.
  curseforge = pkgs.callPackage ../pkgs/curseforge.nix { };
  helium = inputs.helium.packages.${system}.helium;
  hyprquickframe = inputs.hyprquickframe.packages.${system}.default;
  trayscale = pkgs.trayscale;
  zen-browser = inputs.zen-browser.packages.${system}.default;
in
{
  programs.firefox.enable = true;

  xdg.desktopEntries."dev.deedles.Trayscale" = {
    name = "Tailscale";
    genericName = "Tailscale Client";
    comment = "Manage Tailscale connections";
    exec = "${trayscale}/bin/trayscale %F";
    icon = "dev.deedles.Trayscale";
    terminal = false;
    type = "Application";
    categories = [
      "Network"
      "System"
    ];
  };

  home.packages = with pkgs; [
    awww
    bat
    brightnessctl
    claude-code
    curseforge
    discord
    eza
    fastfetch
    fd
    filen-desktop
    fzf
    gnome-calendar
    grim
    helium
    hyprland-qtutils
    hyprquickframe
    hyprshot
    hyprshutdown
    imagemagick
    kitty
    keepassxc
    libnotify
    lutris
    matugen
    mpv
    nautilus
    pavucontrol
    playerctl
    prismlauncher
    ripgrep
    satty
    slurp
    starship
    telegram-desktop
    trayscale
    unstable.herdr
    virt-manager
    volantes-cursors
    whatsapp-electron
    winetricks
    wl-clipboard
    zed-editor
    zen-browser
    zoxide
    kdePackages.qt6ct
    obs-studio
  ];
}
