/*
    SPDX-FileCopyrightText: 2026 Jeysef

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls as QQC2

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "code/dateformat.js" as DateFormat

FocusScope {
    id: expandedRoot
    required property var clockApplet
    property bool calendarExpanded: true

    // Match the translated UI language without changing LC_TIME.
    readonly property var calendarLocale: Qt.locale(DateFormat.calendarLocaleName(
        i18nc("@info calendar display locale (translate to a Qt locale name)", "system"),
        Qt.locale().name))

    // Preserve the native Plasma full representation. Its default margin
    // is zero on docked panels; change only this applet's popup window.
    readonly property var nativePopup: {
        const win = expandedRoot.Window.window;
        return win && win.objectName === "popupWindow" && "margin" in win
            && "removeBorderStrategy" in win ? win : null;
    }
    Binding {
        target: expandedRoot.nativePopup
        property: "margin"
        value: 8
        when: expandedRoot.nativePopup !== null
    }
    Binding {
        target: expandedRoot.nativePopup
        property: "removeBorderStrategy"
        value: PlasmaCore.AppletPopup.Never
        when: expandedRoot.nativePopup !== null
    }

    Win11Palette { id: palette }

    // Plasma owns the popup window and transfers these layout hints.
    // Derive hints from the panel's screen, not this hidden view's geometry.
    readonly property int margin: 16
    readonly property var panelScreen: clockApplet.popupScreenGeometry
    readonly property real screenWidth: Number(panelScreen?.width || 0)
    readonly property real screenHeight: Number(panelScreen?.height || 0)
    readonly property real panelExtent: Math.min(96, Math.max(0, Number(clockApplet.popupPanelExtent) || 48))
    readonly property int availableScreenHeight: screenHeight >= 100
        ? Math.max(1, Math.floor(screenHeight - panelExtent - 4 * margin)) : 720
    readonly property int configuredWidth: Math.max(240, Number(Plasmoid.configuration.expandedWidth) || 320)
    readonly property int popupWidth: Math.min(configuredWidth, screenWidth >= 100
        ? Math.max(1, Math.floor(screenWidth - 4 * margin)) : configuredWidth)
    readonly property int popupHeight: Math.min(availableScreenHeight,
        calendarExpanded ? Math.max(560, Kirigami.Units.gridUnit * 28)
                         : Math.max(220, Kirigami.Units.gridUnit * 11))

    implicitWidth: popupWidth
    implicitHeight: popupHeight
    Layout.minimumWidth: popupWidth
    Layout.preferredWidth: popupWidth
    Layout.maximumWidth: popupWidth
    Layout.minimumHeight: popupHeight
    Layout.preferredHeight: popupHeight
    Layout.maximumHeight: popupHeight
    clip: true
    focus: true
    Keys.onEscapePressed: event => {
        clockApplet.expanded = false;
        event.accepted = true;
    }

    // The calendar is fixed in the popup, not nested inside an outer
    // scroll view. Only notification cards scroll when they exceed their
    // allocated viewport. The calendar rows adapt to the available height.
    ColumnLayout {
        id: mainColumn
        objectName: "wmClockContent"
        anchors.fill: parent
        anchors.margins: expandedRoot.margin
        spacing: 8

        NotificationHistory {
            id: history
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: minimumSectionHeight
            Layout.preferredHeight: minimumSectionHeight
            currentTime: expandedRoot.clockApplet.currentTime
            notificationsAvailable: expandedRoot.clockApplet.notificationsAvailable
            effectiveDnd: expandedRoot.clockApplet.notificationsInhibited
            notificationModel: expandedRoot.clockApplet.notificationModel
            settings: expandedRoot.clockApplet.notificationSettings
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: palette.surfaceBorder
        }


        // ── Header: large time (with superscript AM/PM) and full date ──
        ColumnLayout {
            id: headerColumn
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: Kirigami.Units.smallSpacing / 2

            RowLayout {
                id: timeRow
                visible: Plasmoid.configuration.showTimeInNotificationCenter
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.smallSpacing / 2

                PlasmaComponents.Label {
                    id: timeHeader
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    textFormat: Text.PlainText
                    text: {
                        const fmt = expandedRoot.clockApplet.timeFormatWithSeconds;
                        // Render the AM/PM suffix separately so it can be smaller.
                        if (fmt.toLowerCase().includes("ap")) {
                            return Qt.locale().toString(expandedRoot.clockApplet.currentTime, fmt.replace(/\s+AP/i, ""));
                        }
                        return Qt.locale().toString(expandedRoot.clockApplet.currentTime, fmt);
                    }
                    color: palette.text
                    font {
                        family: Kirigami.Theme.defaultFont.family
                        weight: Font.DemiBold
                        pixelSize: 40
                        features: { "tnum": 1 }
                    }
                }

                PlasmaComponents.Label {
                    id: amPmLabel
                    visible: expandedRoot.clockApplet.timeFormatWithSeconds.toLowerCase().includes("ap")
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignTop
                    textFormat: Text.PlainText
                    text: Qt.locale().toString(expandedRoot.clockApplet.currentTime, "AP")
                    color: palette.text
                    font {
                        family: Kirigami.Theme.defaultFont.family
                        weight: Font.DemiBold
                        pixelSize: Math.round(timeHeader.font.pixelSize * 0.45)
                    }
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: timeHeader.font.pixelSize * 0.12
                }
            }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    id: dateHeader
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    // Windows 11 shows the locale's long date without the year.
                    objectName: "wmCalendarDateHeading"
                    text: DateFormat.calendarLongDate(expandedRoot.calendarLocale, expandedRoot.clockApplet.currentTime)
                    color: palette.textSecondary
                    font {
                        family: Kirigami.Theme.defaultFont.family
                        pixelSize: 14
                    }
                }

                PlasmaComponents.ToolButton {
                    text: expandedRoot.calendarExpanded ? i18n("Collapse calendar") : i18n("Expand calendar")
                    icon.name: expandedRoot.calendarExpanded ? "go-up-symbolic" : "go-down-symbolic"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    onClicked: expandedRoot.calendarExpanded = !expandedRoot.calendarExpanded
                    PlasmaComponents.ToolTip { text: parent.text }
                }
            }
        }

        // ── Calendar grid ──
        CalendarView {
            id: calendarView
            objectName: "wmCalendarSection"
            calendarLocale: expandedRoot.calendarLocale
            applet: expandedRoot.clockApplet
            Layout.fillWidth: true
            Layout.fillHeight: false
            visible: expandedRoot.calendarExpanded
            focus: visible
            // Reserve the real header, notification minimum and optional
            // sections. No hardcoded scrolling viewport or clipped last row.
            readonly property real extraHeight:
                (timeZoneView.visible ? timeZoneView.Layout.preferredHeight : 0)
                + (agenda.visible ? agenda.implicitHeight + 1 : 0)
            readonly property int gaps: 3 + (timeZoneView.visible ? 1 : 0) + (agenda.visible ? 2 : 0)
            dayHeightLimit: Math.max(12, Math.min(40, Math.floor(
                (mainColumn.height - history.minimumSectionHeight - headerColumn.implicitHeight
                 - extraHeight - 1 - gaps * mainColumn.spacing - chromeHeight) / 6)))
        }

        // ── Optional timezone list ──
        TimeZoneView {
            id: timeZoneView
            applet: expandedRoot.clockApplet
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Math.min(84, implicitHeight) : 0
            Layout.minimumHeight: 0
            Layout.maximumHeight: Layout.preferredHeight
            visible: expandedRoot.calendarExpanded && (Plasmoid.configuration.selectedTimeZones.length > 1 || Plasmoid.configuration.showLocalTimezone)
        }

        Rectangle {
            Layout.fillWidth: true
            visible: agenda.visible
            implicitHeight: 1
            color: palette.surfaceBorder
        }

        DayAgenda {
            id: agenda
            calendarLocale: expandedRoot.calendarLocale
            Layout.fillWidth: true
            visible: expandedRoot.calendarExpanded && calendarView.selectedDayEvents.length > 0
            date: calendarView.selectedDate
            events: calendarView.selectedDayEvents
            // Preserve up to four events when room permits, prioritizing
            // the calendar's six rows on shorter displays.
            maximumEvents: Math.max(1, Math.min(4, Math.floor(
                (mainColumn.height - history.minimumSectionHeight - headerColumn.implicitHeight
                 - calendarView.chromeHeight - 6 * 24 - 5 * mainColumn.spacing
                 - (timeZoneView.visible ? timeZoneView.Layout.preferredHeight + mainColumn.spacing : 0)
                 - 32) / 36)))
        }
    }
}
