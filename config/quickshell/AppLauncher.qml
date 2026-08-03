// Centered application launcher backed by Quickshell's native desktop-entry
// model. Opened through IPC by Hyprland's Super+Space binding.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    readonly property int panelWidth: 680
    readonly property int panelHeight: 620
    readonly property var applications: DesktopEntries.applications.values
        .filter(entry => !entry.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))
    readonly property var filteredApplications: {
        const terms = search.text.toLowerCase().trim().split(/\s+/).filter(Boolean);
        if (terms.length === 0)
            return applications;
        return applications.filter(entry => {
            const haystack = [entry.name, entry.genericName, entry.comment, entry.id]
                .filter(Boolean).join(" ").toLowerCase();
            return terms.every(term => haystack.includes(term));
        });
    }

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    exclusiveZone: -1
    visible: ShellState.launcherOpen
    color: "transparent"

    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.launcherOpen
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    function close() {
        ShellState.closeLauncher();
    }

    function launch(entry) {
        if (!entry)
            return;
        close();
        entry.execute();
    }

    onVisibleChanged: {
        if (visible) {
            search.text = "";
            results.currentIndex = 0;
            Qt.callLater(() => search.forceActiveFocus());
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { ShellState.toggleLauncher(); }
        function open(): void { ShellState.openLauncher(); }
        function close(): void { ShellState.closeLauncher(); }
    }

    // Full-screen click-away target. The panel itself consumes clicks so only
    // the transparent surrounding area closes the launcher.
    Item {
        anchors.fill: parent
        TapHandler { onTapped: root.close() }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: root.panelWidth
        height: root.panelHeight
        radius: 24
        color: Colors.glass(0.72)
        border.width: 1
        border.color: Colors.glass(0.95)

        TapHandler {}

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

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    Text {
                        text: "⌕"
                        color: Colors.subtext
                        font.pixelSize: 22
                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 24

                        TextInput {
                            id: search
                            anchors.fill: parent
                            color: Colors.text
                            selectionColor: Colors.accent
                            selectedTextColor: Colors.accentText
                            font.pixelSize: 16
                            clip: true

                            Keys.onEscapePressed: root.close()
                            Keys.onDownPressed: results.incrementCurrentIndex()
                            Keys.onUpPressed: results.decrementCurrentIndex()
                            Keys.onReturnPressed: root.launch(root.filteredApplications[results.currentIndex])
                            Keys.onEnterPressed: root.launch(root.filteredApplications[results.currentIndex])

                            onTextChanged: results.currentIndex = 0
                        }

                        Text {
                            anchors.fill: parent
                            visible: search.text.length === 0
                            text: "Type to search applications"
                            color: Colors.subtext
                            font.pixelSize: 14
                        }
                    }

                    Text {
                        text: root.filteredApplications.length + " apps"
                        color: Colors.subtext
                        font.pixelSize: 12
                    }
                }
            }

            ListView {
                id: results
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: root.filteredApplications
                currentIndex: 0
                keyNavigationWraps: true

                delegate: Rectangle {
                    id: appRow
                    required property var modelData
                    required property int index

                    width: ListView.view ? ListView.view.width : 0
                    height: 60
                    radius: 14
                    color: (ListView.isCurrentItem || rowHover.hovered)
                        ? Colors.glass(0.9)
                        : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Image {
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 38
                            source: Quickshell.iconPath(appRow.modelData.icon, "application-x-executable")
                            sourceSize.width: 38
                            sourceSize.height: 38
                            fillMode: Image.PreserveAspectFit
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: appRow.modelData.name
                                color: Colors.text
                                font.pixelSize: 16
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: appRow.modelData.genericName || appRow.modelData.comment || ""
                                color: Colors.subtext
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            visible: ListView.isCurrentItem
                            text: "↵"
                            color: Colors.accent
                            font.pixelSize: 18
                        }
                    }

                    HoverHandler {
                        id: rowHover
                        onHoveredChanged: if (hovered) results.currentIndex = appRow.index
                    }
                    TapHandler { onTapped: root.launch(appRow.modelData) }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.filteredApplications.length === 0
                    text: "No matching applications"
                    color: Colors.subtext
                    font.pixelSize: 14
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "↑↓ Navigate   Enter Launch   Esc Close"
                    color: Colors.subtext
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }

                Text {
                    text: "Quickshell"
                    color: Colors.accent
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }
    }
}
