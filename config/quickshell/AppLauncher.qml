// Centered application launcher backed by Quickshell's native desktop-entry
// model. Opened through IPC by Hyprland's Super+Space binding.
//
// Typing "cli" and pressing Enter switches the launcher into a clipboard
// manager (Raycast-style): it lists cliphist history, stays searchable, is
// navigable with the arrow keys, and Enter re-copies the highlighted entry to
// the clipboard. Esc steps back to application mode.

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

    // "apps" browses desktop entries, "clipboard" browses cliphist history.
    property string mode: "apps"
    readonly property bool clipMode: mode === "clipboard"

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

    // Each item is { id, preview }: id is cliphist's numeric row key, preview is
    // its single-line description used for both display and searching.
    property var clipboardItems: []
    readonly property var filteredClipboard: {
        const query = search.text.toLowerCase().trim();
        if (query.length === 0)
            return clipboardItems;
        return clipboardItems.filter(item => item.preview.toLowerCase().includes(query));
    }

    // True when the app-mode query is the clipboard trigger, so the footer can
    // hint that Enter opens the clipboard rather than launching an app.
    readonly property bool clipTriggerArmed: !clipMode
        && search.text.trim().toLowerCase() === "cli"

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

    function enterClipboardMode() {
        mode = "clipboard";
        search.text = "";
        clipboardItems = [];
        clipResults.currentIndex = 0;
        clipLister.running = true;
    }

    function exitClipboardMode() {
        mode = "apps";
        search.text = "";
        results.currentIndex = 0;
    }

    // Re-copy a history entry. cliphist decode resolves the raw payload for the
    // numeric id (text or image); wl-copy places it back on the clipboard so it
    // becomes the current paste target.
    function copyClip(item) {
        if (!item)
            return;
        close();
        clipCopy.command = ["sh", "-c", "cliphist decode " + item.id + " | wl-copy"];
        clipCopy.startDetached();
    }

    function moveSelection(delta) {
        const view = clipMode ? clipResults : results;
        if (delta > 0)
            view.incrementCurrentIndex();
        else
            view.decrementCurrentIndex();
    }

    function submit() {
        if (clipMode) {
            copyClip(filteredClipboard[clipResults.currentIndex]);
            return;
        }
        if (clipTriggerArmed) {
            enterClipboardMode();
            return;
        }
        launch(filteredApplications[results.currentIndex]);
    }

    function goBackOrClose() {
        if (clipMode)
            exitClipboardMode();
        else
            close();
    }

    onVisibleChanged: {
        if (visible) {
            mode = "apps";
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

    // Reads the clipboard history. cliphist list emits one "<id>\t<preview>" row
    // per entry, newest first.
    Process {
        id: clipLister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.clipboardItems = this.text.split("\n")
                    .filter(line => line.length > 0)
                    .map(line => {
                        const tab = line.indexOf("\t");
                        if (tab < 0)
                            return { id: line, preview: line };
                        return { id: line.slice(0, tab), preview: line.slice(tab + 1) };
                    });
            }
        }
    }

    Process { id: clipCopy }

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
                        text: root.clipMode ? "🖹" : "⌕"
                        color: root.clipMode ? Colors.accent : Colors.subtext
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

                            Keys.onEscapePressed: root.goBackOrClose()
                            Keys.onDownPressed: root.moveSelection(1)
                            Keys.onUpPressed: root.moveSelection(-1)
                            Keys.onReturnPressed: root.submit()
                            Keys.onEnterPressed: root.submit()

                            onTextChanged: {
                                if (root.clipMode)
                                    clipResults.currentIndex = 0;
                                else
                                    results.currentIndex = 0;
                            }
                        }

                        Text {
                            anchors.fill: parent
                            visible: search.text.length === 0
                            text: root.clipMode
                                ? "Search clipboard history"
                                : "Type to search applications"
                            color: Colors.subtext
                            font.pixelSize: 14
                        }
                    }

                    Text {
                        text: root.clipMode
                            ? root.filteredClipboard.length + " items"
                            : root.filteredApplications.length + " apps"
                        color: Colors.subtext
                        font.pixelSize: 12
                    }
                }
            }

            // Application results.
            ListView {
                id: results
                visible: !root.clipMode
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

            // Clipboard history results.
            ListView {
                id: clipResults
                visible: root.clipMode
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: root.filteredClipboard
                currentIndex: 0
                keyNavigationWraps: true

                delegate: Rectangle {
                    id: clipRow
                    required property var modelData
                    required property int index

                    width: ListView.view ? ListView.view.width : 0
                    height: 52
                    radius: 14
                    color: (ListView.isCurrentItem || clipHover.hovered)
                        ? Colors.glass(0.9)
                        : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        Text {
                            text: "🖹"
                            color: Colors.subtext
                            font.pixelSize: 16
                        }

                        Text {
                            Layout.fillWidth: true
                            text: clipRow.modelData.preview
                            color: Colors.text
                            font.pixelSize: 15
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: ListView.isCurrentItem
                            text: "↵"
                            color: Colors.accent
                            font.pixelSize: 18
                        }
                    }

                    HoverHandler {
                        id: clipHover
                        onHoveredChanged: if (hovered) clipResults.currentIndex = clipRow.index
                    }
                    TapHandler { onTapped: root.copyClip(clipRow.modelData) }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.filteredClipboard.length === 0
                    text: "Clipboard history is empty"
                    color: Colors.subtext
                    font.pixelSize: 14
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: root.clipMode
                        ? "↑↓ Navigate   Enter Copy   Esc Back"
                        : (root.clipTriggerArmed
                            ? "↵ Open clipboard history"
                            : "↑↓ Navigate   Enter Launch   Esc Close")
                    color: root.clipTriggerArmed ? Colors.accent : Colors.subtext
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }

                Text {
                    text: root.clipMode ? "Clipboard" : "Quickshell"
                    color: Colors.accent
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }
    }
}
