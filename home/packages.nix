{
  inputs,
  pkgs,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  unstable = inputs.nixpkgs-unstable.legacyPackages.${system};
  cursebreaker = pkgs.callPackage ../pkgs/cursebreaker.nix { };
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
    cursebreaker
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
  ];
}
