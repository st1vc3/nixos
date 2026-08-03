// One notification, rendered as a frosted-glass card. Shared by the toast
// popups and the notification centre history; `showActions` lets the centre
// hide action buttons if desired.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card

    required property var notif
    property bool showActions: true
    property int toastKey: -1

    function openLink(link) {
        // Notification bodies are untrusted application input. Restrict link
        // activation to web URLs instead of forwarding file:// or custom
        // schemes to arbitrary desktop handlers.
        const normalized = String(link).trim().toLowerCase();
        if (normalized.startsWith("https://") || normalized.startsWith("http://"))
            Qt.openUrlExternally(link);
    }

    radius: 16
    color: Colors.glass(0.55)
    border.width: 1
    border.color: Colors.glass(0.85)
    implicitHeight: row.implicitHeight + 24

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Image {
            visible: !!card.notif && !!card.notif.image && card.notif.image.length > 0
            source: visible ? card.notif.image : ""
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            Layout.alignment: Qt.AlignTop
            sourceSize.width: 44
            sourceSize.height: 44
            fillMode: Image.PreserveAspectCrop
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: card.notif ? card.notif.appName : ""
                    color: Colors.subtext
                    font.pixelSize: 14
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideNone
                    wrapMode: Text.Wrap
                }

                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    width: 18
                    height: 18
                    radius: 9
                    color: closeHover.hovered ? Colors.glass(0.95) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: Colors.subtext
                        font.pixelSize: 12
                    }
                    HoverHandler { id: closeHover }
                    TapHandler { onTapped: Notifications.dismiss(card.notif, card.toastKey) }
                }
            }

            Text {
                visible: text.length > 0
                text: card.notif ? card.notif.summary : ""
                color: Colors.text
                font.pixelSize: 16
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideNone
                wrapMode: Text.Wrap
            }

            Text {
                visible: text.length > 0
                text: card.notif ? card.notif.body : ""
                color: Colors.subtext
                font.pixelSize: 14
                Layout.fillWidth: true
                elide: Text.ElideNone
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                onLinkActivated: link => card.openLink(link)
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 6
                visible: card.showActions && card.notif && card.notif.actions.length > 0

                Repeater {
                    model: card.showActions && card.notif ? card.notif.actions : []

                    delegate: Rectangle {
                        id: actBtn
                        required property var modelData
                        radius: 8
                        color: actHover.hovered ? Colors.accent : Colors.glass(0.95)
                        implicitWidth: actLabel.implicitWidth + 20
                        implicitHeight: 26

                        Text {
                            id: actLabel
                            anchors.centerIn: parent
                            text: actBtn.modelData.text
                            color: actHover.hovered ? Colors.accentText : Colors.text
                            font.pixelSize: 14
                        }
                        HoverHandler { id: actHover }
                        TapHandler {
                            onTapped: {
                                actBtn.modelData.invoke();
                                Notifications.dismiss(card.notif, card.toastKey);
                            }
                        }
                    }
                }
            }
        }
    }
}
