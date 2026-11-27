/*
    SPDX-FileCopyrightText: 2026 Jeysef

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.workspace.calendar as PlasmaCalendar
import org.kde.kirigami as Kirigami

import "Calendar.js" as Calendar
import "code/dateformat.js" as DateFormat

ColumnLayout {
    id: calendarView

    Win11Palette { id: palette }
    readonly property alias calendarPalette: palette

    // Zoom levels: clicking the header zooms out, picking a tile zooms in.
    enum Zoom { Month, Year, Decade }

    // The applet root (main.qml): the clock and the popup's expanded state.
    required property var applet
    property var calendarLocale: Qt.locale()
    // The applet updates every second while open. The month model needs
    // only the day; a clock tick must not recreate its 42 delegates.
    readonly property int todayKey: applet.currentTime.getFullYear() * 10000
        + (applet.currentTime.getMonth() + 1) * 100 + applet.currentTime.getDate()
    readonly property date today: new Date(Math.floor(todayKey / 10000),
        Math.floor(todayKey / 100) % 100 - 1, todayKey % 100)
    // Use the same row pitch in the month and zoomed-out views.
    property real dayHeightLimit: 36
    readonly property real chromeHeight: Math.ceil(Math.max(28, monthNavigation.implicitHeight)
        + weekdayMetrics.height + 2 * spacing + 5 * calendarGrid.spacing)
    readonly property int naturalHeight: Math.ceil(chromeHeight + 6 * zoomHost.dayCellHeight)

    // Year/month currently displayed by the calendar (0-based month).
    property int displayedYear: today.getFullYear()
    property int displayedMonth: today.getMonth()
    property date selectedDate: today
    property int zoom: CalendarView.Zoom.Month

    // A wheel event is not necessarily a physical detent. Wayland can
    // deliver many fractional angle events or pixel events for one gesture.
    property real wheelAngleRemainder: 0
    property real wheelPixelRemainder: 0
    property bool wheelPixelGesture: false
    property bool wheelPixelPaged: false
    readonly property int wheelPixelThreshold: 64

    Timer {
        id: wheelIdle
        interval: 300
        repeat: false
        onTriggered: calendarView.resetWheelInput()
    }

    function resetWheelInput() {
        wheelAngleRemainder = 0;
        wheelPixelRemainder = 0;
        wheelPixelGesture = false;
        wheelPixelPaged = false;
    }

    function handleWheel(angleX, angleY, pixelX, pixelY) {
        // Use pixels when present; never count both representations.
        const hasPixels = pixelX !== 0 || pixelY !== 0;
        const dx = hasPixels ? pixelX : angleX;
        const dy = hasPixels ? pixelY : angleY;
        if (dy === 0 || Math.abs(dx) > Math.abs(dy))
            return;

        if (hasPixels) {
            if (!wheelPixelGesture) {
                resetWheelInput();
                wheelPixelGesture = true;
            }
            // Only one page per continuous swipe, including its inertia.
            wheelIdle.restart();
            if (wheelPixelPaged)
                return;
            if (wheelPixelRemainder * dy < 0)
                wheelPixelRemainder = 0;
            wheelPixelRemainder += dy;
            if (Math.abs(wheelPixelRemainder) >= wheelPixelThreshold) {
                wheelPixelPaged = true;
                page(wheelPixelRemainder > 0 ? -1 : 1);
            }
            return;
        }

        // Some touchpads send angle-only events at the end of a pixel swipe.
        if (wheelPixelGesture) {
            wheelIdle.restart();
            return;
        }
        wheelIdle.restart();
        if (wheelAngleRemainder * dy < 0)
            wheelAngleRemainder = 0;
        wheelAngleRemainder += dy;
        if (Math.abs(wheelAngleRemainder) >= 120) {
            const step = wheelAngleRemainder > 0 ? -1 : 1;
            // Do not queue extra pages from a coalesced event. Retain only
            // the fractional part, not skipped whole detents.
            wheelAngleRemainder %= 120;
            page(step);
        }
    }

    onZoomChanged: resetWheelInput()

    readonly property int decadeStart: Math.floor(displayedYear / 10) * 10

    readonly property int firstDayOfWeek: Plasmoid.configuration.firstDayOfWeek > -1
        ? Plasmoid.configuration.firstDayOfWeek
        : Qt.locale().firstDayOfWeek

    readonly property bool showWeekNumbers: Plasmoid.configuration.showWeekNumbers

    readonly property PlasmaCalendar.EventPluginsManager eventPluginsManager: PlasmaCalendar.EventPluginsManager {
        enabledPlugins: Plasmoid.configuration.enabledCalendarPlugins
    }

    readonly property PlasmaCalendar.Calendar calendarBackend: PlasmaCalendar.Calendar {
        days: 7
        weeks: 6
        firstDayOfWeek: calendarView.firstDayOfWeek
        today: calendarView.today
        displayedDate: new Date(calendarView.displayedYear, calendarView.displayedMonth, 1)

        Component.onCompleted: {
            calendarBackend.daysModel.setPluginsManager(calendarView.eventPluginsManager);
        }
    }

    // Plugins (holidays, your calendars) deliver events asynchronously; the
    // day model announces each batch. Bindings that read events depend on
    // this counter so they refresh when events arrive.
    property int eventsRevision: 0
    Connections {
        target: calendarView.calendarBackend.daysModel
        function onAgendaUpdated(updatedDate) {
            // Only the selected day needs to refresh its agenda. The day
            // cells also use this revision for event marks, so coalesce
            // bursts of native plugin updates into one refresh per frame.
            agendaRefresh.restart();
        }
    }
    Timer {
        id: agendaRefresh
        interval: 0
        onTriggered: calendarView.eventsRevision++
    }

    // Events of the picked day, for the agenda under the calendar.
    readonly property var selectedDayEvents: {
        calendarView.eventsRevision;
        const model = calendarView.calendarBackend.daysModel;
        return model ? model.eventsForDate(calendarView.selectedDate) : [];
    }

    // First date shown in the 6-week grid.
    readonly property date gridStartDate: Calendar.firstGridDate(displayedYear, displayedMonth, firstDayOfWeek)

    spacing: Kirigami.Units.smallSpacing
    focus: true

    function resetToToday() {
        resetWheelInput();
        selectDate(today);
        zoom = CalendarView.Zoom.Month;
    }

    function selectDate(date) {
        displayedYear = date.getFullYear();
        displayedMonth = date.getMonth();
        selectedDate = date;
    }

    function previousMonth() {
        let newMonth = calendarView.displayedMonth - 1;
        let newYear = calendarView.displayedYear;
        if (newMonth < 0) {
            newMonth = 11;
            newYear--;
        }
        calendarView.displayedMonth = newMonth;
        calendarView.displayedYear = newYear;
    }

    function nextMonth() {
        let newMonth = calendarView.displayedMonth + 1;
        let newYear = calendarView.displayedYear;
        if (newMonth > 11) {
            newMonth = 0;
            newYear++;
        }
        calendarView.displayedMonth = newMonth;
        calendarView.displayedYear = newYear;
    }

    // The chevrons, Page Up/Down and the wheel page by month, year or
    // decade, depending on the zoom level.
    function page(step) {
        switch (zoom) {
        case CalendarView.Zoom.Month:
            if (step < 0) {
                previousMonth();
            } else {
                nextMonth();
            }
            break;
        case CalendarView.Zoom.Year:
            displayedYear += step;
            yearGrid.crossfade();
            break;
        case CalendarView.Zoom.Decade:
            displayedYear += 10 * step;
            decadeGrid.crossfade();
            break;
        }
    }

    function zoomOut() {
        if (zoom < CalendarView.Zoom.Decade) {
            zoom++;
        }
    }

    // Like Windows, the flyout always opens on today's month.
    Connections {
        target: calendarView.applet
        function onFlyoutOpenChanged() {
            if (calendarView.applet.flyoutOpen) {
                calendarView.resetToToday();
            }
        }
    }

    onDisplayedMonthChanged: calendarGrid.crossfade()
    onDisplayedYearChanged: calendarGrid.crossfade()

    Keys.onPressed: event => {
        if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
            calendarView.page(event.key === Qt.Key_PageUp ? -1 : 1);
            event.accepted = true;
            return;
        }
        // The arrow keys move the selected day, so only the month view uses them.
        if (calendarView.zoom !== CalendarView.Zoom.Month && event.key !== Qt.Key_Home) {
            return;
        }
        // Paging intentionally keeps the selected day's agenda until a new
        // day is picked. Arrow navigation must start in the displayed month,
        // rather than jumping back to the old selection's month.
        const selected = calendarView.selectedDate;
        const d = new Date(calendarView.displayedYear, calendarView.displayedMonth,
            Math.min(selected.getDate(), Calendar.daysInMonth(calendarView.displayedYear, calendarView.displayedMonth)));
        switch (event.key) {
        case Qt.Key_Left:
            d.setDate(d.getDate() - 1);
            calendarView.selectDate(d);
            event.accepted = true;
            break;
        case Qt.Key_Right:
            d.setDate(d.getDate() + 1);
            calendarView.selectDate(d);
            event.accepted = true;
            break;
        case Qt.Key_Up:
            d.setDate(d.getDate() - 7);
            calendarView.selectDate(d);
            event.accepted = true;
            break;
        case Qt.Key_Down:
            d.setDate(d.getDate() + 7);
            calendarView.selectDate(d);
            event.accepted = true;
            break;
        case Qt.Key_Home:
            calendarView.resetToToday();
            event.accepted = true;
            break;
        }
    }

    // A zoom level's content: the active level is shown at full size, the
    // others are faded out, smaller (finer levels) or larger (coarser ones).
    component ZoomLevel: Item {
        required property int level
        readonly property bool active: calendarView.zoom === level

        visible: opacity > 0
        enabled: active
        opacity: active ? 1 : 0
        scale: active ? 1 : (calendarView.zoom > level ? 0.9 : 1.1)

        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    // Month/year navigation header. The title zooms out when clicked.
    RowLayout {
        id: monthNavigation
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            id: headerTitle
            objectName: "wmCalendarMonthHeading"
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: {
                switch (calendarView.zoom) {
                case CalendarView.Zoom.Year:
                    return String(calendarView.displayedYear);
                case CalendarView.Zoom.Decade:
                    return calendarView.decadeStart + " – " + (calendarView.decadeStart + 9);
                }
                return DateFormat.calendarMonthTitle(calendarView.calendarLocale,
                    calendarView.displayedYear, calendarView.displayedMonth, Locale.LongFormat);
            }
            // The decade is the last level: greyed like the dimmed years.
            color: headerButton.enabled ? palette.text : palette.textDisabled
            font {
                weight: Font.DemiBold
                pixelSize: 14
            }

            activeFocusOnTab: headerButton.enabled
            Accessible.role: headerButton.enabled ? Accessible.Button : Accessible.StaticText
            Accessible.onPressAction: if (headerButton.enabled) calendarView.zoomOut()
            Keys.onReturnPressed: event => { if (headerButton.enabled && !event.isAutoRepeat) calendarView.zoomOut(); }
            Keys.onEnterPressed: event => { if (headerButton.enabled && !event.isAutoRepeat) calendarView.zoomOut(); }
            Keys.onSpacePressed: event => { if (headerButton.enabled && !event.isAutoRepeat) calendarView.zoomOut(); }

            // Hover/press background around the title text, behind it; the
            // decade level is the last one, so there it is plain text.
            MouseArea {
                id: headerButton
                z: -1
                x: -Kirigami.Units.smallSpacing
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(headerTitle.width, headerTitle.contentWidth) + 2 * Kirigami.Units.smallSpacing
                height: Kirigami.Units.gridUnit * 1.5
                enabled: calendarView.zoom !== CalendarView.Zoom.Decade
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: calendarView.zoomOut()

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: headerButton.containsPress ? palette.pressed
                                                      : (headerButton.containsMouse || headerTitle.activeFocus ? palette.hover : "transparent")

                    Behavior on color {
                        ColorAnimation {
                            duration: Kirigami.Units.shortDuration
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }

        CalendarNavButton {
            up: true
            glyphColor: palette.textSecondary
            hoverColor: palette.hover
            pressedColor: palette.pressed
            onClicked: calendarView.page(-1)
            Accessible.name: i18n("Previous")
        }

        CalendarNavButton {
            up: false
            glyphColor: palette.textSecondary
            hoverColor: palette.hover
            pressedColor: palette.pressed
            onClicked: calendarView.page(1)
            Accessible.name: i18n("Next")
        }
    }

    // The month view, or the year/decade view zoomed out in its place.
    Item {
        id: zoomHost
        Layout.fillWidth: true
        // Do not derive the host height from the hidden Month layout:
        // zooming to Year/Decade or opening a hidden popup can collapse it.
        readonly property real weekColumnWidth: calendarView.showWeekNumbers
            ? Kirigami.Units.gridUnit * 1.5 : 0
        readonly property real dayCellSize: Math.max(1,
            (width - weekColumnWidth - 6 * calendarGrid.spacing) / 7)
        readonly property real dayCellHeight: Math.max(1, Math.min(dayCellSize, calendarView.dayHeightLimit))
        Layout.preferredHeight: Math.ceil(dayCellHeight * 6 + 5 * calendarGrid.spacing
            + weekdayMetrics.height + calendarView.spacing)
        Layout.minimumHeight: Layout.preferredHeight
        clip: true

        FontMetrics {
            id: weekdayMetrics
            font.family: Kirigami.Theme.defaultFont.family
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        ZoomLevel {
            anchors.fill: parent
            level: CalendarView.Zoom.Month

            ColumnLayout {
                id: monthView
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                spacing: calendarView.spacing

                // Day-of-week header: match the seven grid columns.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    PlasmaComponents.Label {
                        visible: calendarView.showWeekNumbers
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        textFormat: Text.PlainText
                        text: i18nc("@label week number column header", "Wk")
                        color: palette.textSecondary
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: calendarGrid.spacing
                        Repeater {
                            model: 7
                            delegate: PlasmaComponents.Label {
                                required property int index
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredWidth: 1
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                text: calendarView.calendarLocale.standaloneDayName((calendarView.firstDayOfWeek + index) % 7, Locale.ShortFormat)
                                color: palette.text
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }

                // Calendar grid with optional week number column.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    ColumnLayout {
                        visible: calendarView.showWeekNumbers
                        spacing: calendarGrid.spacing
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5

                        Repeater {
                            model: 6
                            delegate: PlasmaComponents.Label {
                                required property int index
                                Layout.preferredHeight: calendarGrid.cellHeight
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                textFormat: Text.PlainText
                                text: Calendar.isoWeekNumber(Calendar.dateAfterDays(calendarView.gridStartDate, index * 7))
                                color: palette.textSecondary
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            }
                        }
                    }

                    CalendarGrid {
                        id: calendarGrid
                        calendarController: calendarView
                        rowHeight: zoomHost.dayCellHeight
                        Layout.fillWidth: true
                        Layout.preferredHeight: calendarGrid.cellHeight * 6 + calendarGrid.spacing * 5
                    }
                }
            }
        }

        ZoomLevel {
            anchors.fill: parent
            level: CalendarView.Zoom.Year

            CalendarZoomGrid {
                id: yearGrid
                anchors.fill: parent
                tiles: Calendar.generateYearGrid(calendarView.displayedYear, calendarView.today,
                    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11].map(m => calendarView.calendarLocale.standaloneMonthName(m, Locale.ShortFormat)))
                onPicked: index => {
                    const tile = tiles[index];
                    calendarView.displayedYear = tile.year;
                    calendarView.displayedMonth = tile.month;
                    calendarView.zoom = CalendarView.Zoom.Month;
                }
            }
        }

        ZoomLevel {
            anchors.fill: parent
            level: CalendarView.Zoom.Decade

            CalendarZoomGrid {
                id: decadeGrid
                anchors.fill: parent
                tiles: Calendar.generateDecadeGrid(calendarView.displayedYear, calendarView.today)
                onPicked: index => {
                    calendarView.displayedYear = tiles[index].year;
                    calendarView.zoom = CalendarView.Zoom.Year;
                }
            }
        }

        // Scroll wheel over the grid pages at the current zoom level.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                calendarView.handleWheel(wheel.angleDelta.x, wheel.angleDelta.y,
                                         wheel.pixelDelta.x, wheel.pixelDelta.y);
                // The calendar owns this surface; do not let a parent
                // scroll handler process the same wheel event a second time.
                wheel.accepted = true;
            }
        }
    }
}
