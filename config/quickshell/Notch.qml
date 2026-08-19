// macOS-style dynamic notch: an opaque black pill hanging from the top-centre
// of the screen showing the clock, which springs open on hover to reveal the
// date and a month calendar. Runs as its own layer-shell surface, floating
// over windows without reserving space.

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    // Injected by the Variants delegate in shell.qml (one notch per screen).
    property var modelData
    screen: modelData

    // Anchoring to the top edge only (no left/right) centres the surface
    // horizontally on that edge - exactly where a notch lives.
    anchors.top: true

    // Reserve exactly the collapsed pill height so windows tile *below* the
    // notch and never sit under it - a fixed strip along the top edge, like a
    // minimal bar. It stays pinned to the collapsed height on purpose: the
    // hover expansion grows past it as a transient overlay and must NOT push
    // windows down, so this is bound to collapsedHeight, not the live height.
    exclusiveZone: root.collapsedHeight
    color: "transparent"

    WlrLayershell.namespace: "quickshell-notch"

    // Hyprland draws a fullscreen window above the Top layer, so the notch -
    // clock and all - correctly disappears under a game or a video. Dictation
    // is the one thing that must not: it is push-to-talk feedback, and the
    // moment it is worth showing is the moment there is no other way to tell
    // whether the mic is live. Overlay outranks fullscreen, so the pill is
    // promoted for exactly as long as it has something live to say and drops
    // back to Top the instant it does not.
    WlrLayershell.layer: root.dictating ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // The surface is sized for the largest shape it ever draws, and the black
    // shape animates within it while everything around it stays transparent.
    // The widest state is the dictation error pill, not the calendar: 420 plus
    // a flare on each side is 452.
    implicitWidth: 460
    implicitHeight: 380

    // Restrict input to the visible notch shape, otherwise the large
    // transparent surface would swallow clicks meant for the windows
    // underneath it. Bound to the body rather than the drawn shape so the
    // flared corners, which are mostly wallpaper, stay click-through.
    mask: Region {
        item: body
    }

    property bool expanded: false

    // Voice dictation (F1 / F2) takes over the collapsed pill: it grows a
    // little and shows a waveform, the way the Dynamic Island swaps its
    // contents for whatever is live. Hover still wins, so reaching for the
    // calendar mid-sentence behaves normally.
    readonly property bool dictating: Dictation.busy && !root.expanded

    readonly property real collapsedWidth: 190
    // The notch hangs to the same line the bar pills end on, so its lower edge
    // and theirs form one horizontal line across the top of the screen. Windows
    // then start a gaps_out below that shared line.
    readonly property real collapsedHeight: BarMetrics.stripHeight
    readonly property real expandedWidth: 360

    // Deliberately a small step up from the collapsed pill rather than a jump
    // to the calendar size: the point is to catch the eye at the top of the
    // screen, not to cover what is being dictated into.
    // An error message needs room that "Listening" does not. Note that
    // hyprwhspr-rs overwrites its error status with "inactive" on the next
    // statement, so this is a graceful path rather than something seen in
    // practice - a failed transcription is diagnosed from
    // `journalctl --user -u hyprwhspr-rs`.
    readonly property real dictationWidth: Dictation.failed ? 420 : 264
    readonly property real dictationHeight: collapsedHeight + 16
    // Derive the open shape from its contents so six-row months never clip.
    // The 40px addition gives the same 20px padding above and below that the
    // panel already has at its left and right edges.
    readonly property real expandedHeight: content.implicitHeight + 40

    // How far the shape flares sideways as it reaches the screen edge. The
    // silhouette has no corner up there at all: the top edge of the display
    // curves down into the notch's side in one continuous sweep, so nothing
    // meets the edge at a right angle.
    readonly property real flare: 16

    // The live geometry of the notch body, animated rather than switched, so
    // the path below is redrawn every frame of the growth. Bindings on a plain
    // property still trigger the Behaviors when the target state changes.
    property real bodyWidth: root.expanded ? root.expandedWidth : root.dictating ? root.dictationWidth : root.collapsedWidth
    property real bodyHeight: root.expanded ? root.expandedHeight : root.dictating ? root.dictationHeight : root.collapsedHeight
    property real bodyRadius: root.expanded ? 34 : root.dictating ? 30 : 26

    // What the path actually uses. The two bottom arcs have to fit between the
    // flare and the lower edge, and between each other: past that the side
    // walls invert and the silhouette turns inside out. The collapsed pill is
    // the tight one - BarMetrics.stripHeight is 46, so anything over 30 breaks
    // it. Clamping here means the numbers above can be tuned freely, and it
    // holds mid-animation too, while the height is still travelling.
    readonly property real drawRadius: Math.max(0, Math.min(root.bodyRadius, root.bodyHeight - root.flare, root.bodyWidth / 2))

    // Height leads and width follows, so the pill reads as being extruded out
    // of the screen edge and then spreading, rather than scaling as one block.
    // The overshoot is kept mild: this should settle, not bounce.
    Behavior on bodyHeight {
        NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
    }
    Behavior on bodyWidth {
        NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.05 }
    }
    Behavior on bodyRadius {
        NumberAnimation { duration: 380; easing.type: Easing.OutCubic }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Process {
        id: calendarProcess
        // Keep this explicit so the launcher also works immediately after a
        // NixOS switch, before the long-running Wayland session has inherited
        // NixOS's TZDIR environment on its next login.
        command: ["env", "TZDIR=/etc/zoneinfo", "gnome-calendar"]
    }

    function pad(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    // The silhouette, traced anticlockwise from the top-left flare. Two arcs
    // curve *away* from the body where it meets the screen edge (concave), two
    // curve into it at the bottom (convex) - the macOS notch profile. A plain
    // Rectangle cannot express the concave pair at any radius, which is why
    // this is a Shape.
    Shape {
        id: shape
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        width: root.bodyWidth + 2 * root.flare
        height: root.bodyHeight

        // Analytic curve rasteriser: the flares are large, shallow arcs that
        // the legacy triangulating renderer visibly facets.
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "#000000"
            strokeWidth: -1

            // Screen edge, just left of where the notch begins to descend.
            startX: 0
            startY: 0

            // Flare down into the left side. Clockwise where the bottom corners
            // are anticlockwise: that reversal is what makes it concave.
            PathArc {
                x: root.flare; y: root.flare
                radiusX: root.flare; radiusY: root.flare
                direction: PathArc.Clockwise
            }

            PathLine { x: root.flare; y: root.bodyHeight - root.drawRadius }

            PathArc {
                x: root.flare + root.drawRadius; y: root.bodyHeight
                radiusX: root.drawRadius; radiusY: root.drawRadius
                direction: PathArc.Counterclockwise
            }

            PathLine { x: root.flare + root.bodyWidth - root.drawRadius; y: root.bodyHeight }

            PathArc {
                x: root.flare + root.bodyWidth; y: root.bodyHeight - root.drawRadius
                radiusX: root.drawRadius; radiusY: root.drawRadius
                direction: PathArc.Counterclockwise
            }

            PathLine { x: root.flare + root.bodyWidth; y: root.flare }

            // Flare back out to the screen edge on the right.
            PathArc {
                x: root.bodyWidth + 2 * root.flare; y: 0
                radiusX: root.flare; radiusY: root.flare
                direction: PathArc.Clockwise
            }

            PathLine { x: 0; y: 0 }
        }

        // The notch body without its flares: the region that is actually opaque
        // across its full height, and so the region that should take input.
        Item {
            id: body
            x: root.flare
            y: 0
            width: root.bodyWidth
            height: root.bodyHeight

            HoverHandler {
                id: hover
                onHoveredChanged: root.expanded = hovered
            }
        }

        // Collapsed clock: centred in the pill, fades out as it expands and
        // hands the pill over to the dictation waveform while recording.
        Text {
            anchors.centerIn: parent
            text: root.pad(clock.hours) + ":" + root.pad(clock.minutes)
            color: Colors.text
            font.pixelSize: 16
            font.bold: true
            opacity: root.expanded || root.dictating ? 0 : 1

            // Leaving is immediate, returning waits. The clock and the
            // dictation row share the pill's exact centre, so fading them at
            // the same time superimposes "20:56" on "Listening" for a couple of
            // frames. Whichever is arriving holds back until the other has gone.
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: root.expanded || root.dictating ? 0 : 120 }
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
            }

            // Recede slightly on the way out instead of only dimming, so the
            // swap reads as one element making way for another.
            scale: root.expanded || root.dictating ? 0.88 : 1
            Behavior on scale {
                SequentialAnimation {
                    PauseAnimation { duration: root.expanded || root.dictating ? 0 : 120 }
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
            }
        }

        // Dictation takeover. The bars are decorative rather than a meter:
        // Quickshell's PipeWire service exposes volume and mute but no peak
        // level, and opening a second capture stream against the microphone the
        // daemon already holds is not worth a real amplitude reading. Motion
        // here answers "is it listening", which is the whole job.
        RowLayout {
            anchors.centerIn: parent
            spacing: 12

            opacity: root.dictating ? 1 : 0
            visible: opacity > 0

            // Mirror of the clock's hand-off above: wait for it to clear, then
            // grow into place with the pill rather than appearing at full size.
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: root.dictating ? 120 : 0 }
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
            }

            scale: root.dictating ? 1 : 0.88
            Behavior on scale {
                SequentialAnimation {
                    PauseAnimation { duration: root.dictating ? 120 : 0 }
                    NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                }
            }

            Text {
                id: micIcon

                // The daemon publishes its own mic glyph in status.json, so the
                // icon set stays defined in one place.
                text: Dictation.icon
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                color: Dictation.failed ? Colors.alert : Colors.accent

                // A slow breath keeps the pill alive between sentences, when
                // the bars have settled to their resting row. Restoring the
                // opacity by id, not `parent`: an Animation is not an Item and
                // has no parent to resolve, so reaching for one leaves the
                // glyph stuck at whatever point of the breath it stopped on.
                SequentialAnimation on opacity {
                    running: Dictation.recording
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) micIcon.opacity = 1
                    NumberAnimation { to: 0.45; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }

            // Each bar runs its own loop at a slightly different period so the
            // row never falls into a mechanical lockstep.
            RowLayout {
                spacing: 4
                Repeater {
                    model: 5
                    Rectangle {
                        id: bar
                        required property int index

                        readonly property real minHeight: 5
                        readonly property real maxHeight: 12 + (index % 3) * 7
                        property real level: 0

                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 4
                        implicitHeight: minHeight + level * (maxHeight - minHeight)
                        radius: 2
                        color: Dictation.failed ? Colors.alert : Colors.accent

                        SequentialAnimation on level {
                            running: Dictation.recording
                            loops: Animation.Infinite
                            // The animation owns `level` only while running, so
                            // the row can be collapsed back on the way out.
                            onRunningChanged: if (!running) bar.level = 0
                            NumberAnimation { to: 1; duration: 260 + bar.index * 55; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.1; duration: 300 + bar.index * 40; easing.type: Easing.InOutSine }
                        }

                        // While the audio is in flight there is nothing left to
                        // visualise, so the row becomes a travelling pulse:
                        // clearly working, clearly no longer listening.
                        SequentialAnimation on opacity {
                            running: Dictation.processing
                            loops: Animation.Infinite
                            onRunningChanged: if (!running) bar.opacity = 1
                            PauseAnimation { duration: bar.index * 90 }
                            NumberAnimation { to: 0.25; duration: 260 }
                            NumberAnimation { to: 1; duration: 260 }
                            PauseAnimation { duration: (4 - bar.index) * 90 }
                        }
                    }
                }
            }

            Text {
                text: Dictation.recording ? "Listening" : Dictation.processing ? "Transcribing" : Dictation.tooltip
                color: Dictation.failed ? Colors.alert : Colors.subtext
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
                Layout.maximumWidth: Dictation.failed ? 286 : 130
            }
        }

        // Expanded panel: big time + date header and the month calendar.
        // Fades in slightly after the shape has started growing.
        ColumnLayout {
            id: content
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 20
            width: root.expandedWidth - 40
            spacing: 12

            opacity: root.expanded ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.pad(clock.hours) + ":" + root.pad(clock.minutes)
                    color: Colors.text
                    font.pixelSize: 42
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(clock.date, "dddd, d MMMM")
                    color: Colors.subtext
                    font.pixelSize: 14
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Colors.outline
                opacity: 0.4
            }

            Calendar {
                Layout.alignment: Qt.AlignHCenter
                today: clock.date
                onActivated: calendarProcess.startDetached()
            }
        }
    }
}
