// Month calendar shown inside the expanded notch. Hand-rolled from a Grid +
// Repeater (rather than QtQuick.Controls MonthGrid) so it has no dependency
// beyond stock QtQuick and stays trivially themeable from Colors.
//
// Monday-first week. Today is highlighted with an accent pill.

pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: cal

    signal activated

    // The day the calendar is drawn around; the notch feeds it the live clock
    // date so the highlight follows midnight rollovers.
    property date today: new Date()

    readonly property int cellW: 38
    readonly property int cellH: 34

    readonly property int year: today.getFullYear()
    readonly property int month: today.getMonth() // 0-based
    readonly property int todayDate: today.getDate()

    readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()
    // JS getDay(): 0=Sun..6=Sat. Shift so Monday is column 0.
    readonly property int leading: (new Date(year, month, 1).getDay() + 6) % 7

    implicitWidth: cellW * 7
    implicitHeight: header.height + column.spacing + column.implicitHeight

    TapHandler { onTapped: cal.activated() }

    Column {
        id: column
        anchors.fill: parent
        spacing: 4

        Row {
            id: header
            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                delegate: Text {
                    required property string modelData
                    width: cal.cellW
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Colors.subtext
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }

        Grid {
            columns: 7

            Repeater {
                model: cal.leading + cal.daysInMonth

                delegate: Item {
                    required property int index
                    readonly property bool isDay: index >= cal.leading
                    readonly property int dayNum: index - cal.leading + 1
                    readonly property bool isToday: isDay && dayNum === cal.todayDate

                    width: cal.cellW
                    height: cal.cellH

                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        visible: parent.isToday
                        color: Colors.accent
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: parent.isDay
                        text: parent.dayNum
                        color: parent.isToday ? Colors.accentText : Colors.text
                        font.pixelSize: 13
                        font.bold: parent.isToday
                    }
                }
            }
        }
    }
}
