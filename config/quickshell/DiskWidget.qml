// Storage widget for the notification centre: a usage ring for the root
// filesystem plus a per-mount breakdown. Binds to the SystemStats singleton.

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: widget
    spacing: 12

    readonly property int rootPct: SystemStats.rootDisk.pct || 0
    readonly property color rootColor: rootPct >= 90 ? Colors.alert : Colors.accent

    // Header: ring + summary.
    RowLayout {
        Layout.fillWidth: true
        spacing: 16

        Item {
            implicitWidth: 76
            implicitHeight: 76

            Ring {
                anchors.fill: parent
                thickness: 7
                value: widget.rootPct / 100
                fillColor: widget.rootColor
            }

            Text {
                anchors.centerIn: parent
                text: widget.rootPct + "%"
                color: Colors.text
                font.pixelSize: 18
                font.bold: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: "Storage"
                color: Colors.text
                font.pixelSize: 18
                font.bold: true
            }
            Text {
                text: SystemStats.human(SystemStats.rootDisk.used) + " / "
                      + SystemStats.human(SystemStats.rootDisk.size) + " used"
                color: Colors.subtext
                font.pixelSize: 18
            }
        }
    }

    // Per-mount breakdown bars.
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: SystemStats.disks

            delegate: ColumnLayout {
                id: mount
                required property var modelData
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: mount.modelData.target
                        color: Colors.text
                        font.pixelSize: 18
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: (mount.modelData.pct || 0) + "%"
                        color: (mount.modelData.pct || 0) >= 90 ? Colors.alert : Colors.subtext
                        font.pixelSize: 18
                    }
                }

                // Track + fill bar.
                Rectangle {
                    Layout.fillWidth: true
                    height: 4
                    radius: 2
                    color: Colors.glass(0.35)

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        width: parent.width * Math.max(0, Math.min(1, (mount.modelData.pct || 0) / 100))
                        color: (mount.modelData.pct || 0) >= 90 ? Colors.alert : Colors.accent
                    }
                }
            }
        }
    }
}
