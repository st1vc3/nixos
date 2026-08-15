// Slide-in notification centre on the right edge: notification history plus the
// status widgets (disk for now). Toggled by the bar button via ShellState.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    readonly property int panelWidth: 400

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    exclusiveZone: 0
    color: "transparent"

    WlrLayershell.namespace: "quickshell-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // While open, the input region covers the monitor so the transparent area
    // can act as a click-away target. Closed, only the off-screen glass belongs
    // to the region, leaving the desktop completely pass-through.
    mask: Region { item: ShellState.centerOpen ? dismissArea : glass }

    Item {
        id: dismissArea
        anchors.fill: parent
        visible: ShellState.centerOpen

        TapHandler { onTapped: ShellState.centerOpen = false }
    }

    Rectangle {
        id: glass
        width: root.panelWidth
        height: parent.height
        x: ShellState.centerOpen ? root.width - width : root.width

        color: Colors.glass(0.6)
        topLeftRadius: 20
        bottomLeftRadius: 20

        // Consume otherwise-unhandled clicks inside the panel so they do not
        // reach the click-away layer behind it.
        TapHandler {}

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Notifications"
                    color: Colors.text
                    font.pixelSize: 14
                    font.bold: true
                    Layout.fillWidth: true
                }

                Rectangle {
                    radius: 8
                    implicitWidth: clearLabel.implicitWidth + 20
                    implicitHeight: 28
                    visible: Notifications.list.values.length > 0
                    color: clearHover.hovered ? Colors.accent : Colors.glass(0.9)

                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: "Clear all"
                        color: clearHover.hovered ? Colors.accentText : Colors.text
                        font.pixelSize: 14
                    }
                    HoverHandler { id: clearHover }
                    TapHandler { onTapped: Notifications.clearAll() }
                }
            }

            DndToggle {
                Layout.fillWidth: true
            }

            DiskWidget {
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.glass(0.5)
            }

            // Notification history (or empty state).
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    anchors.fill: parent
                    clip: true
                    spacing: 8
                    visible: Notifications.list.values.length > 0
                    model: Notifications.list

                    delegate: NotificationCard {
                        required property var modelData
                        width: ListView.view ? ListView.view.width : 0
                        notif: modelData
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: Notifications.list.values.length === 0
                    text: "No notifications"
                    color: Colors.subtext
                    font.pixelSize: 14
                }
            }
        }
    }
}
