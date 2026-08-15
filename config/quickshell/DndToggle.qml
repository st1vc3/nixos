// Do-not-disturb row for the notification centre: a labelled switch that
// silences toast popups while still collecting them in the history. The state
// itself lives on the Notifications singleton.

import QtQuick
import QtQuick.Layouts

Rectangle {
    implicitHeight: 44
    radius: 12
    color: hover.hovered ? Colors.glass(0.95) : Colors.glass(0.8)

    Behavior on color { ColorAnimation { duration: 120 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Text {
            text: "" // Nerd Font bell-slash
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: Notifications.dnd ? Colors.accent : Colors.subtext
        }

        Text {
            text: "Do not disturb"
            color: Colors.text
            font.pixelSize: 14
            Layout.fillWidth: true
        }

        // Track and knob.
        Rectangle {
            implicitWidth: 40
            implicitHeight: 22
            radius: height / 2
            color: Notifications.dnd ? Colors.accent : Colors.glass(0.9)
            border.width: 1
            border.color: Notifications.dnd ? Colors.accent : Colors.outline

            Behavior on color { ColorAnimation { duration: 140 } }

            Rectangle {
                width: 16
                height: 16
                radius: height / 2
                y: (parent.height - height) / 2
                x: Notifications.dnd ? parent.width - width - 3 : 3
                color: Notifications.dnd ? Colors.accentText : Colors.subtext

                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 140 } }
            }
        }
    }

    HoverHandler { id: hover }
    TapHandler { onTapped: Notifications.toggleDnd() }
}
