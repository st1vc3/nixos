pragma Singleton

// Live matugen palette for the quickshell shell. matugen writes
// ~/.config/quickshell/colors.json on every wallpaper change (see the
// quickshell-colors template wired up in home/stivce.nix); FileView watches
// that file and reparses it in place, so the notch re-themes without a
// restart.
//
// The hardcoded values below are the fallback used before the first matugen
// run (or if the JSON is missing/corrupt), matching the Material dark
// defaults in config/matugen/defaults/.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Property names deliberately avoid an "on"+CapitalLetter prefix: QML
    // parses `onAccent:` as a signal handler, not a property, so the Material
    // "on-*" foreground roles are named accentText / text / subtext instead.
    property color accent: "#adc6ff"
    property color accentText: "#002e6a"
    property color surface: "#111318"
    property color text: "#e2e2e9"
    property color subtext: "#c4c6d0"
    property color outline: "#8d9199"
    property color alert: "#ffb4ab"

    // Deliberately outside the matugen palette: "installed" has to read as
    // green whatever the wallpaper happens to tint the accent to.
    readonly property color success: "#6dd58c"

    // Frosted-glass fill: the surface colour at a given alpha, to be paired
    // with a Hyprland blur layer-rule (see hyprland.lua). Matches the acrylic
    // look used throughout the shell's notifications and popups.
    function glass(a) {
        return Qt.rgba(surface.r, surface.g, surface.b, a);
    }

    function apply() {
        const raw = view.text();
        if (!raw)
            return;
        try {
            const c = JSON.parse(raw);
            if (c.accent) accent = c.accent;
            if (c.accentText) accentText = c.accentText;
            if (c.surface) surface = c.surface;
            if (c.text) text = c.text;
            if (c.subtext) subtext = c.subtext;
            if (c.outline) outline = c.outline;
            if (c.alert) alert = c.alert;
        } catch (e) {
            // Malformed JSON (e.g. matugen caught mid-write): keep the last
            // good palette rather than throwing away the theme.
        }
    }

    FileView {
        id: view
        path: Quickshell.env("HOME") + "/.config/quickshell/colors.json"
        watchChanges: true
        onLoaded: root.apply()
        onFileChanged: {
            reload();
            root.apply();
        }
    }
}
