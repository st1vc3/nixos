// Entry point loaded by `quickshell` (from ~/.config/quickshell/shell.qml).
//
// Per-screen surfaces (notch, bar button) go through Variants so they follow
// monitors. The notification popups and centre are single instances on the
// primary screen.

import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens
        Notch {}
    }

    Variants {
        model: Quickshell.screens
        StatusButton {}
    }

    Variants {
        model: Quickshell.screens
        WorkspacesButton {}
    }

    NotificationPopups {}
    NotificationCenter {}
    StatusCenter {}
    VolumeOsd {}
    AppLauncher {}
    PowerMenu {}
    WallpaperPicker {}
}
