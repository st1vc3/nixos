// Top-left bar element mirroring the right-hand notification pill: a row of
// frosted-glass workspace pills. Only workspaces that actually hold windows are
// shown, the focused one is filled with the accent colour, and clicking a pill
// switches Hyprland to that workspace.
//
// Hovering a single pill springs open a notch-style panel underneath it (same
// animated expand) listing just that workspace's open windows; moving to
// another pill swaps the panel to that workspace. Clicking a window row jumps
// to its workspace.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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

    // Sized for the fully expanded panel; the dropdown animates within it while
    // everything around it stays transparent and click-through (see mask).
    // Wide enough for a full row of padded pills plus the dropdown hanging
    // under the last of them, so the extra width costs nothing.
    implicitWidth: 720
    implicitHeight: BarMetrics.stripHeight + maxDropHeight

    readonly property real stripHeight: BarMetrics.stripHeight
    readonly property real maxDropHeight: 420

    // Workspace id whose panel is open (-1 = none), and the left offset of the
    // pill it hangs under.
    property int hoveredWs: -1
    property real dropAnchorX: BarMetrics.edgeMargin
    readonly property bool expanded: hoveredWs >= 0

    // A short grace period stops the panel collapsing while the pointer travels
    // between a pill and its dropdown.
    Timer {
        id: collapseTimer
        interval: 160
        onTriggered: bar.hoveredWs = -1
    }
    function openFor(wsId, anchorX) {
        collapseTimer.stop();
        bar.dropAnchorX = anchorX;
        bar.hoveredWs = wsId;
    }
    function keepOpen() { collapseTimer.stop(); }
    function scheduleClose() { collapseTimer.restart(); }

    // Only the visible shapes take input; the rest of the large surface stays
    // click-through. Collapsed, the dropdown region is empty (height 0).
    mask: Region {
        Region { item: pillRow }
        Region { item: dropdown }
    }

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

    // Windows on the currently hovered workspace only, sorted by class.
    readonly property var hoveredWindows: {
        if (hoveredWs < 0)
            return [];
        const arr = [];
        const tops = Hyprland.toplevels.values;
        for (let i = 0; i < tops.length; i++) {
            const o = tops[i].lastIpcObject;
            if (!o || !o.workspace || o.workspace.id !== bar.hoveredWs)
                continue;
            arr.push({ appClass: o.class || "?", title: o.title || "" });
        }
        arr.sort((a, b) => a.appClass.localeCompare(b.appClass));
        return arr;
    }

    function focusWorkspace(id) {
        // Lua-configured Hyprland: the IPC dispatch endpoint wraps input as
        // hl.dispatch(<input>), so pass the dispatcher factory rather than a
        // bare "workspace N".
        Hyprland.dispatch("hl.dsp.focus({workspace = " + id + "})");
    }

    // Pills row.
    Row {
        id: pillRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: BarMetrics.edgeMargin
        anchors.leftMargin: BarMetrics.edgeMargin
        height: BarMetrics.pillHeight
        spacing: BarMetrics.pillGap

        Repeater {
            model: bar.occupied

            delegate: Rectangle {
                id: wsPill
                required property var modelData

                readonly property bool isFocused: modelData.id === bar.focusedId

                anchors.verticalCenter: parent.verticalCenter
                // Same bubble as the status island's pill: padded on both
                // sides, never narrower than it is tall for single-digit names.
                width: Math.max(BarMetrics.pillHeight, label.implicitWidth + 2 * BarMetrics.pillPaddingH)
                height: BarMetrics.pillHeight
                radius: BarMetrics.pillRadius
                color: isFocused
                    ? Colors.accent
                    : (pillHover.hovered ? Colors.glass(0.85) : Colors.glass(0.5))

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: wsPill.modelData.name
                    color: wsPill.isFocused ? Colors.accentText : Colors.text
                    font.pixelSize: BarMetrics.labelSize
                    font.bold: true
                }

                HoverHandler {
                    id: pillHover
                    onHoveredChanged: {
                        if (hovered)
                            bar.openFor(wsPill.modelData.id, pillRow.x + wsPill.x);
                        else
                            bar.scheduleClose();
                    }
                }
                TapHandler { onTapped: bar.focusWorkspace(wsPill.modelData.id) }
            }
        }
    }

    // Notch-style dropdown listing the hovered workspace's windows. Grows from
    // the pills' bottom edge, aligned under the hovered pill.
    Rectangle {
        id: dropdown

        readonly property real openHeight: Math.min(12 + bar.hoveredWindows.length * 42, bar.maxDropHeight)

        y: pillRow.y + pillRow.height
        // Hangs under the hovered pill, held inside the surface so a pill near
        // the right end does not push the panel off the window.
        x: Math.min(bar.dropAnchorX, bar.width - width - BarMetrics.edgeMargin)
        width: 300
        height: bar.expanded ? openHeight : 0
        clip: true
        radius: 18
        color: Colors.glass(0.9)
        border.width: bar.expanded ? 1 : 0
        border.color: Colors.glass(0.95)

        Behavior on height {
            // Grows to its size without springing past it, like the other
            // panels that drop out of the bar.
            NumberAnimation { duration: 320; easing.type: Easing.OutQuint }
        }

        HoverHandler {
            id: dropHover
            onHoveredChanged: {
                if (hovered)
                    bar.keepOpen();
                else
                    bar.scheduleClose();
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2
            opacity: bar.expanded ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Repeater {
                model: bar.hoveredWindows

                delegate: Rectangle {
                    id: winRow
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 12
                    color: rowHover.hovered ? Colors.glass(0.9) : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 10
                        spacing: 10

                        Image {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            source: Quickshell.iconPath(winRow.modelData.appClass, "application-x-executable")
                            sourceSize.width: 22
                            sourceSize.height: 22
                            fillMode: Image.PreserveAspectFit
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: winRow.modelData.appClass
                                color: Colors.text
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: winRow.modelData.title
                                color: Colors.subtext
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }
                    }

                    HoverHandler { id: rowHover }
                    TapHandler { onTapped: bar.focusWorkspace(bar.hoveredWs) }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: bar.hoveredWindows.length === 0
                horizontalAlignment: Text.AlignHCenter
                text: "No open windows"
                color: Colors.subtext
                font.pixelSize: 12
            }

            Item { Layout.fillHeight: true }
        }
    }
}
