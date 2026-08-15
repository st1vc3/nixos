// Compact top-right status island. The detailed controls live in StatusCenter.

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Networking

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

    implicitWidth: pill.width + 2 * BarMetrics.edgeMargin
    implicitHeight: BarMetrics.stripHeight

    mask: Region { item: pill }

    Rectangle {
        id: pill
        // Inset by the shared gutter on the top and right, so the empty space
        // around the pill matches the gap Hyprland leaves around a window.
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: BarMetrics.edgeMargin
        anchors.rightMargin: BarMetrics.edgeMargin
        // Sized from its icons rather than a fixed number, so the glyphs sit in
        // the same 12px of padding the workspace pills use on the left.
        width: iconRow.implicitWidth + 2 * BarMetrics.pillPaddingH
        height: BarMetrics.pillHeight
        radius: BarMetrics.pillRadius
        color: (btnHover.hovered || ShellState.centerOpen || ShellState.statusCenterOpen) ? Colors.glass(0.85) : Colors.glass(0.5)
        // The expanding overlay starts transparent, leaving this pill visible
        // as the source of the growth animation just like the centre notch.
        opacity: 1

        Behavior on color { ColorAnimation { duration: 120 } }

        Row {
            id: iconRow
            anchors.centerIn: parent
            spacing: BarMetrics.pillGap
            Text {
                text: SystemStatus.vpnActive ? "" : ""
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: BarMetrics.iconSize
                color: SystemStatus.vpnActive ? Colors.accent : Colors.subtext
            }
            Text {
                text: Networking.wifiEnabled ? "" : ""
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: BarMetrics.iconSize
                color: Networking.wifiEnabled ? Colors.text : Colors.subtext
            }
            Text {
                text: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "" : ""
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: BarMetrics.iconSize
                color: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? Colors.text : Colors.subtext
            }
            Text {
                text: SystemStatus.sinkMuted ? "" : SystemStatus.volumeIcon
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: BarMetrics.iconSize
                color: SystemStatus.sinkMuted ? Colors.subtext : Colors.text
            }
            Text {
                id: notificationIcon
                text: Notifications.dnd ? "" : ""
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: BarMetrics.iconSize
                color: notificationZoneHover.hovered ? Colors.accent : (Notifications.dnd ? Colors.subtext : Colors.text)

                // Badged on the bell rather than on the pill's corner: the
                // pill now meets the screen edge, so a corner dot would be
                // clipped by it.
                Rectangle {
                    visible: bar.unread > 0
                    width: 8
                    height: 8
                    radius: 4
                    color: Colors.accent
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: -2
                    anchors.rightMargin: -3
                }
            }
        }

        // Two sibling hit zones avoid nested pointer handlers competing for
        // the same click. The generous bell zone includes its surrounding
        // padding, not only the few painted pixels of the glyph.
        Item {
            id: controlZone
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: notificationZone.left
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: ShellState.toggleStatusCenter()
            }
        }

        Item {
            id: notificationZone
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            // The bell glyph plus its right padding and half the gap to the
            // icon before it, so the whole visual gutter around the bell taps
            // through to the notification centre.
            width: notificationIcon.width + BarMetrics.pillPaddingH + BarMetrics.pillGap / 2
            HoverHandler {
                id: notificationZoneHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: ShellState.toggleCenter()
            }
        }

        HoverHandler { id: btnHover }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: ShellState.toggleCenter()
        }
    }
}
