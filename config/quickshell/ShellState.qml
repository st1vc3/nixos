pragma Singleton

// Shared UI state for the shell. Kept tiny and global so the bar button, the
// notification centre and anything else can agree on what's open without
// threading properties through the tree.

import Quickshell

Singleton {
    id: root

    property bool centerOpen: false
    property bool launcherOpen: false
    property bool powerMenuOpen: false
    property bool wallpaperPickerOpen: false
    property bool statusCenterOpen: false
    property bool cheatsheetOpen: false

    function closeOverlays() {
        centerOpen = false;
        launcherOpen = false;
        powerMenuOpen = false;
        wallpaperPickerOpen = false;
        statusCenterOpen = false;
        cheatsheetOpen = false;
    }

    function toggleCenter() {
        const opening = !centerOpen;
        closeOverlays();
        centerOpen = opening;
    }

    function openLauncher() {
        closeOverlays();
        launcherOpen = true;
    }

    function closeLauncher() {
        launcherOpen = false;
    }

    function toggleLauncher() {
        if (launcherOpen)
            closeLauncher();
        else
            openLauncher();
    }

    function togglePowerMenu() {
        const opening = !powerMenuOpen;
        closeOverlays();
        powerMenuOpen = opening;
    }

    function toggleWallpaperPicker() {
        const opening = !wallpaperPickerOpen;
        closeOverlays();
        wallpaperPickerOpen = opening;
    }

    function toggleStatusCenter() {
        const opening = !statusCenterOpen;
        closeOverlays();
        statusCenterOpen = opening;
    }

    function openCheatsheet() {
        closeOverlays();
        cheatsheetOpen = true;
    }

    function toggleCheatsheet() {
        const opening = !cheatsheetOpen;
        closeOverlays();
        cheatsheetOpen = opening;
    }
}
