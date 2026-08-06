// Top-left bar element mirroring the right-hand notification pill: a row of
// frosted-glass workspace pills. Only workspaces that actually hold windows are
// shown, the focused one is filled with the accent colour, and clicking a pill
// switches Hyprland to that workspace.
//
// Hovering the row springs open a notch-style panel underneath (same animated
// expand) that lists every open window grouped by workspace; clicking an entry
// jumps to its workspace.

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
    implicitWidth: 360
    implicitHeight: 460

    readonly property real stripHeight: 34

    property bool expanded: false
    // A short grace period stops the panel collapsing while the pointer travels
    // between the pills and the dropdown.
    Timer {
        id: collapseTimer
        interval: 160
        onTriggered: bar.expanded = false
    }
    function hoverChanged(hovered) {
        if (hovered) {
            collapseTimer.stop();
            bar.expanded = true;
        } else {
            collapseTimer.restart();
        }
    }

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

    // Open windows grouped per workspace for the dropdown. Each group is
    // { wsId, wsName, windows: [{ appClass, title }] }, sorted by workspace id
    // with windows sorted by class within it.
    readonly property var groups: {
        const map = ({});
        const order = [];
        const tops = Hyprland.toplevels.values;
        for (let i = 0; i < tops.length; i++) {
            const o = tops[i].lastIpcObject;
            if (!o || !o.workspace || o.workspace.id <= 0)
                continue;
            const id = o.workspace.id;
            if (!map[id]) {
                map[id] = { wsId: id, wsName: o.workspace.name || ("" + id), windows: [] };
                order.push(id);
            }
            map[id].windows.push({ appClass: o.class || "?", title: o.title || "" });
        }
        order.sort((a, b) => a - b);
        return order.map(id => {
            map[id].windows.sort((a, b) => a.appClass.localeCompare(b.appClass));
            return map[id];
        });
    }
    readonly property int windowCount: {
        let n = 0;
        for (let i = 0; i < groups.length; i++)
            n += groups[i].windows.length;
        return n;
    }
    // Height needed to show every group header plus its window rows.
    readonly property real contentHeight: {
        let h = 12;
        for (let i = 0; i < groups.length; i++)
            h += 24 + groups[i].windows.length * 42 + (i < groups.length - 1 ? 8 : 0);
        return Math.max(h, 44);
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
        anchors.leftMargin: 12
        height: bar.stripHeight
        spacing: 6

        Repeater {
            model: bar.occupied

            delegate: Rectangle {
                id: wsPill
                required property var modelData

                readonly property bool isFocused: modelData.id === bar.focusedId

                anchors.verticalCenter: parent.verticalCenter
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

                HoverHandler {
                    id: pillHover
                    onHoveredChanged: bar.hoverChanged(hovered)
                }
                TapHandler { onTapped: bar.focusWorkspace(wsPill.modelData.id) }
            }
        }
    }

    // Notch-style dropdown listing open windows. Grows from the pills' bottom
    // edge on hover, content fading in just after the shape starts opening.
    Rectangle {
        id: dropdown

        readonly property real openHeight: Math.min(bar.contentHeight, 420)

        anchors.top: pillRow.bottom
        anchors.left: parent.left
        anchors.leftMargin: 12
        width: 320
        height: bar.expanded ? openHeight : 0
        clip: true
        radius: 18
        color: Colors.glass(0.9)
        border.width: bar.expanded ? 1 : 0
        border.color: Colors.glass(0.95)

        Behavior on height {
            NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.05 }
        }

        HoverHandler {
            id: dropHover
            onHoveredChanged: bar.hoverChanged(hovered)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 6
            opacity: bar.expanded ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            // One section per workspace: a header with the workspace badge, then
            // its windows underneath.
            Repeater {
                model: bar.groups

                delegate: ColumnLayout {
                    id: group
                    required property var modelData

                    readonly property bool isFocused: modelData.wsId === bar.focusedId

                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            radius: 10
                            color: group.isFocused ? Colors.accent : Colors.glass(0.6)
                            Text {
                                anchors.centerIn: parent
                                text: group.modelData.wsName
                                color: group.isFocused ? Colors.accentText : Colors.subtext
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        Text {
                            text: "Workspace"
                            color: group.isFocused ? Colors.accent : Colors.subtext
                            font.pixelSize: 11
                            font.bold: true
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Repeater {
                        model: group.modelData.windows

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
                            TapHandler { onTapped: bar.focusWorkspace(group.modelData.wsId) }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: bar.windowCount === 0
                horizontalAlignment: Text.AlignHCenter
                text: "No open windows"
                color: Colors.subtext
                font.pixelSize: 12
            }

            Item { Layout.fillHeight: true }
        }
    }
}
