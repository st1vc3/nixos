// Keyboard shortcut reference, modelled on the macosx repo's Hammerspoon
// overlay (home/.hammerspoon/init.lua there): a centred glass panel with the
// bindings grouped into columns. Bound to Alt+Escape, the same physical keys
// as the Mac's Option+Escape, so the muscle memory carries between machines.
//
// The Mac shows it while the keys are held. Hyprland's Lua config here has no
// verified release-binding, and every other surface in this shell is an IPC
// toggle, so this one toggles too: Alt+Escape opens it, Alt+Escape or Esc
// closes it.
//
// The shortcut sections below are written by hand and config/hypr/hyprland.lua
// stays the source of truth for what the keys actually do - keep them in step.
// The Launcher section is the exception: it is generated from the same
// LauncherCommands table the launcher itself renders, so it cannot drift.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    readonly property int panelWidth: 1240

    // Sections are assigned to a column by hand rather than flowed into a
    // grid: a grid sizes every row to its tallest section, which leaves large
    // voids under the short ones. Split this way each column carries 11 rows.
    readonly property var columnA: [
        {
            title: "Applications",
            rows: [
                { keys: "Super Return", text: "Kitty terminal" },
                { keys: "Super Shift Return", text: "Herdr in Kitty" },
                { keys: "Super E", text: "File manager" },
                { keys: "Super Space", text: "Application launcher" }
            ]
        },
        { title: "Launcher", rows: root.launcherRows },
        {
            title: "Session",
            rows: [
                { keys: "Super Shift Q", text: "Lock screen" },
                { keys: "Super M", text: "Exit Hyprland" }
            ]
        }
    ]

    readonly property var columnB: [
        {
            title: "Windows",
            rows: [
                { keys: "Super Q", text: "Close window" },
                { keys: "Super V", text: "Toggle floating" },
                { keys: "Super F", text: "Fullscreen" },
                { keys: "Super P", text: "Pseudotile" },
                { keys: "Super J", text: "Toggle split" },
                { keys: "Super Arrows", text: "Focus in direction" },
                { keys: "Super Drag", text: "Move window" },
                { keys: "Super Right-drag", text: "Resize window" }
            ]
        },
        {
            title: "Capture",
            rows: [
                { keys: "Alt Shift 3", text: "Monitor to Pictures" },
                { keys: "Alt Shift 4", text: "Region to clipboard" },
                { keys: "Alt Shift 5", text: "HyprQuickFrame" }
            ]
        }
    ]

    readonly property var columnC: [
        {
            title: "Workspaces",
            rows: [
                { keys: "Super 1 - 0", text: "Switch workspace" },
                { keys: "Super Shift 1 - 0", text: "Move window there" },
                { keys: "Super S", text: "Toggle magic workspace" },
                { keys: "Super Shift S", text: "Move window to magic" },
                { keys: "Three fingers", text: "Swipe between workspaces" }
            ]
        },
        {
            title: "Shell",
            rows: [
                { keys: "Super Escape", text: "Power menu" },
                { keys: "Super F1", text: "Wallpaper picker" },
                { keys: "Super Shift F1", text: "Re-roll wallpaper and theme" },
                { keys: "Alt Escape", text: "This cheat sheet" },
                { keys: "Super Scroll", text: "Volume up / down" },
                { keys: "Super Middle-click", text: "Mute" }
            ]
        }
    ]

    // Launcher commands come straight from the launcher's own table, so a new
    // command appears here without this file being touched.
    readonly property var launcherRows: LauncherCommands.list.map(cmd => ({
        keys: cmd.keyword, text: cmd.label
    }))

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    exclusiveZone: -1
    visible: ShellState.cheatsheetOpen
    color: "transparent"

    WlrLayershell.namespace: "quickshell-cheatsheet"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function close() {
        ShellState.cheatsheetOpen = false;
    }

    onVisibleChanged: {
        if (visible)
            Qt.callLater(() => panel.forceActiveFocus());
    }

    IpcHandler {
        target: "cheatsheet"
        function toggle(): void { ShellState.toggleCheatsheet(); }
        function open(): void { ShellState.openCheatsheet(); }
        function close(): void { root.close(); }
    }

    Item {
        anchors.fill: parent
        TapHandler { onTapped: root.close() }
    }

    component Section: ColumnLayout {
        id: section
        required property var modelData

        Layout.fillWidth: true
        spacing: 2

        Text {
            Layout.bottomMargin: 4
            text: section.modelData.title.toUpperCase()
            color: Colors.accent
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1.25
        }

        Repeater {
            model: section.modelData.rows

            Rectangle {
                id: shortcutRow
                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: 27
                color: "transparent"

                // Hairline between rows. Deliberately white rather than a
                // Colors role: it has to read as a faint edge on top of the
                // glass, and the palette's surface tints vanish against it.
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    visible: shortcutRow.index > 0
                    color: Qt.rgba(1, 1, 1, 0.06)
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 12

                    Text {
                        Layout.preferredWidth: 136
                        Layout.fillHeight: true
                        text: shortcutRow.modelData.keys
                        color: Colors.text
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: shortcutRow.modelData.text
                        color: Colors.subtext
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: root.panelWidth
        implicitHeight: content.implicitHeight + 44
        radius: 24
        color: Colors.glass(0.72)
        border.width: 1
        border.color: Colors.glass(0.95)
        focus: true

        Keys.onEscapePressed: root.close()

        TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 22
            spacing: 20

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Keyboard shortcuts"
                    color: Colors.text
                    font.pixelSize: 24
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Esc to close"
                    color: Colors.subtext
                    font.pixelSize: 13
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 30

                Repeater {
                    model: [root.columnA, root.columnB, root.columnC]

                    ColumnLayout {
                        id: column
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 18

                        Repeater {
                            model: column.modelData
                            Section {}
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }
}
