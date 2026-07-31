{ pkgs, inputs, ... }:

{
  environment.systemPackages = with pkgs; [
    inputs.claude-code-nix.packages.${pkgs.system}.claude-code
    git
    vim
    neovim
    wget
    curl
    jq
    fzf
    fd
    zoxide
    eza
    bat
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
