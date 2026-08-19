pragma Singleton

// Live recording state for the dictation overlay.
//
// hyprwhspr-rs publishes its state to ~/.cache/hyprwhspr-rs/status.json on
// every transition, writing to a temp file and renaming it so watchers see one
// atomic event rather than a half-written file. That makes the file, not the
// keybindings, the honest source of truth: the overlay follows what the daemon
// is actually doing, so a failed start or a transcription that outlives the key
// release can never leave the indicator stuck on.
//
// The file is upstream's Waybar contract - see config/waybar/ in the
// hyprwhspr-rs source. Only "class" and "tooltip" are read here; "text" carries
// the Nerd Font mic glyph, which the overlay reuses so the icon set stays in
// one place.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // inactive | active | processing | error, mirroring the daemon's own state
    // names. Anything unrecognised is treated as inactive so a future upstream
    // state cannot pin the overlay open.
    property string state: "inactive"
    property string tooltip: ""
    property string icon: ""

    readonly property bool recording: state === "active"
    readonly property bool processing: state === "processing"
    readonly property bool failed: state === "error"
    readonly property bool busy: recording || processing || failed

    function apply() {
        const raw = view.text();
        if (!raw)
            return;
        try {
            const s = JSON.parse(raw);
            const known = ["inactive", "active", "processing", "error"];
            root.state = known.indexOf(s.class) >= 0 ? s.class : "inactive";
            root.tooltip = s.tooltip || "";
            root.icon = s.text || "";
        } catch (e) {
            // Caught mid-write despite the atomic rename, or the daemon changed
            // the format: hold the last known state rather than flashing the
            // overlay off and on.
        }
    }

    FileView {
        id: view
        path: Quickshell.env("HOME") + "/.cache/hyprwhspr-rs/status.json"
        watchChanges: true
        onLoaded: root.apply()
        onFileChanged: {
            reload();
            root.apply();
        }
        onLoadFailed: error => {
            // The daemon has not run yet, so there is nothing to show. It
            // creates the file on startup and the watch picks it up from there.
            if (error === FileViewError.FileNotFound)
                root.state = "inactive";
        }
    }
}
