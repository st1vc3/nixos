pragma Singleton

// Shared geometry for the top-bar surfaces (workspaces on the left, the status
// island on the right) and the panels that hang off them. Both pills sit on the
// same line as the notch, so they have to agree on height, corner radius, edge
// inset and the gap between items - keeping those numbers here stops the two
// sides drifting apart whenever one of them is tweaked.

import QtQuick
import Quickshell

Singleton {
    // The one gutter the whole desktop is spaced by. It mirrors Hyprland's
    // `gaps_out` (see config/hypr/hyprland.lua), so the ring of empty space
    // around a pill matches the ring around a tiled window: change one and the
    // other has to follow, or the bar stops lining up with the windows.
    readonly property real outerGap: 10

    // The pills on either side of the notch, as a fully rounded bubble. They
    // are the notch's height so the three shapes read as one row rather than
    // as a tall notch flanked by two small lozenges.
    readonly property real pillHeight: 36
    readonly property real pillRadius: pillHeight / 2

    // Height of the band the bar occupies along the top edge: a pill floating
    // in its own gutter. The notch fills the whole band because a notch has to
    // touch the screen edge, but its lower edge still lands on the pills', and
    // Hyprland adds another gaps_out below - so the pill has the same ring of
    // space around it as a tiled window does.
    readonly property real stripHeight: outerGap + pillHeight

    // Space between a pill's edge and its content, and between neighbouring
    // items (icons inside the status pill, workspace pills next to each other).
    readonly property real pillPaddingH: 12
    readonly property real pillGap: 12

    // Distance from the screen's left/right edge to the nearest pill.
    readonly property real edgeMargin: outerGap

    // Panels that drop out of the bar animate their height with a plain
    // decelerating ease (Easing.OutQuint), never Easing.OutBack: a back-ease
    // overshoots by a *fraction of the distance travelled*, so a panel that
    // grows the height of the screen swings ~90px past its resting size and
    // springs back. The notch keeps its back-ease - it moves a short enough
    // distance that the overshoot reads as the intended dynamic-island spring.

    // Type sizes inside a pill. The nerd-font glyphs are set larger than the
    // workspace digits on purpose: an icon's ink is thin outline, a bold digit
    // is solid, so equal pixelSize makes the icons read noticeably smaller.
    readonly property int labelSize: 13
    readonly property int iconSize: 16
}
