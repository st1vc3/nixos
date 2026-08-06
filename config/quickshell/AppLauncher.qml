// Centered application launcher backed by Quickshell's native desktop-entry
// model. Opened through IPC by Hyprland's Super+Space binding.
//
// Beyond launching apps the search box doubles as a command bar. Typing a
// keyword and pressing Enter switches into a focused mode:
//   cli      clipboard manager (cliphist history, text + image quick-look)
//   ssh      SSH connector (known hosts, opens a terminal session)
//   nsearch  Nix package search (queries nixpkgs, copies the attribute)
// and two inline web searches act on Enter without a mode switch:
//   yt <q>   open YouTube results for <q> in the default browser
//   ggl <q>  open Google results for <q> in the default browser
//
// No row is ever preselected: the highlight only appears once the user
// navigates, and Enter falls back to the top result.

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

    // "apps" | "clipboard" | "ssh" | "nsearch".
    property string mode: "apps"
    readonly property bool clipMode: mode === "clipboard"

    readonly property string query: search.text.trim()

    // --- Applications -------------------------------------------------------
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

    // In app mode the query is parsed into a command descriptor so the footer
    // can preview what Enter does and submit() can act on it. Recognised
    // commands take over the panel with a single action card instead of the
    // app list.
    readonly property var appAction: {
        const q = root.query;
        const lower = q.toLowerCase();
        if (lower === "cli")
            return { type: "mode", target: "clipboard", label: "Open clipboard history" };
        if (lower === "ssh")
            return { type: "mode", target: "ssh", label: "SSH to a host" };
        if (lower === "nsearch")
            return { type: "mode", target: "nsearch", label: "Search Nix packages" };
        if (lower === "yt" || lower.startsWith("yt ")) {
            const term = q.slice(2).trim();
            return {
                type: "web", ready: term.length > 0,
                url: "https://www.youtube.com/results?search_query=" + encodeURIComponent(term),
                label: term.length ? "Search YouTube for “" + term + "”" : "Type a YouTube query"
            };
        }
        if (lower === "ggl" || lower.startsWith("ggl ")) {
            const term = q.slice(3).trim();
            return {
                type: "web", ready: term.length > 0,
                url: "https://www.google.com/search?q=" + encodeURIComponent(term),
                label: term.length ? "Search Google for “" + term + "”" : "Type a Google query"
            };
        }
        return { type: "apps" };
    }
    readonly property bool actionActive: mode === "apps" && appAction.type !== "apps"

    // --- Clipboard (cliphist) ----------------------------------------------
    // Each item is { id, preview }: id is cliphist's numeric row key, preview
    // its single-line description used for display and searching.
    property var clipboardItems: []
    readonly property var filteredClipboard: {
        const q = search.text.toLowerCase().trim();
        if (q.length === 0)
            return clipboardItems;
        return clipboardItems.filter(item => item.preview.toLowerCase().includes(q));
    }
    // cliphist renders binary payloads as "[[ binary data <size> <type> WxH ]]".
    function isImageClip(item) {
        return !!item && /\[\[ binary data .*\b(png|jpe?g|gif|webp|bmp|tiff?|ico)\b/i.test(item.preview);
    }
    function clipDims(item) {
        const m = item ? item.preview.match(/(\d+x\d+)\s*\]\]/) : null;
        return m ? m[1] : "";
    }
    property string previewSource: ""
    property string previewDims: ""

    // --- SSH ----------------------------------------------------------------
    property var sshHosts: []
    readonly property var filteredSshHosts: {
        const q = search.text.toLowerCase().trim();
        if (q.length === 0)
            return sshHosts;
        return sshHosts.filter(host => host.toLowerCase().includes(q));
    }

    // --- Nix package search -------------------------------------------------
    property var nixItems: []
    property bool nixSearching: false

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

    function openUrl(url) {
        if (!url)
            return;
        close();
        webOpen.command = ["xdg-open", url];
        webOpen.startDetached();
    }

    function switchMode(target) {
        mode = target;
        search.text = "";
        previewSource = "";
        if (target === "clipboard") {
            clipboardItems = [];
            clipResults.currentIndex = -1;
            clipLister.running = true;
        } else if (target === "ssh") {
            sshResults.currentIndex = -1;
            sshHostLister.running = true;
        } else if (target === "nsearch") {
            nixItems = [];
            nixSearching = false;
            nixResults.currentIndex = -1;
        }
    }

    function exitToApps() {
        mode = "apps";
        search.text = "";
        previewSource = "";
        results.currentIndex = -1;
    }

    // Re-copy a history entry. cliphist decode resolves the raw payload for the
    // numeric id (text or image); wl-copy makes it the current paste target.
    function copyClip(item) {
        if (!item)
            return;
        close();
        clipCopy.command = ["sh", "-c", "cliphist decode " + item.id + " | wl-copy"];
        clipCopy.startDetached();
    }

    function sshConnect(host) {
        const target = (host && host.length) ? host : root.query;
        if (!target.length)
            return;
        close();
        sshLauncher.command = ["kitty", "ssh", target];
        sshLauncher.startDetached();
    }

    // Attribute paths are safe (alnum . _ -), so a plain wl-copy is enough.
    function copyPackage(item) {
        if (!item)
            return;
        close();
        clipCopy.command = ["sh", "-c", "printf %s 'nixpkgs#" + item.attr + "' | wl-copy"];
        clipCopy.startDetached();
    }

    // Decode the highlighted image entry to a per-id cache file and show it in
    // the quick-look card once written. Non-image or unselected rows clear it,
    // so the preview closes the moment the selection moves.
    function updatePreview() {
        if (!clipMode || clipResults.currentIndex < 0) {
            previewSource = "";
            return;
        }
        const item = filteredClipboard[clipResults.currentIndex];
        if (!isImageClip(item)) {
            previewSource = "";
            return;
        }
        previewSource = "";
        previewDims = clipDims(item);
        const path = Quickshell.env("HOME") + "/.cache/quickshell/clip-preview-" + item.id;
        clipPreview.target = path;
        clipPreview.command = ["sh", "-c",
            "mkdir -p ~/.cache/quickshell && cliphist decode " + item.id + " > '" + path + "'"];
        clipPreview.running = true;
    }

    // Nothing is highlighted until the user navigates: from the unselected
    // state (-1), Down reveals the first item and Up the last, then wraps.
    function activeView() {
        if (mode === "clipboard") return clipResults;
        if (mode === "ssh") return sshResults;
        if (mode === "nsearch") return nixResults;
        return results;
    }
    function moveSelection(delta) {
        const view = activeView();
        const count = view.count;
        if (count === 0)
            return;
        let index = view.currentIndex;
        if (index < 0)
            index = delta > 0 ? 0 : count - 1;
        else
            index = (index + delta + count) % count;
        view.currentIndex = index;
    }
    function indexOrFirst(view) {
        return view.currentIndex >= 0 ? view.currentIndex : 0;
    }

    function submit() {
        if (mode === "clipboard") {
            copyClip(filteredClipboard[indexOrFirst(clipResults)]);
            return;
        }
        if (mode === "ssh") {
            sshConnect(sshResults.currentIndex >= 0 ? filteredSshHosts[sshResults.currentIndex] : "");
            return;
        }
        if (mode === "nsearch") {
            copyPackage(nixItems[indexOrFirst(nixResults)]);
            return;
        }
        const a = appAction;
        if (a.type === "mode") {
            switchMode(a.target);
            return;
        }
        if (a.type === "web") {
            if (a.ready)
                openUrl(a.url);
            return;
        }
        launch(filteredApplications[indexOrFirst(results)]);
    }

    function goBackOrClose() {
        if (mode !== "apps")
            exitToApps();
        else
            close();
    }

    function runNixSearch() {
        const terms = root.query.split(/\s+/).filter(Boolean);
        if (terms.length === 0 || root.query.length < 2) {
            nixItems = [];
            nixSearching = false;
            return;
        }
        nixSearching = true;
        nixSearch.command = ["nix", "search", "nixpkgs"].concat(terms).concat(["--json"]);
        nixSearch.running = false;
        nixSearch.running = true;
    }

    onVisibleChanged: {
        if (visible) {
            mode = "apps";
            search.text = "";
            previewSource = "";
            results.currentIndex = -1;
            Qt.callLater(() => search.forceActiveFocus());
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { ShellState.toggleLauncher(); }
        function open(): void { ShellState.openLauncher(); }
        function close(): void { ShellState.closeLauncher(); }
    }

    // cliphist list emits one "<id>\t<preview>" row per entry, newest first.
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
                clipResults.currentIndex = -1;
            }
        }
    }

    Process {
        id: clipPreview
        property string target: ""
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0 && target.length > 0 && root.clipMode)
                root.previewSource = "file://" + target;
        }
    }

    // Suggest hosts from ~/.ssh/config and known_hosts; drop wildcards and
    // hashed (|...) entries.
    Process {
        id: sshHostLister
        command: ["sh", "-c",
            "{ grep -ihE '^[Hh]ost ' ~/.ssh/config 2>/dev/null | awk '{for(i=2;i<=NF;i++) print $i}';"
            + " cut -d' ' -f1 ~/.ssh/known_hosts 2>/dev/null | tr ',' '\\n' | sed -e 's/\\[//' -e 's/\\]:.*//'; }"
            + " | grep -vE '^\\||[*?]|^#|^$' | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.sshHosts = this.text.split("\n").filter(line => line.length > 0);
                sshResults.currentIndex = -1;
            }
        }
    }

    // `nix search ... --json` prints an object keyed by attribute path.
    Process {
        id: nixSearch
        stdout: StdioCollector {
            onStreamFinished: {
                root.nixSearching = false;
                let obj = {};
                try { obj = JSON.parse(this.text); } catch (e) { obj = {}; }
                const arr = [];
                for (const key in obj) {
                    const attr = key.replace(/^legacyPackages\.[^.]+\./, "");
                    arr.push({
                        attr: attr,
                        pname: obj[key].pname || attr,
                        version: obj[key].version || "",
                        description: obj[key].description || ""
                    });
                }
                arr.sort((a, b) => a.attr.localeCompare(b.attr));
                root.nixItems = arr;
                nixResults.currentIndex = -1;
            }
        }
    }

    Timer {
        id: nixDebounce
        interval: 350
        onTriggered: root.runNixSearch()
    }

    Process { id: clipCopy }
    Process { id: sshLauncher }
    Process { id: webOpen }

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
                        text: root.clipMode ? "\u{1F5B9}"
                            : root.mode === "ssh" ? "»"
                            : root.mode === "nsearch" ? "❄"
                            : "⌕"
                        color: root.mode === "apps" ? Colors.subtext : Colors.accent
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
                                    clipResults.currentIndex = -1;
                                else if (root.mode === "ssh")
                                    sshResults.currentIndex = -1;
                                else if (root.mode === "nsearch") {
                                    nixResults.currentIndex = -1;
                                    nixDebounce.restart();
                                } else
                                    results.currentIndex = -1;
                            }
                        }

                        Text {
                            anchors.fill: parent
                            visible: search.text.length === 0
                            text: root.clipMode ? "Search clipboard history"
                                : root.mode === "ssh" ? "Type a host to SSH into"
                                : root.mode === "nsearch" ? "Search Nix packages"
                                : "Type to search applications"
                            color: Colors.subtext
                            font.pixelSize: 14
                        }
                    }

                    Text {
                        text: root.clipMode ? root.filteredClipboard.length + " items"
                            : root.mode === "ssh" ? root.filteredSshHosts.length + " hosts"
                            : root.mode === "nsearch" ? (root.nixSearching ? "Searching…" : root.nixItems.length + " packages")
                            : root.actionActive ? "" : root.filteredApplications.length + " apps"
                        color: Colors.subtext
                        font.pixelSize: 12
                    }
                }
            }

            // Command action card (yt / ggl / mode triggers in app mode).
            Rectangle {
                visible: root.actionActive
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 16
                color: "transparent"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.appAction.type === "web" ? "\u{1F310}" : "→"
                        color: Colors.accent
                        font.pixelSize: 40
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.appAction.label || ""
                        color: Colors.text
                        font.pixelSize: 18
                        font.bold: true
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: root.appAction.type !== "web" || root.appAction.ready
                        text: "Press Enter"
                        color: Colors.subtext
                        font.pixelSize: 13
                    }
                }
            }

            // Application results.
            ListView {
                id: results
                visible: root.mode === "apps" && !root.actionActive
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: root.filteredApplications
                currentIndex: -1
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
                    border.width: ListView.isCurrentItem ? 2 : 0
                    border.color: Colors.accent

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
                currentIndex: -1
                keyNavigationWraps: true
                onCurrentIndexChanged: root.updatePreview()

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
                    border.width: ListView.isCurrentItem ? 2 : 0
                    border.color: Colors.accent

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        Text {
                            text: root.isImageClip(clipRow.modelData) ? "\u{1F5BC}" : "\u{1F5B9}"
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

            // SSH host results.
            ListView {
                id: sshResults
                visible: root.mode === "ssh"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: root.filteredSshHosts
                currentIndex: -1
                keyNavigationWraps: true

                delegate: Rectangle {
                    id: sshRow
                    required property var modelData
                    required property int index

                    width: ListView.view ? ListView.view.width : 0
                    height: 48
                    radius: 14
                    color: (ListView.isCurrentItem || sshHover.hovered)
                        ? Colors.glass(0.9)
                        : "transparent"
                    border.width: ListView.isCurrentItem ? 2 : 0
                    border.color: Colors.accent

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        Text {
                            text: "»"
                            color: Colors.subtext
                            font.pixelSize: 16
                        }

                        Text {
                            Layout.fillWidth: true
                            text: sshRow.modelData
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
                        id: sshHover
                        onHoveredChanged: if (hovered) sshResults.currentIndex = sshRow.index
                    }
                    TapHandler { onTapped: root.sshConnect(sshRow.modelData) }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.filteredSshHosts.length === 0
                    text: root.query.length > 0
                        ? "Press Enter to SSH into “" + root.query + "”"
                        : "No known hosts - type one and press Enter"
                    color: Colors.subtext
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    width: parent.width - 40
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // Nix package results.
            ListView {
                id: nixResults
                visible: root.mode === "nsearch"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: root.nixItems
                currentIndex: -1
                keyNavigationWraps: true

                delegate: Rectangle {
                    id: nixRow
                    required property var modelData
                    required property int index

                    width: ListView.view ? ListView.view.width : 0
                    height: 60
                    radius: 14
                    color: (ListView.isCurrentItem || nixHover.hovered)
                        ? Colors.glass(0.9)
                        : "transparent"
                    border.width: ListView.isCurrentItem ? 2 : 0
                    border.color: Colors.accent

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        Text {
                            text: "❄"
                            color: Colors.subtext
                            font.pixelSize: 16
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: nixRow.modelData.attr
                                    color: Colors.text
                                    font.pixelSize: 15
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 360
                                }
                                Text {
                                    visible: text.length > 0
                                    text: nixRow.modelData.version
                                    color: Colors.subtext
                                    font.pixelSize: 12
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: nixRow.modelData.description
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
                        id: nixHover
                        onHoveredChanged: if (hovered) nixResults.currentIndex = nixRow.index
                    }
                    TapHandler { onTapped: root.copyPackage(nixRow.modelData) }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.nixItems.length === 0
                    text: root.nixSearching ? "Searching nixpkgs…"
                        : root.query.length < 2 ? "Type at least two characters"
                        : "No matching packages"
                    color: Colors.subtext
                    font.pixelSize: 14
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: root.clipMode ? "↑↓ Navigate   Enter Copy   Esc Back"
                        : root.mode === "ssh" ? "↑↓ Navigate   Enter Connect   Esc Back"
                        : root.mode === "nsearch" ? "↑↓ Navigate   Enter Copy attribute   Esc Back"
                        : root.actionActive ? "↵ " + root.appAction.label
                        : "↑↓ Navigate   Enter Launch   Esc Close"
                    color: root.actionActive ? Colors.accent : Colors.subtext
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: root.clipMode ? "Clipboard"
                        : root.mode === "ssh" ? "SSH"
                        : root.mode === "nsearch" ? "Nix"
                        : "Quickshell"
                    color: Colors.accent
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }
    }

    // Image quick-look: floats to the right of the panel while an image entry
    // is highlighted in clipboard mode, and disappears when the selection
    // leaves it.
    Rectangle {
        id: previewCard
        visible: root.clipMode && root.previewSource.length > 0
        anchors.left: panel.right
        anchors.leftMargin: 16
        anchors.verticalCenter: panel.verticalCenter
        width: 360
        height: 360
        radius: 20
        color: Colors.glass(0.72)
        border.width: 1
        border.color: Colors.glass(0.95)

        Image {
            anchors.fill: parent
            anchors.margins: 14
            anchors.bottomMargin: 34
            source: root.previewSource
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            text: root.previewDims
            color: Colors.subtext
            font.pixelSize: 12
        }
    }
}
