{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    jq
    fzf
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
    hyprland-qtutils
    grim
    slurp
    wl-clipboard
    nautilus
    pavucontrol
    psmisc
    volantes-cursors
    kdePackages.qt6ct
  ];

  programs.firefox.enable = true;
  programs.starship.enable = true;
}
