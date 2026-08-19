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
// Sources of truth for the rows below, all of which stay authoritative:
//   Hyprland   config/hypr/hyprland.lua
//   Neovim     config/nvim/lua/keys.lua and lua/plugins/
//   Terminal   config/zsh/bindings.zsh
//   Herdr      config/herdr/config.toml
// Keep them in step by hand. The Launcher section is the exception: it is
// generated from the same LauncherCommands table the launcher itself renders,
// so it cannot drift.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    // Clamped to the screen the way the reference overlay is, so the panel
    // still fits when this config runs on the laptop rather than the 4K panel.
    readonly property int panelWidth:
        Math.min(1820, (screen ? screen.width : 1820) - 80)
    readonly property int keyColumnWidth: 150
    readonly property int rowHeight: 32
    readonly property int bodySize: 14

    readonly property int columnSpacing: 34
    // Columns are sized explicitly and evenly. Left to fillWidth alone the
    // layout apportions by implicit content width, which starved the last
    // column until its descriptions elided.
    readonly property int columnWidth:
        (panelWidth - 56 - columnSpacing * 3) / 4

    // Sections are assigned to a column by hand rather than flowed into a
    // grid: a grid sizes every row to its tallest section, which leaves large
    // voids under the short ones. Split this way each column carries 13-14
    // rows, so the columns end at roughly the same height.
    readonly property var columnA: [
        {
            title: "Applications",
            rows: [
                { keys: "Super Return", text: "Kitty terminal" },
                { keys: "Super Shift Return", text: "Herdr in Kitty" },
                { keys: "Super E", text: "Files (Nautilus)" },
                { keys: "Super Space", text: "Application launcher" }
            ]
        },
        { title: "Launcher", rows: root.launcherRows },
        {
            title: "Capture",
            rows: [
                { keys: "Alt Shift 3", text: "Monitor to Pictures" },
                { keys: "Alt Shift 4", text: "Region to clipboard" },
                { keys: "Alt Shift 5", text: "HyprQuickFrame" }
            ]
        },
        {
            title: "Dictation",
            rows: [
                { keys: "F1", text: "Hold to talk" },
                { keys: "F2", text: "Toggle dictation" }
            ]
        },
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
            title: "Workspaces",
            rows: [
                { keys: "Super 1 - 0", text: "Switch workspace" },
                { keys: "Super Shift 1 - 0", text: "Move window there" },
                { keys: "Super S", text: "Toggle magic workspace" },
                { keys: "Super Shift S", text: "Move window to magic" },
                { keys: "Three fingers", text: "Swipe between workspaces" }
            ]
        }
    ]

    readonly property var columnC: [
        {
            title: "Neovim",
            rows: [
                { keys: "Space W", text: "Save" },
                { keys: "Space E", text: "File browser" },
                { keys: "Space F", text: "Find files" },
                { keys: "Space S", text: "Search text" },
                { keys: "Space B", text: "Buffers" },
                { keys: "Space G", text: "Open Neogit" },
                { keys: "g d", text: "Go to definition" },
                { keys: "Ctrl A", text: "Select all" },
                { keys: "Visual p", text: "Paste, keep register" }
            ]
        },
        {
            title: "Terminal",
            rows: [
                { keys: "Ctrl R", text: "Fuzzy history search" },
                { keys: "Ctrl F", text: "Fuzzy files, no hidden" },
                { keys: "Ctrl T", text: "Fuzzy files, all" },
                { keys: "Up / Down", text: "Match typed history" },
                { keys: "Esc", text: "Vi command mode" }
            ]
        }
    ]

    readonly property var columnD: [
        {
            title: "Shell",
            rows: [
                { keys: "Super Escape", text: "Power menu" },
                { keys: "Super F1", text: "Wallpaper picker" },
                { keys: "Super Shift F1", text: "New wallpaper and theme" },
                { keys: "Alt Escape", text: "This cheat sheet" },
                { keys: "Super Scroll", text: "Volume up / down" },
                { keys: "Super Middle-click", text: "Mute" }
            ]
        },
        {
            title: "Herdr",
            rows: [
                { keys: "Ctrl B, H J K L", text: "Focus pane" },
                { keys: "Ctrl B, \"", text: "Split horizontally" },
                { keys: "Ctrl B, %", text: "Split vertically" },
                { keys: "Ctrl B, C", text: "New tab" },
                { keys: "Ctrl B, &", text: "Close tab" },
                { keys: "Ctrl B, W", text: "Workspace picker" },
                { keys: "Ctrl B, G", text: "Go to" },
                { keys: "Ctrl B, Y", text: "Copy mode" }
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
            Layout.bottomMargin: 5
            text: section.modelData.title.toUpperCase()
            color: Colors.accent
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 1.3
        }

        Repeater {
            model: section.modelData.rows

            Rectangle {
                id: shortcutRow
                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: root.rowHeight
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
                        Layout.preferredWidth: root.keyColumnWidth
                        Layout.minimumWidth: 0
                        Layout.fillHeight: true
                        text: shortcutRow.modelData.keys
                        color: Colors.text
                        font.pixelSize: root.bodySize
                        font.bold: true
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.fillHeight: true
                        text: shortcutRow.modelData.text
                        color: Colors.subtext
                        font.pixelSize: root.bodySize
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
        implicitHeight: content.implicitHeight + 56
        radius: 26
        color: Colors.glass(0.72)
        border.width: 1
        border.color: Colors.glass(0.95)
        focus: true

        Keys.onEscapePressed: root.close()

        TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 28
            spacing: 24

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Keyboard shortcuts"
                    color: Colors.text
                    font.pixelSize: 28
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Esc to close"
                    color: Colors.subtext
                    font.pixelSize: 15
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: root.columnSpacing

                Repeater {
                    model: [root.columnA, root.columnB, root.columnC, root.columnD]

                    ColumnLayout {
                        id: column
                        required property var modelData

                        Layout.preferredWidth: root.columnWidth
                        Layout.minimumWidth: 0
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 20

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
