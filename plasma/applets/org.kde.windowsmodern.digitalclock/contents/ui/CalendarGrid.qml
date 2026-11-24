/*
    SPDX-FileCopyrightText: 2026 Jeysef

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import "Calendar.js" as Calendar

Item {
    id: calendarGrid
    objectName: "wmCalendarDayGrid"
    required property var calendarController

    // Keep seven columns and six rows visible even on a shorter screen.
    readonly property real cellWidth: Math.max(1, (width - (columns - 1) * spacing) / columns)
    property real rowHeight: cellWidth
    readonly property real cellHeight: Math.max(1, Math.min(cellWidth, rowHeight))

    readonly property int columns: 7
    readonly property int rows: 6
    property real spacing: 2

    Layout.preferredHeight: cellHeight * rows + spacing * (rows - 1)
    Layout.minimumHeight: Layout.preferredHeight

    function crossfade() {
        grid.opacity = 0;
        fadeIn.restart();
    }

    Grid {
        id: grid
        anchors.fill: parent
        columns: calendarGrid.columns
        rows: calendarGrid.rows
        spacing: calendarGrid.spacing

        Repeater {
            id: gridRepeater

            model: Calendar.generateMonthGrid(
                calendarGrid.calendarController.displayedYear,
                calendarGrid.calendarController.displayedMonth,
                calendarGrid.calendarController.today,
                calendarGrid.calendarController.selectedDate,
                calendarGrid.calendarController.firstDayOfWeek)

            delegate: CalendarDayDelegate {
                required property var modelData

                width: calendarGrid.cellWidth
                height: calendarGrid.cellHeight

                calendarController: calendarGrid.calendarController
                dayData: modelData
                daysModel: calendarGrid.calendarController.calendarBackend.daysModel
                eventsRevision: calendarGrid.calendarController.eventsRevision
            }
        }

    }

    NumberAnimation {
        id: fadeIn
        target: grid
        property: "opacity"
        to: 1
        duration: Kirigami.Units.shortDuration
        easing.type: Easing.InOutQuad
    }
}
