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
  zen-browser = inputs.zen-browser.packages.${system}.default;
in
{
  programs.firefox.enable = true;

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
