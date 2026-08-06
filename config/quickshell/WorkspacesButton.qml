// Top-left bar element mirroring the right-hand notification pill: a row of
// frosted-glass workspace pills. Only workspaces that actually hold windows are
// shown, the focused one is filled with the accent colour, and clicking a pill
// switches Hyprland to that workspace.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: bar

    property var modelData
    screen: modelData

    anchors.top: true
    anchors.left: true
    // Share the top line with the notch instead of being pushed below its
    // reserved strip, exactly like StatusButton on the right.
    exclusiveZone: -1
    color: "transparent"

    WlrLayershell.namespace: "quickshell-workspaces"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    implicitWidth: Math.max(48, row.implicitWidth + 24)
    implicitHeight: 34

    mask: Region { item: row }

    readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -999

    // Occupied workspaces on this monitor, sorted by id. Occupancy is taken
    // from the live toplevel model (updates as windows open/close) with the
    // workspace's own window count as a fallback; special workspaces (negative
    // ids) are ignored.
    readonly property var occupied: {
        const ids = ({});
        const tops = Hyprland.toplevels.values;
        for (let i = 0; i < tops.length; i++) {
            const ws = tops[i].workspace;
            if (ws)
                ids[ws.id] = true;
        }
        return Hyprland.workspaces.values.filter(w => {
            if (w.id <= 0)
                return false;
            const hasWindows = ids[w.id] || (w.lastIpcObject && w.lastIpcObject.windows > 0);
            const onThisMonitor = !w.monitor || !bar.modelData || w.monitor.name === bar.modelData.name;
            return hasWindows && onThisMonitor;
        }).sort((a, b) => a.id - b.id);
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 12
        spacing: 6

        Repeater {
            model: bar.occupied

            delegate: Rectangle {
                id: wsPill
                required property var modelData

                readonly property bool isFocused: modelData.id === bar.focusedId

                width: Math.max(30, label.implicitWidth + 18)
                height: 26
                radius: 13
                color: isFocused
                    ? Colors.accent
                    : (pillHover.hovered ? Colors.glass(0.85) : Colors.glass(0.5))

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: wsPill.modelData.name
                    color: wsPill.isFocused ? Colors.accentText : Colors.text
                    font.pixelSize: 13
                    font.bold: true
                }

                HoverHandler { id: pillHover }
                // This Hyprland is Lua-configured: the IPC dispatch endpoint
                // wraps input as hl.dispatch(<input>), so a bare "workspace N"
                // is a Lua syntax error. Pass the dispatcher factory instead.
                TapHandler {
                    onTapped: Hyprland.dispatch("hl.dsp.focus({workspace = " + wsPill.modelData.id + "})")
                }
            }
        }
    }
}
