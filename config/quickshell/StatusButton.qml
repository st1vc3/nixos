// Top-right bar element: a frosted-glass bell pill that toggles the
// notification centre and shows an accent dot when there's history. First
// occupant of what will become the right-side status cluster.

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: bar

    property var modelData
    screen: modelData

    readonly property int unread: Notifications.list.values ? Notifications.list.values.length : 0

    anchors.top: true
    anchors.right: true
    // Ignore the notch's reserved strip so this surface shares its top line
    // instead of being pushed down by the notch's 34px exclusive zone.
    exclusiveZone: -1
    color: "transparent"

    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    implicitWidth: 72
    implicitHeight: 34

    mask: Region { item: pill }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: 48
        height: 26
        radius: 13
        color: (btnHover.hovered || ShellState.centerOpen) ? Colors.glass(0.85) : Colors.glass(0.5)

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: "" // Nerd Font bell
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: Colors.text
        }

        Rectangle {
            visible: bar.unread > 0
            width: 8
            height: 8
            radius: 4
            color: Colors.accent
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -1
            anchors.rightMargin: -1
        }

        HoverHandler { id: btnHover }
        TapHandler { onTapped: ShellState.toggleCenter() }
    }
}
