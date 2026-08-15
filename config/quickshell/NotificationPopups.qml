// Transient toast popups, stacked top-right below the notch/bar strip. Shows
// Notifications.activeToasts; each toast auto-expires on its own timer but
// stays in the centre history.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    anchors.top: true
    anchors.right: true
    exclusiveZone: 0
    color: "transparent"

    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // The stack sits below the notch/bar strip, so the surface has to cover
    // that offset as well as the cards themselves - sizing it to the column
    // alone clips the last card against the bottom window edge.
    // Toasts line up with the top edge of a tiled window: below the bar strip
    // by the same gutter Hyprland leaves around windows.
    readonly property int stackTop: BarMetrics.stripHeight + BarMetrics.outerGap
    readonly property int stackMargin: BarMetrics.edgeMargin

    implicitWidth: 380
    implicitHeight: column.implicitHeight > 0
        ? root.stackTop + column.implicitHeight + root.stackMargin
        : 1

    // Only the toast stack captures input; the rest of the corner is pass-through.
    mask: Region { item: column }

    ColumnLayout {
        id: column
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: root.stackTop
        anchors.rightMargin: root.stackMargin
        width: root.implicitWidth - 2 * root.stackMargin
        spacing: 8

        Repeater {
            model: Notifications.activeToasts

            delegate: Item {
                id: toast
                required property int toastKey
                required property var notification
                Layout.fillWidth: true
                implicitHeight: cardItem.implicitHeight

                NotificationCard {
                    id: cardItem
                    anchors.left: parent.left
                    anchors.right: parent.right
                    notif: toast.notification
                    toastKey: toast.toastKey
                }

                Timer {
                    interval: Notifications.toastTimeout(toast.notification)
                    // Per the freedesktop notification specification, zero
                    // means the notification must not expire automatically.
                    running: interval > 0
                    onTriggered: Notifications.removeToastByKey(toast.toastKey)
                }
            }
        }
    }
}
