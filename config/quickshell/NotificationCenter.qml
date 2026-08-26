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
    // Ignore the bar's exclusive zone so the collapsed surface can occupy the
    // exact status-pill geometry before growing into the notification panel.
    exclusiveZone: -1
    color: "transparent"

    WlrLayershell.namespace: "quickshell-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // While open, the input region covers the monitor so the transparent area
    // can act as a click-away target. Closed, only the off-screen glass belongs
    // to the region, leaving the desktop completely pass-through.
    mask: Region { item: ShellState.centerOpen ? dismissArea : closedInputRegion }

    Item {
        id: closedInputRegion
        width: 0
        height: 0
    }

    Item {
        id: dismissArea
        anchors.fill: parent
        visible: ShellState.centerOpen

        TapHandler { onTapped: ShellState.centerOpen = false }
    }

    Rectangle {
        id: glass
        // This is a top-down popover, not a drawer from the screen edge.
        width: root.panelWidth
        // Match the strip above the panel at the bottom edge as well.
        readonly property real openHeight: parent.height - 2 * BarMetrics.stripHeight
        readonly property real closedHeight: BarMetrics.pillHeight

        height: ShellState.centerOpen ? openHeight : closedHeight
        x: root.width - BarMetrics.edgeMargin - width
        y: BarMetrics.stripHeight
        clip: true

        color: ShellState.centerOpen ? Colors.glass(0.6) : "transparent"
        radius: ShellState.centerOpen ? 20 : 13

        Behavior on height {
            // Deliberately not Easing.OutBack: this panel grows the height of
            // the screen, and any back-ease overshoots by a fraction of the
            // distance travelled, so it swings past its resting height and
            // springs back. OutQuint decelerates just as sharply but never
            // exceeds the target - the panel simply arrives at its size.
            NumberAnimation { duration: 340; easing.type: Easing.OutQuint }
        }
        Behavior on color { ColorAnimation { duration: 200 } }

        // Consume otherwise-unhandled clicks inside the panel so they do not
        // reach the click-away layer behind it. The gesture policy is what
        // makes that work: the default (DragThreshold) only takes a passive
        // grab, which leaves the click free to fall through and close the
        // panel. Handlers on the panel's own controls still fire.
        TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds }

        ColumnLayout {
            id: panelContent
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14
            opacity: ShellState.centerOpen ? 1 : 0
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 200 } }

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
                implicitHeight: 1
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
