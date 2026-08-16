// Centered application launcher backed by Quickshell's native desktop-entry
// model. Opened through IPC by Hyprland's Super+Space binding.
//
// Beyond launching apps the search box doubles as a command bar. The commands
// are listed among the app results as soon as anything is typed, so they can
// be found by browsing; typing a keyword and pressing Enter switches into the
// matching focused mode, where the search box belongs to that mode until Esc
// goes back:
//   cli      clipboard manager (cliphist history, text + image quick-look)
//   ssh      SSH connector (known hosts, opens a terminal session)
//   nsearch  Nix package search (queries nixpkgs, copies the attribute)
//   yt       YouTube search (opens results in the default browser)
//   ggl      Google search (opens results in the default browser)
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

    // "apps" | "clipboard" | "ssh" | "nsearch" | "youtube" | "google".
    property string mode: "apps"
    readonly property bool clipMode: mode === "clipboard"

    readonly property string query: search.text.trim()

    // --- Web search modes ---------------------------------------------------
    // Engines, command list and icons all live in the LauncherCommands
    // singleton so the cheat sheet renders exactly what the launcher offers.
    readonly property var webEngines: LauncherCommands.engines
    readonly property var webEngine: webEngines[mode] || null
    readonly property bool webMode: webEngine !== null
    readonly property string iconFont: LauncherCommands.iconFont

    function modeIcon(target) { return LauncherCommands.icon(target); }
    function modeName(target) { return LauncherCommands.label(target); }
    function plural(n, word) {
        return n + " " + word + (n === 1 ? "" : "s");
    }

    // --- Applications -------------------------------------------------------
    readonly property var applications: DesktopEntries.applications.values
        .filter(entry => !entry.noDisplay)
        .sort((a, b) => b.name.localeCompare(a.name))
    readonly property var filteredApplications: {
        const terms = search.text.toLowerCase().trim().split(/\s+/).filter(Boolean);
        if (terms.length === 0)
            return applications;
        // Name only: matching the description too made "p" pull in Discord for
        // "Platform", which buries what was actually being looked for.
        return applications.filter(entry => {
            const name = (entry.name || "").toLowerCase();
            return terms.every(term => name.includes(term));
        });
    }

    // --- Commands -----------------------------------------------------------
    // The modes double as search results: they are listed alongside apps so
    // the keywords are discoverable without having to know them already.
    readonly property var commands: LauncherCommands.list

    // Only once something is typed: an empty box stays a plain app list, so
    // Enter on it still launches the first app rather than a command.
    readonly property var filteredCommands: {
        const terms = search.text.toLowerCase().trim().split(/\s+/).filter(Boolean);
        if (terms.length === 0)
            return [];
        const q = search.text.toLowerCase().trim();
        return commands
            .filter(cmd => {
                const haystack = (cmd.keyword + " " + cmd.label).toLowerCase();
                return terms.every(term => haystack.includes(term));
            })
            // An exactly typed keyword outranks a merely prefixed one, so
            // "ssh" puts SSH on top even though "nsearch" also contains it.
            // Ties fall back to declaration order: sort() is not required to
            // be stable here, and without it equal ranks shuffle per keystroke.
            .sort((a, b) => {
                const rank = cmd => cmd.keyword === q ? 0 : (cmd.keyword.startsWith(q) ? 1 : 2);
                return rank(a) - rank(b) || a.order - b.order;
            });
    }

    // Commands rank above apps: they are few, exactly matched, and the app
    // list is long enough to bury them otherwise.
    readonly property var appRows: filteredCommands.concat(filteredApplications)

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
    // Id of the image the preview belongs to, so a late decode can't attach to
    // the wrong (or no) selection.
    property string previewId: ""

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

    // App-mode rows are either a command (switch mode) or a desktop entry.
    function activateRow(item) {
        if (!item)
            return;
        if (item.isCommand)
            switchMode(item.target);
        else
            launch(item);
    }

    // Run the current query through the active engine. Empty queries are a
    // no-op so Enter cannot open a bare results page.
    function webSearch() {
        if (!webEngine || root.query.length === 0)
            return;
        close();
        webOpen.command = ["xdg-open", webEngine.base + encodeURIComponent(root.query)];
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
        // Web modes need no loader: the query is typed after the switch.
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
        previewSource = "";
        previewId = "";
        if (!clipMode || clipResults.currentIndex < 0)
            return;
        const item = filteredClipboard[clipResults.currentIndex];
        if (!isImageClip(item))
            return;
        previewId = item.id;
        previewDims = clipDims(item);
        const path = Quickshell.env("HOME") + "/.cache/quickshell/clip-preview-" + item.id;
        clipPreview.targetId = item.id;
        clipPreview.target = path;
        clipPreview.command = ["sh", "-c",
            "mkdir -p ~/.cache/quickshell && cliphist decode " + item.id + " > '" + path + "'"];
        clipPreview.running = true;
    }

    // Nothing is highlighted until the user navigates: from the unselected
    // state (-1), Down reveals the first item and Up the last, then wraps.
    // Web modes have no list, so there is nothing to move through.
    function activeView() {
        if (mode === "clipboard") return clipResults;
        if (mode === "ssh") return sshResults;
        if (mode === "nsearch") return nixResults;
        if (webMode) return null;
        return results;
    }
    function moveSelection(delta) {
        const view = activeView();
        if (!view)
            return;
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
    // Replacing a view's model makes it adopt a current item again, so the
    // "nothing preselected" reset has to run once the model binding has
    // settled rather than alongside it.
    function clearSelection() {
        const view = activeView();
        if (view)
            view.currentIndex = -1;
    }

    function submit() {
        if (webMode) {
            webSearch();
            return;
        }
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
        activateRow(appRows[indexOrFirst(results)]);
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
        property string targetId: ""
        onExited: function(exitCode, exitStatus) {
            // Only attach the result if the highlighted image is still the one
            // we decoded - guards against a stale/transient decode reviving the
            // card after the selection moved or cleared.
            if (exitCode === 0 && target.length > 0 && root.clipMode
                    && clipResults.currentIndex >= 0 && root.previewId === targetId)
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

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    // Every cell fills the bar height and centres its own text:
                    // sizing cells to their font metrics instead would give the
                    // icon, the query and the counter three different baselines.
                    Text {
                        Layout.fillHeight: true
                        text: root.modeIcon(root.mode)
                        color: root.mode === "apps" ? Colors.subtext : Colors.accent
                        font.family: root.iconFont
                        font.pixelSize: 18
                        verticalAlignment: Text.AlignVCenter
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        TextInput {
                            id: search
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
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
                                if (root.webMode)
                                    return;
                                if (root.clipMode)
                                    clipResults.currentIndex = -1;
                                else if (root.mode === "ssh")
                                    sshResults.currentIndex = -1;
                                else if (root.mode === "nsearch") {
                                    nixResults.currentIndex = -1;
                                    nixDebounce.restart();
                                } else
                                    results.currentIndex = -1;
                                Qt.callLater(root.clearSelection);
                            }
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: search.text.length === 0
                            text: root.clipMode ? "Search clipboard history"
                                : root.mode === "ssh" ? "Type a host to SSH into"
                                : root.mode === "nsearch" ? "Search Nix packages"
                                : root.webMode ? "Search " + root.webEngine.name
                                : "Type to search applications"
                            color: Colors.subtext
                            font.pixelSize: 14
                        }
                    }

                    Text {
                        Layout.fillHeight: true
                        verticalAlignment: Text.AlignVCenter
                        text: root.clipMode ? root.plural(root.filteredClipboard.length, "item")
                            : root.mode === "ssh" ? root.plural(root.filteredSshHosts.length, "host")
                            : root.mode === "nsearch" ? (root.nixSearching ? "Searching…" : root.plural(root.nixItems.length, "package"))
                            : root.webMode ? root.webEngine.name
                            : root.filteredCommands.length > 0 ? root.plural(root.appRows.length, "result")
                            : root.plural(root.filteredApplications.length, "app")
                        color: Colors.subtext
                        font.pixelSize: 12
                    }
                }
            }

            // Web search mode: no list to navigate, the typed query is the
            // action, so the panel just previews what Enter will open.
            Rectangle {
                visible: root.webMode
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 16
                color: "transparent"

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    spacing: 10

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.webEngine ? root.webEngine.icon : ""
                        color: Colors.accent
                        font.family: root.iconFont
                        font.pixelSize: 40
                    }
                    Text {
                        Layout.fillWidth: true
                        text: !root.webEngine ? ""
                            : root.query.length > 0
                                ? "Search " + root.webEngine.name + " for “" + root.query + "”"
                                : "Type a " + root.webEngine.name + " query"
                        color: Colors.text
                        font.pixelSize: 18
                        font.bold: true
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: root.query.length > 0
                        text: "Press Enter"
                        color: Colors.subtext
                        font.pixelSize: 13
                    }
                }
            }

            // Command and application results, in one list so the arrow keys
            // run through both.
            ListView {
                id: results
                visible: root.mode === "apps"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: root.appRows
                currentIndex: -1
                keyNavigationWraps: true

                delegate: Rectangle {
                    id: appRow
                    required property var modelData
                    required property int index
                    readonly property bool isCommand: modelData.isCommand === true

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

                        // Commands carry a glyph where apps carry their icon;
                        // one of the two fills the same 38px slot.
                        Item {
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 38

                            Image {
                                anchors.fill: parent
                                visible: !appRow.isCommand
                                source: appRow.isCommand
                                    ? ""
                                    : Quickshell.iconPath(appRow.modelData.icon, "application-x-executable")
                                sourceSize.width: 38
                                sourceSize.height: 38
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                anchors.fill: parent
                                visible: appRow.isCommand
                                text: appRow.isCommand ? appRow.modelData.glyph : ""
                                color: Colors.accent
                                font.family: root.iconFont
                                font.pixelSize: 20
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: appRow.isCommand
                                    ? appRow.modelData.label
                                    : appRow.modelData.name
                                color: Colors.text
                                font.pixelSize: 16
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: appRow.isCommand
                                    ? appRow.modelData.hint
                                    : (appRow.modelData.genericName || appRow.modelData.comment || "")
                                color: Colors.subtext
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                        }

                        // Keyword chip: teaches the shortcut that reaches this
                        // command directly next time.
                        Rectangle {
                            visible: appRow.isCommand
                            implicitWidth: keyword.implicitWidth + 16
                            implicitHeight: 22
                            radius: 11
                            color: Colors.glass(0.95)

                            Text {
                                id: keyword
                                anchors.centerIn: parent
                                text: appRow.isCommand ? appRow.modelData.keyword : ""
                                color: Colors.subtext
                                font.pixelSize: 12
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
                    TapHandler { onTapped: root.activateRow(appRow.modelData) }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.appRows.length === 0
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
                            text: root.isImageClip(clipRow.modelData) ? "\uF03E" : "\uF0F6"
                            color: Colors.subtext
                            font.family: root.iconFont
                            font.pixelSize: 14
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
                            text: "\uF233"
                            color: Colors.subtext
                            font.family: root.iconFont
                            font.pixelSize: 14
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
                            text: "\uF313"
                            color: Colors.subtext
                            font.family: root.iconFont
                            font.pixelSize: 14
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
                        : root.webMode ? "Enter Search   Esc Back"
                        : "↑↓ Navigate   Enter Launch   Esc Close"
                    color: Colors.subtext
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: root.modeName(root.mode)
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
        visible: root.clipMode && clipResults.currentIndex >= 0 && root.previewSource.length > 0
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
