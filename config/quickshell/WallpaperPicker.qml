// Searchable wallpaper picker with live thumbnails. Files come from the locked
// wallpaper flake exposed at ~/Pictures/wallpapers by Home Manager.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    readonly property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/wallpapers"
    property var wallpapers: []
    readonly property var filteredWallpapers: {
        const term = search.text.toLowerCase().trim();
        if (term.length === 0)
            return wallpapers;
        return wallpapers.filter(path => root.relativeName(path).toLowerCase().includes(term));
    }

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    exclusiveZone: -1
    visible: ShellState.wallpaperPickerOpen
    color: "transparent"

    WlrLayershell.namespace: "quickshell-wallpaper"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function close() { ShellState.wallpaperPickerOpen = false; }
    function relativeName(path) { return path.slice(wallpaperDir.length + 1); }
    function refresh() {
        wallpapers = [];
        finder.running = true;
    }
    function apply(path) {
        if (!path)
            return;
        close();
        setter.command = [Quickshell.env("HOME") + "/Scripts/set-wallpaper.sh", path];
        setter.startDetached();
    }

    function moveSelection(delta) {
        if (filteredWallpapers.length === 0)
            return;
        grid.currentIndex = Math.max(0, Math.min(grid.currentIndex + delta, filteredWallpapers.length - 1));
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
    }

    function applyCurrent() {
        if (grid.currentIndex >= 0 && grid.currentIndex < filteredWallpapers.length)
            apply(filteredWallpapers[grid.currentIndex]);
    }

    onVisibleChanged: {
        if (visible) {
            search.text = "";
            refresh();
            grid.currentIndex = 0;
            Qt.callLater(() => grid.forceActiveFocus());
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { ShellState.toggleWallpaperPicker(); }
        function close(): void { root.close(); }
    }

    Process {
        id: finder
        command: [
            "find", "-L", root.wallpaperDir, "-type", "f", "(",
            "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o",
            "-iname", "*.png", "-o", "-iname", "*.webp", ")"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wallpapers = this.text.split("\n")
                    .filter(path => path.length > 0)
                    .sort((a, b) => a.localeCompare(b));
            }
        }
    }

    Process { id: setter }

    Item {
        anchors.fill: parent
        TapHandler { onTapped: root.close() }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 760
        height: 650
        radius: 24
        color: Colors.glass(0.72)
        border.width: 1
        border.color: Colors.glass(0.95)

        // Consume clicks inside the panel so they do not reach the click-away
        // layer behind it; the default gesture policy would let them through.
        TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: 16
                color: Colors.glass(0.72)
                border.width: search.activeFocus ? 2 : 1
                border.color: search.activeFocus ? Colors.accent : Colors.glass(0.95)

                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.margins: 14
                    color: Colors.text
                    selectionColor: Colors.accent
                    selectedTextColor: Colors.accentText
                    font.pixelSize: 16
                    clip: true
                    onTextChanged: grid.currentIndex = 0
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            if (text.length > 0)
                                text = "";
                            grid.forceActiveFocus();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            root.moveSelection(3);
                            grid.forceActiveFocus();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            root.moveSelection(-3);
                            grid.forceActiveFocus();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.applyCurrent();
                            event.accepted = true;
                        }
                    }
                }

                Text {
                    anchors.fill: search
                    visible: search.text.length === 0
                    text: "Search " + root.wallpapers.length + " wallpapers"
                    color: Colors.subtext
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: 237
                cellHeight: 166
                model: root.filteredWallpapers
                currentIndex: 0
                focus: true

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.close();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Slash) {
                        search.forceActiveFocus();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                        root.moveSelection(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                        root.moveSelection(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        root.moveSelection(3);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        root.moveSelection(-3);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.applyCurrent();
                        event.accepted = true;
                    }
                }

                delegate: Rectangle {
                    id: tile
                    required property string modelData
                    required property int index
                    width: 225
                    height: 154
                    radius: 16
                    color: tileHover.hovered ? Colors.glass(0.95) : Colors.glass(0.45)
                    border.width: grid.currentIndex === tile.index ? 3 : 1
                    border.color: grid.currentIndex === tile.index ? Colors.accent : Colors.glass(0.8)
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 5
                        source: "file://" + encodeURI(tile.modelData)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 36
                        color: Colors.glass(0.9)
                        Text {
                            anchors.fill: parent
                            anchors.margins: 8
                            text: root.relativeName(tile.modelData)
                            color: Colors.text
                            font.pixelSize: 12
                            elide: Text.ElideMiddle
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    HoverHandler {
                        id: tileHover
                        onHoveredChanged: if (hovered) grid.currentIndex = tile.index
                    }
                    TapHandler { onTapped: root.apply(tile.modelData) }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.filteredWallpapers.length === 0
                    text: finder.running ? "Loading wallpapers…" : "No matching wallpapers"
                    color: Colors.subtext
                    font.pixelSize: 14
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Arrows or h/j/k/l select   •   Enter applies   •   / searches   •   Esc closes"
                color: Colors.subtext
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
