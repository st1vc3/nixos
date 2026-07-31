# Applications and CLI tools (system-wide).
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # --- core CLI ---
    git
    vim
    wget
    curl
    jq # waybar/script JSON plumbing
    fzf # fuzzy finder (zshrc.d/50-fzf.zsh)
    fastfetch # system info
    libnotify # notify-send, used across the scripts
    imagemagick # `magick`, used by swaync-fake-blur
    playerctl # media keybinds
    brightnessctl # brightness keybinds

    # --- terminal ---
    kitty

    # --- Hyprland desktop ---
    waybar # status bar
    wofi # app launcher
    awww # wallpaper daemon (formerly swww)
    matugen # material palette generated from the wallpaper
    swaynotificationcenter # swaync: notification daemon + center
    hypridle # idle daemon (lock / dpms)
    hyprpolkitagent # graphical polkit auth agent
    hyprshot # screenshots (wraps grim + slurp)
    hyprland-qtutils # Qt dialogs/utilities Hyprland shells out to
    grim # screenshot backend
    slurp # region selection for grim/hyprshot
    wl-clipboard # wl-copy/wl-paste in scripts

    # --- GUI apps ---
    nautilus # file manager
    pavucontrol # PipeWire/PulseAudio volume mixer

    # --- referenced by the hypr configs ---
    psmisc # `killall`, used by start-hyprlock
    volantes-cursors # XCURSOR_THEME = volantes_light_cursors
    kdePackages.qt6ct # QT_QPA_PLATFORMTHEME = qt6ct
  ];

  # Web browser (module form: supports policies + runs native Wayland).
  programs.firefox.enable = true;

  # Shell prompt (integrates with the enabled zsh).
  programs.starship.enable = true;
}
