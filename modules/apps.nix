{ pkgs, inputs, ... }:

let
  unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};
  hyprquickframe = inputs.hyprquickframe.packages.${pkgs.system}.default;
in
{
  environment.systemPackages = with pkgs; [
    claude-code
    unstable.herdr
    git
    neovim
    wget
    curl
    jq
    fzf
    fd
    zoxide
    eza
    bat
    ripgrep
    mpv
    starship
    fastfetch
    libnotify
    imagemagick
    playerctl
    brightnessctl
    kitty
    zed-editor
    waybar
    wofi
    awww
    matugen
    swaynotificationcenter
    hypridle
    hyprpolkitagent
    hyprshot
    hyprshutdown
    hyprquickframe
    hyprland-qtutils
    grim
    slurp
    wl-clipboard
    nautilus
    pavucontrol
    psmisc
    volantes-cursors
    kdePackages.qt6ct
    discord
    telegram-desktop
    whatsapp-electron
  ];

  programs.firefox.enable = true;
}
