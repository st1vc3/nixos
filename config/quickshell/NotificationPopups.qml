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

    implicitWidth: 380
    implicitHeight: Math.max(1, column.implicitHeight + 24)

    // Only the toast stack captures input; the rest of the corner is pass-through.
    mask: Region { item: column }

    ColumnLayout {
        id: column
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 44
        anchors.rightMargin: 12
        width: 356
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
