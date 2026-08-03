// Centered Quickshell power menu. Destructive session actions require a
// second confirmation step; lock and suspend remain immediate.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property string pendingAction: ""
    property int currentIndex: 0
    property int confirmationIndex: 0
    readonly property var actions: [
        { name: "Lock", icon: "󰌾", command: [Quickshell.env("HOME") + "/.config/hypr/start-hyprlock"], confirm: false },
        { name: "Suspend", icon: "󰒲", command: ["systemctl", "suspend"], confirm: false },
        { name: "Logout", icon: "󰍃", command: ["hyprctl", "dispatch", "exit"], confirm: true },
        { name: "Reboot", icon: "󰜉", command: ["systemctl", "reboot"], confirm: true },
        { name: "Shutdown", icon: "󰐥", command: ["systemctl", "poweroff"], confirm: true }
    ]

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    exclusiveZone: -1
    visible: ShellState.powerMenuOpen
    color: "transparent"

    WlrLayershell.namespace: "quickshell-power"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function close() {
        pendingAction = "";
        ShellState.powerMenuOpen = false;
    }

    function choose(action) {
        if (action.confirm) {
            pendingAction = action.name;
            confirmationIndex = 0;
            panel.forceActiveFocus();
            return;
        }
        execute(action);
    }

    function execute(action) {
        close();
        actionProcess.command = action.command;
        actionProcess.startDetached();
    }

    function actionNamed(name) {
        return actions.find(action => action.name === name);
    }

    function moveSelection(delta) {
        currentIndex = (currentIndex + delta + actions.length) % actions.length;
    }

    onVisibleChanged: {
        pendingAction = "";
        currentIndex = 0;
        confirmationIndex = 0;
        if (visible)
            Qt.callLater(() => panel.forceActiveFocus());
    }

    IpcHandler {
        target: "powermenu"
        function toggle(): void { ShellState.togglePowerMenu(); }
        function close(): void { root.close(); }
    }

    Process { id: actionProcess }

    Item {
        anchors.fill: parent
        TapHandler { onTapped: root.close() }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: 620
        height: root.pendingAction.length > 0 ? 250 : 190
        radius: 24
        color: Colors.glass(0.72)
        border.width: 1
        border.color: Colors.glass(0.95)
        focus: root.visible

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (root.pendingAction.length > 0)
                    root.pendingAction = "";
                else
                    root.close();
                event.accepted = true;
                return;
            }

            if (root.pendingAction.length > 0) {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_H || event.key === Qt.Key_K) {
                    root.confirmationIndex = (root.confirmationIndex + 1) % 2;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_L || event.key === Qt.Key_J) {
                    root.confirmationIndex = (root.confirmationIndex + 1) % 2;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.confirmationIndex === 0)
                        root.pendingAction = "";
                    else
                        root.execute(root.actionNamed(root.pendingAction));
                    event.accepted = true;
                } else if (event.key === Qt.Key_Y) {
                    root.execute(root.actionNamed(root.pendingAction));
                    event.accepted = true;
                } else if (event.key === Qt.Key_N) {
                    root.pendingAction = "";
                    event.accepted = true;
                }
                return;
            }

            if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_H || event.key === Qt.Key_K) {
                root.moveSelection(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_L || event.key === Qt.Key_J) {
                root.moveSelection(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.choose(root.actions[root.currentIndex]);
                event.accepted = true;
            }
        }
        TapHandler {}

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.pendingAction.length > 0
                    ? "Confirm " + root.pendingAction.toLowerCase() + "?"
                    : "Power"
                color: Colors.text
                font.pixelSize: 18
                font.bold: true
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10
                visible: root.pendingAction.length === 0

                Repeater {
                    model: root.actions
                    delegate: Rectangle {
                        id: actionButton
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 16
                        color: actionHover.hovered || root.currentIndex === actionButton.index
                            ? Colors.glass(0.95) : Colors.glass(0.55)
                        border.width: root.currentIndex === actionButton.index ? 2 : 1
                        border.color: root.currentIndex === actionButton.index ? Colors.accent : Colors.glass(0.8)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: actionButton.modelData.icon
                                color: actionButton.modelData.name === "Shutdown" ? Colors.alert : Colors.accent
                                font.pixelSize: 28
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: actionButton.modelData.name
                                color: Colors.text
                                font.pixelSize: 14
                            }
                        }
                        HoverHandler {
                            id: actionHover
                            onHoveredChanged: if (hovered) root.currentIndex = actionButton.index
                        }
                        TapHandler { onTapped: root.choose(actionButton.modelData) }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12
                visible: root.pendingAction.length > 0

                Rectangle {
                    readonly property bool selected: root.confirmationIndex === 0
                    implicitWidth: 130
                    implicitHeight: 48
                    radius: 14
                    color: cancelHover.hovered || selected ? Colors.glass(0.95) : Colors.glass(0.55)
                    border.width: selected ? 2 : 1
                    border.color: selected ? Colors.accent : Colors.glass(0.8)
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Colors.text; font.pixelSize: 14 }
                    HoverHandler {
                        id: cancelHover
                        onHoveredChanged: if (hovered) root.confirmationIndex = 0
                    }
                    TapHandler { onTapped: root.pendingAction = "" }
                }

                Rectangle {
                    readonly property bool selected: root.confirmationIndex === 1
                    implicitWidth: 130
                    implicitHeight: 48
                    radius: 14
                    color: confirmHover.hovered || selected ? Colors.alert : Colors.glass(0.55)
                    border.width: selected ? 2 : 1
                    border.color: selected ? Colors.alert : Colors.glass(0.8)
                    Text { anchors.centerIn: parent; text: "Confirm"; color: Colors.text; font.pixelSize: 14; font.bold: true }
                    HoverHandler {
                        id: confirmHover
                        onHoveredChanged: if (hovered) root.confirmationIndex = 1
                    }
                    TapHandler { onTapped: root.execute(root.actionNamed(root.pendingAction)) }
                }
            }
        }
    }
}
