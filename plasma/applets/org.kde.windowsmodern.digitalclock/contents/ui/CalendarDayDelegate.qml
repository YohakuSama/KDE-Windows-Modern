/*
    SPDX-FileCopyrightText: 2026 Jeysef

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.workspace.calendar as PlasmaCalendar
import org.kde.kirigami as Kirigami

MouseArea {
    id: dayDelegate

    required property var calendarController
    required property var dayData
    required property PlasmaCalendar.DaysModel daysModel
    required property int eventsRevision

    required property var colors

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    // Events for this day, queried from the shared DaysModel.
    readonly property var dayEvents: {
        dayDelegate.eventsRevision;                 // refresh when events arrive
        return daysModel ? daysModel.eventsForDate(dayData.date) : [];
    }
    readonly property bool hasEvents: dayEvents && dayEvents.length > 0

    Accessible.role: Accessible.Button
    Accessible.name: dayData.day
        + (dayData.isToday ? i18n(", today") : "")
        + (dayData.isSelected ? i18n(", selected") : "")
    Accessible.onPressAction: dayDelegate.calendarController.selectDate(dayData.date)  // as the month/year tiles

    onClicked: {
        dayDelegate.calendarController.selectDate(dayData.date);
    }

    // One circle in every state (hover, press, picked ring, today), as on
    // Windows 11: the picked day used to turn into a rounded square while
    // hovered, and plain days had a square hover.
    Rectangle {
        id: dayBackground
        anchors.centerIn: parent
        width: Math.max(1, Math.min(parent.width, parent.height) - 2)
        height: width
        radius: width / 2
        color: {
            if (dayData.isToday) {
                return dayDelegate.colors.accent;
            } else if (dayDelegate.containsPress) {
                return dayDelegate.colors.pressed;
            } else if (dayDelegate.containsMouse) {
                return dayDelegate.colors.hover;
            }
            return "transparent";
        }
        // The picked day: an accent ring, as Windows 11 draws it (it was a
        // surface-coloured fill, invisible in dark mode).
        border.color: dayData.isSelected && !dayData.isToday ? dayDelegate.colors.accent : "transparent"
        border.width: 2

        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
                easing.type: Easing.InOutQuad
            }
        }
    }

    scale: dayDelegate.containsPress ? 0.96 : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: Kirigami.Units.shortDuration
            easing.type: Easing.InOutQuad
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 1

        PlasmaComponents.Label {
            id: dayLabel
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
            text: dayData.day
            color: {
                if (dayData.isToday) {
                    return dayDelegate.colors.accentText;
                } else if (dayData.isCurrentMonth) {
                    return dayDelegate.colors.text;
                }
                return dayDelegate.colors.textDisabled;
            }
            font.pixelSize: Math.max(8, Math.min(13, Math.floor(dayDelegate.height * (dayDelegate.hasEvents ? 0.52 : 0.68))))
        }

        // Event dots.
        RowLayout {
            id: eventDotsRow
            Layout.alignment: Qt.AlignHCenter
            visible: dayDelegate.hasEvents && dayDelegate.height >= 22
            spacing: 2

            Repeater {
                model: Math.min(3, dayDelegate.dayEvents.length)
                delegate: Rectangle {
                    required property int index
                    width: 4
                    height: 4
                    radius: 2
                    color: dayDelegate.dayEvents[index].eventColor || dayDelegate.colors.accent
                }
            }
        }
    }

    QQC2.ToolTip {
        visible: dayDelegate.hasEvents && dayDelegate.containsMouse
        text: dayDelegate.dayEvents.map(ev => ev.title || "").join("\n")
        delay: 800
    }
}
