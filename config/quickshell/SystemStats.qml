pragma Singleton

// Polls system telemetry for the shell's status widgets. Currently just disk
// usage via `df` (no native quickshell module for it); CPU/RAM/etc. can hang
// off the same singleton later, each with its own timer so polling stays
// centralised and cheap.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // One entry per real filesystem: { target, used, size, pct }. `root` is the
    // headline used for the ring; `disks` is the deduplicated list.
    property var disks: []
    property var rootDisk: ({ target: "/", used: 0, size: 0, pct: 0 })

    function refresh() {
        dfProc.running = true;
    }

    // Disk changes slowly; a 30s poll is plenty and keeps the process spawn
    // rate negligible.
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: dfProc
        // -B1: bytes. Exclude pseudo filesystems so the list is only real
        // storage. Fixed column order via --output so parsing is positional.
        command: [
            "df", "-B1", "--output=source,target,used,size,pcent",
            "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs",
            "-x", "overlay", "-x", "squashfs"
        ]
        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
    }

    function parse(text) {
        const out = [];
        const seenSources = ({});
        const lines = text.trim().split("\n");
        for (let i = 1; i < lines.length; i++) {
            const parts = lines[i].trim().split(/\s+/);
            if (parts.length < 5)
                continue;
            const source = parts[0];
            const pct = parseInt(parts[parts.length - 1]) || 0;
            const size = parseInt(parts[parts.length - 2]) || 0;
            const used = parseInt(parts[parts.length - 3]) || 0;
            const target = parts.slice(1, parts.length - 3).join(" ");
            // df reports identical whole-filesystem figures for every btrfs
            // subvolume. Keep the first mount so this is an honest filesystem
            // list instead of a duplicate pseudo-breakdown.
            if (seenSources[source])
                continue;
            seenSources[source] = true;
            out.push({ target, used, size, pct });
        }
        root.disks = out;
        for (const d of out) {
            if (d.target === "/") {
                root.rootDisk = d;
                break;
            }
        }
    }

    function human(bytes) {
        const u = ["B", "K", "M", "G", "T"];
        let n = bytes, i = 0;
        while (n >= 1024 && i < u.length - 1) {
            n /= 1024;
            i++;
        }
        return (n >= 100 || i === 0 ? Math.round(n) : n.toFixed(1)) + u[i];
    }
}
