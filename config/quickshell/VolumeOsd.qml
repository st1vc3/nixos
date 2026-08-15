import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root
    anchors.bottom: true
    exclusiveZone: -1
    color: "transparent"
    implicitWidth: 330
    implicitHeight: 110
    property bool showing: false
    visible: showing

    WlrLayershell.namespace: "quickshell-volume-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Connections {
        target: SystemStatus
        function onOsdSerialChanged() {
            root.showing = true;
            hideTimer.restart();
        }
    }
    Timer { id: hideTimer; interval: 1200; onTriggered: root.showing = false }

    Rectangle {
        anchors.centerIn: parent
        width: 286; height: 64; radius: 20
        color: Colors.glass(0.82)
        border.width: 1; border.color: Colors.glass(0.95)
        RowLayout {
            anchors.fill: parent; anchors.margins: 16; spacing: 14
            Text {
                text: SystemStatus.sinkMuted ? "" : SystemStatus.volumeIcon
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20
                color: SystemStatus.sinkMuted ? Colors.subtext : Colors.text
            }
            Rectangle {
                Layout.fillWidth: true; height: 7; radius: 4; color: Colors.glass(0.95)
                Rectangle {
                    width: parent.width * (SystemStatus.sinkMuted ? 0 : SystemStatus.volume)
                    height: parent.height; radius: parent.radius; color: Colors.accent
                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }
            }
            Text { text: Math.round(SystemStatus.volume * 100); color: Colors.text; font.pixelSize: 13; font.bold: true }
        }
    }

    IpcHandler {
        target: "audio"
        function raise(): void { SystemStatus.changeVolume(0.05) }
        function lower(): void { SystemStatus.changeVolume(-0.05) }
        function mute(): void { SystemStatus.toggleSinkMute() }
        function micmute(): void { SystemStatus.toggleMicMute() }
    }
}
