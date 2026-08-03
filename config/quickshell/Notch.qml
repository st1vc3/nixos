// macOS-style dynamic notch: an opaque black pill hanging from the top-centre
// of the screen showing the clock, which springs open on hover to reveal the
// date and a month calendar. Runs as its own layer-shell surface, floating
// over windows without reserving space.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    // Injected by the Variants delegate in shell.qml (one notch per screen).
    property var modelData
    screen: modelData

    // Anchoring to the top edge only (no left/right) centres the surface
    // horizontally on that edge - exactly where a notch lives.
    anchors.top: true

    // Reserve exactly the collapsed pill height so windows tile *below* the
    // notch and never sit under it - a fixed strip along the top edge, like a
    // minimal bar. It stays pinned to the collapsed height on purpose: the
    // hover expansion grows past it as a transient overlay and must NOT push
    // windows down, so this is bound to collapsedHeight, not the live height.
    exclusiveZone: root.collapsedHeight
    color: "transparent"

    WlrLayershell.namespace: "quickshell-notch"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // The surface is sized for the fully expanded panel; the black shape
    // animates within it while everything around it stays transparent.
    implicitWidth: 440
    implicitHeight: 380

    // Restrict input to the visible notch shape, otherwise the large
    // transparent surface would swallow clicks meant for the windows
    // underneath it.
    mask: Region {
        item: shape
    }

    property bool expanded: false

    readonly property real collapsedWidth: 190
    readonly property real collapsedHeight: 34
    readonly property real expandedWidth: 360
    readonly property real expandedHeight: 320

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Process {
        id: calendarProcess
        // Keep this explicit so the launcher also works immediately after a
        // NixOS switch, before the long-running Wayland session has inherited
        // NixOS's TZDIR environment on its next login.
        command: ["env", "TZDIR=/etc/zoneinfo", "gnome-calendar"]
    }

    function pad(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    Rectangle {
        id: shape
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#000000"

        width: root.expanded ? root.expandedWidth : root.collapsedWidth
        height: root.expanded ? root.expandedHeight : root.collapsedHeight

        // Square where it meets the screen edge, rounded where it hangs into
        // the display - the defining notch silhouette (Qt 6.7+ per-corner).
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: root.expanded ? 28 : 18
        bottomRightRadius: root.expanded ? 28 : 18

        Behavior on width {
            NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
        Behavior on height {
            NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }

        HoverHandler {
            id: hover
            onHoveredChanged: root.expanded = hovered
        }

        // Collapsed clock: centred in the pill, fades out as it expands.
        Text {
            anchors.centerIn: parent
            text: root.pad(clock.hours) + ":" + root.pad(clock.minutes)
            color: Colors.text
            font.pixelSize: 16
            font.bold: true
            opacity: root.expanded ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // Expanded panel: big time + date header and the month calendar.
        // Fades in slightly after the shape has started growing.
        ColumnLayout {
            id: content
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 18
            width: root.expandedWidth - 40
            spacing: 12

            opacity: root.expanded ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: root.pad(clock.hours) + ":" + root.pad(clock.minutes)
                    color: Colors.text
                    font.pixelSize: 34
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Text {
                    horizontalAlignment: Text.AlignRight
                    text: Qt.formatDate(clock.date, "ddd\nd MMM")
                    color: Colors.subtext
                    font.pixelSize: 13
                    lineHeight: 1.1
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Colors.outline
                opacity: 0.4
            }

            Calendar {
                Layout.alignment: Qt.AlignHCenter
                today: clock.date
                onActivated: calendarProcess.startDetached()
            }
        }
    }
}
