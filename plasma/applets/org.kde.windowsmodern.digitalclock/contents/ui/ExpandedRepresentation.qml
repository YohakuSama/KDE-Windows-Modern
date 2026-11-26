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

    readonly property var clockTimeLocale: Plasmoid.configuration.use24hFormat === 1
        ? Qt.locale("en_US") : Qt.locale()
    // Match the translated UI language without changing LC_TIME.
    readonly property var calendarLocale: Qt.locale(DateFormat.calendarLocaleName(
        i18nc("@info calendar display locale (translate to a Qt locale name)", "system"),
        Qt.locale().name))

    Win11Palette { id: palette }

    property var splitBlurProvider: null
    property bool allowSplitAcrylic: false
    property bool splitAcrylic: false

    function scheduleSplitBlur() {
        if (!blurUpdate) return;
        if (clockApplet && clockApplet.flyoutOpen && splitBlurProvider) {
            blurUpdate.restart();
        } else {
            blurUpdate.stop();
            splitAcrylic = false;
        }
    }

    // Wait for both rectangles to have their final window-local geometry.
    // Only use translucent paint after the native blur call succeeds.
    Timer {
        id: blurUpdate
        interval: 16
        onTriggered: {
            expandedRoot.splitAcrylic = expandedRoot.clockApplet.flyoutOpen
                && !!expandedRoot.splitBlurProvider
                && expandedRoot.splitBlurProvider.setSplitPopupBlur(expandedRoot,
                    notificationPanel, calendarPanel, notificationPanel.radius,
                    expandedRoot.allowSplitAcrylic);
            // Plasma can refresh its own edge hint during geometry/theme
            // updates. Reassert only after the existing split-region work.
            if (expandedRoot.clockApplet.flyoutOpen && expandedRoot.splitBlurProvider
                    && typeof expandedRoot.splitBlurProvider.setNotificationPopupSlide === "function")
                expandedRoot.splitBlurProvider.setNotificationPopupSlide(expandedRoot);
        }
    }
    onSplitBlurProviderChanged: {
        if (!splitBlurProvider && splitAcrylic && clockApplet && clockApplet.flyoutOpen)
            clockApplet.closeFlyout();
        scheduleSplitBlur();
    }
    onAllowSplitAcrylicChanged: scheduleSplitBlur()
    Connections {
        target: expandedRoot.splitBlurProvider
        ignoreUnknownSignals: true
        function onPopupBlurPreferencesChanged() { expandedRoot.scheduleSplitBlur(); }
    }
    Connections {
        target: expandedRoot.clockApplet
        function onFlyoutOpenChanged() { expandedRoot.scheduleSplitBlur(); }
    }

    // Plasma owns the popup window and transfers these layout hints.
    // Derive hints from the panel's screen, not this hidden view's geometry.
    readonly property int margin: 0
    readonly property int sectionGap: 12
    readonly property int sectionInset: 12
    readonly property int calendarHeaderHeight: 44
    readonly property int focusFooterHeight: 44
    readonly property int bodyInset: 10
    readonly property bool showLargeClock: Plasmoid.configuration.showTimeInNotificationCenter
    readonly property var focusSession: clockApplet.focusSession
    readonly property var panelScreen: clockApplet.popupScreenGeometry
    readonly property real screenWidth: Number(panelScreen?.width || 0)
    readonly property real screenHeight: Number(panelScreen?.height || 0)
    readonly property bool verticalPanel: clockApplet.popupVerticalPanel === true
    readonly property real panelExtent: Math.max(0, Number(clockApplet.popupPanelExtent) || 48)
    readonly property int availableScreenHeight: screenHeight >= 100
        ? Math.max(1, Math.floor(screenHeight - (verticalPanel ? 0 : panelExtent) - 32)) : 720
    readonly property int configuredWidth: Math.max(240, Number(Plasmoid.configuration.expandedWidth) || 320)
    readonly property int popupWidth: Math.min(configuredWidth, screenWidth >= 100
        ? Math.max(1, Math.floor(screenWidth - (verticalPanel ? panelExtent : 0) - 24)) : configuredWidth)
    readonly property int notificationMinimum: history.minimumSectionHeight + 2 * sectionInset
    // Reserve a usable calendar and then let notification history grow into
    // the remaining space. Only the history list scrolls, never both cards.
    readonly property int collapsedCalendarHeight: calendarHeaderHeight + focusFooterHeight + 1
    readonly property real expandedBodyBudget: Math.max(0, availableScreenHeight
        - 2 * margin - sectionGap - notificationMinimum - collapsedCalendarHeight - 1 - 2 * bodyInset)
    readonly property bool calendarCanExpand: expandedBodyBudget >= calendarView.chromeHeight + 6 * 12
    readonly property bool calendarBodyShown: calendarExpanded && calendarCanExpand
    readonly property int calendarFixedHeight: collapsedCalendarHeight
        + (calendarBodyShown ? 1 + 2 * bodyInset : 0)
    // Reserve calendar rows before optional sections. Do not use effective
    // visibility (which is false while the popup is hidden) for size hints.
    readonly property bool largeClockShown: calendarBodyShown && showLargeClock
        && expandedBodyBudget >= calendarView.chromeHeight + 6 * 18 + 44 + calendarBody.spacing
    readonly property int zoneHeight: Math.min(84, timeZoneView.implicitHeight)
    readonly property bool zonesShown: calendarBodyShown
        && (Plasmoid.configuration.selectedTimeZones.length > 1 || Plasmoid.configuration.showLocalTimezone)
        && expandedBodyBudget >= calendarView.chromeHeight + 6 * 18
            + (largeClockShown ? 44 + calendarBody.spacing : 0) + zoneHeight + calendarBody.spacing
    readonly property bool agendaShown: calendarBodyShown && calendarView.selectedDayEvents.length > 0
        && expandedBodyBudget >= 260
        && expandedBodyBudget >= calendarView.chromeHeight + 6 * 18
            + (largeClockShown ? 44 + calendarBody.spacing : 0)
            + (zonesShown ? zoneHeight + calendarBody.spacing : 0) + agenda.implicitHeight + calendarBody.spacing
    readonly property int optionalCalendarHeight: (largeClockShown ? 44 + calendarBody.spacing : 0)
        + (zonesShown ? zoneHeight + calendarBody.spacing : 0)
        + (agendaShown ? agenda.implicitHeight + calendarBody.spacing : 0)
    readonly property int calendarPanelHeight: Math.max(calendarFixedHeight, Math.min(
        Math.max(calendarFixedHeight, availableScreenHeight - sectionGap - notificationMinimum),
        Math.ceil(calendarFixedHeight + (calendarBodyShown ? calendarView.naturalHeight + optionalCalendarHeight : 0))))
    readonly property int notificationPanelHeight: Math.max(1, Math.min(
        Math.max(1, availableScreenHeight - sectionGap - calendarPanelHeight),
        history.preferredSectionHeight + 2 * sectionInset))
    readonly property int popupHeight: Math.min(availableScreenHeight,
        notificationPanelHeight + sectionGap + calendarPanelHeight + 2 * margin)

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
        clockApplet.closeFlyout();
        event.accepted = true;
    }

    // Two independent surfaces on one transparent shell-role window.
    readonly property real calendarBodyBudget: expandedBodyBudget

    ColumnLayout {
        id: mainColumn
        objectName: "wmClockContent"
        anchors.fill: parent
        anchors.margins: expandedRoot.margin
        spacing: expandedRoot.sectionGap

        Rectangle {
            id: notificationPanel
            objectName: "wmNotificationPanel"
            Layout.fillWidth: true
            Layout.preferredHeight: expandedRoot.notificationPanelHeight
            Layout.minimumHeight: Layout.preferredHeight
            Layout.maximumHeight: Layout.preferredHeight
            radius: 8
            color: expandedRoot.splitAcrylic ? palette.acrylicPanel : palette.detachedPanel
            onXChanged: expandedRoot.scheduleSplitBlur()
            onYChanged: expandedRoot.scheduleSplitBlur()
            onWidthChanged: expandedRoot.scheduleSplitBlur()
            onHeightChanged: expandedRoot.scheduleSplitBlur()
            border.width: 1
            border.color: palette.surfaceBorder

            NotificationHistory {
                id: history
                anchors.fill: parent
                anchors.margins: expandedRoot.sectionInset
                currentTime: expandedRoot.clockApplet.currentTime
                notificationsAvailable: expandedRoot.clockApplet.notificationsAvailable
                effectiveDnd: expandedRoot.clockApplet.notificationsInhibited
                notificationModel: expandedRoot.clockApplet.notificationModel
                settings: expandedRoot.clockApplet.notificationSettings
                timeLocale: expandedRoot.clockTimeLocale
                timeFormat: expandedRoot.clockApplet.timeFormat || "h:mm AP"
            }
        }

        Rectangle {
            id: calendarPanel
            objectName: "wmCalendarPanel"
            Layout.fillWidth: true
            Layout.preferredHeight: expandedRoot.calendarPanelHeight
            Layout.minimumHeight: Layout.preferredHeight
            Layout.maximumHeight: Layout.preferredHeight
            radius: 8
            color: expandedRoot.splitAcrylic ? palette.acrylicPanel : palette.detachedPanel
            onXChanged: expandedRoot.scheduleSplitBlur()
            onYChanged: expandedRoot.scheduleSplitBlur()
            onWidthChanged: expandedRoot.scheduleSplitBlur()
            onHeightChanged: expandedRoot.scheduleSplitBlur()
            border.width: 1
            border.color: palette.surfaceBorder

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                anchors.topMargin: expandedRoot.calendarHeaderHeight
                radius: Math.max(0, calendarPanel.radius - 1)
                topLeftRadius: 0
                topRightRadius: 0
                color: palette.calendarBodyTint
            }

            ColumnLayout {
                id: calendarContent
                anchors.fill: parent
                spacing: 0

                RowLayout {
                    id: dateRow
                    Layout.fillWidth: true
                    Layout.leftMargin: expandedRoot.sectionInset
                    Layout.rightMargin: expandedRoot.sectionInset
                    Layout.preferredHeight: expandedRoot.calendarHeaderHeight
                    Layout.minimumHeight: Layout.preferredHeight
                    Layout.maximumHeight: Layout.preferredHeight
                    spacing: 8

                    PlasmaComponents.Label {
                        id: dateHeader
                        objectName: "wmCalendarDateHeading"
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        text: DateFormat.calendarLongDate(expandedRoot.calendarLocale,
                            expandedRoot.clockApplet.currentTime, Locale.LongFormat)
                        color: palette.text
                        font.pixelSize: 14
                    }

                    FlyoutButton {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        enabled: expandedRoot.calendarCanExpand
                        text: expandedRoot.calendarBodyShown ? i18n("Collapse calendar") : i18n("Expand calendar")
                        nativeIconName: expandedRoot.calendarBodyShown ? "go-down-symbolic" : "go-up-symbolic"
                        display: PlasmaComponents.AbstractButton.IconOnly
                        onClicked: expandedRoot.calendarExpanded = !expandedRoot.calendarExpanded
                        PlasmaComponents.ToolTip { text: parent.text }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    visible: expandedRoot.calendarBodyShown
                    color: palette.panelBorder
                }

                ColumnLayout {
                    id: calendarBody
                    Layout.fillWidth: true
                    Layout.leftMargin: expandedRoot.sectionInset
                    Layout.rightMargin: expandedRoot.sectionInset
                    Layout.topMargin: visible ? expandedRoot.bodyInset : 0
                    Layout.bottomMargin: visible ? expandedRoot.bodyInset : 0
                    visible: expandedRoot.calendarBodyShown
                    spacing: 6

                    RowLayout {
                        id: timeRow
                        Layout.preferredHeight: 44
                        Layout.minimumHeight: Layout.preferredHeight
                        Layout.maximumHeight: Layout.preferredHeight
                        visible: expandedRoot.largeClockShown
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Kirigami.Units.smallSpacing / 2

                        PlasmaComponents.Label {
                            id: timeHeader
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            textFormat: Text.PlainText
                            text: {
                                const fmt = expandedRoot.clockApplet.timeFormatWithSeconds;
                                const full = DateFormat.formatClockTime(expandedRoot.clockTimeLocale, expandedRoot.clockApplet.currentTime, fmt);
                                // Removing AP from the FORMAT changes 12-hour conversion.
                                // Split only the actual formatted suffix; preserve prefixes.
                                return amPmLabel.visible && full.endsWith(amPmLabel.text)
                                    ? full.slice(0, -amPmLabel.text.length).trim() : full;
                            }
                            color: palette.text
                            font {
                                family: Kirigami.Theme.defaultFont.family
                                weight: Font.DemiBold
                                pixelSize: 32
                                features: { "tnum": 1 }
                            }
                        }

                        PlasmaComponents.Label {
                            id: amPmLabel
                            visible: /\s+AP$/i.test(expandedRoot.clockApplet.timeFormatWithSeconds)
                                && text.length > 0
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignTop
                            textFormat: Text.PlainText
                            text: DateFormat.formatClockTime(expandedRoot.clockTimeLocale, expandedRoot.clockApplet.currentTime, "AP")
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

                    CalendarView {
                        id: calendarView
                        objectName: "wmCalendarSection"
                        calendarLocale: expandedRoot.calendarLocale
                        applet: expandedRoot.clockApplet
                        Layout.fillWidth: true
                        focus: expandedRoot.calendarBodyShown
                        dayHeightLimit: Math.max(12, Math.min(36, Math.floor(
                            (expandedRoot.calendarBodyBudget - chromeHeight
                             - expandedRoot.optionalCalendarHeight) / 6)))
                        Layout.preferredHeight: naturalHeight
                        Layout.minimumHeight: Layout.preferredHeight
                        Layout.maximumHeight: Layout.preferredHeight
                    }

                    TimeZoneView {
                        id: timeZoneView
                        applet: expandedRoot.clockApplet
                        Layout.fillWidth: true
                        Layout.preferredHeight: expandedRoot.zonesShown ? expandedRoot.zoneHeight : 0
                        Layout.minimumHeight: 0
                        Layout.maximumHeight: Layout.preferredHeight
                        visible: expandedRoot.zonesShown
                    }

                    DayAgenda {
                        id: agenda
                        calendarLocale: expandedRoot.calendarLocale
                        timeLocale: expandedRoot.clockTimeLocale
                        timeFormat: expandedRoot.clockApplet.timeFormat || "h:mm AP"
                        Layout.fillWidth: true
                        visible: expandedRoot.agendaShown
                        date: calendarView.selectedDate
                        events: calendarView.selectedDayEvents
                        maximumEvents: Math.max(1, Math.min(4, Math.floor(
                            (expandedRoot.calendarBodyBudget - calendarView.chromeHeight - 6 * 24
                             - (expandedRoot.largeClockShown ? 44 + calendarBody.spacing : 0)
                             - (expandedRoot.zonesShown ? expandedRoot.zoneHeight + calendarBody.spacing : 0)
                             - 36) / 36)))
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: palette.panelBorder
                }

                RowLayout {
                    id: focusRow
                    objectName: "wmFocusFooter"
                    Layout.fillWidth: true
                    Layout.leftMargin: expandedRoot.sectionInset
                    Layout.rightMargin: expandedRoot.sectionInset
                    Layout.preferredHeight: expandedRoot.focusFooterHeight
                    Layout.minimumHeight: Layout.preferredHeight
                    Layout.maximumHeight: Layout.preferredHeight
                    spacing: 6

                    readonly property bool running: !!expandedRoot.focusSession && expandedRoot.focusSession.running

                    FlyoutButton {
                        objectName: "wmFocusDecrease"
                        visible: !focusRow.running
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        enabled: !!expandedRoot.focusSession && expandedRoot.focusSession.canStart
                            && expandedRoot.focusSession.durationMinutes > 5
                        text: i18n("Decrease focus duration")
                        nativeIconName: "list-remove"
                        display: PlasmaComponents.AbstractButton.IconOnly
                        onClicked: expandedRoot.focusSession.adjust(-5)
                        PlasmaComponents.ToolTip { text: parent.text }
                    }
                    PlasmaComponents.Label {
                        objectName: "wmFocusDuration"
                        visible: !focusRow.running
                        Layout.preferredWidth: 76
                        horizontalAlignment: Text.AlignHCenter
                        textFormat: Text.PlainText
                        text: i18n("%1 mins", expandedRoot.focusSession ? expandedRoot.focusSession.durationMinutes : 30)
                        color: palette.text
                        font.pixelSize: 13
                        font.features: { "tnum": 1 }
                    }
                    FlyoutButton {
                        objectName: "wmFocusIncrease"
                        visible: !focusRow.running
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        enabled: !!expandedRoot.focusSession && expandedRoot.focusSession.canStart
                            && expandedRoot.focusSession.durationMinutes < 240
                        text: i18n("Increase focus duration")
                        nativeIconName: "list-add"
                        display: PlasmaComponents.AbstractButton.IconOnly
                        onClicked: expandedRoot.focusSession.adjust(5)
                        PlasmaComponents.ToolTip { text: parent.text }
                    }

                    PlasmaComponents.Label {
                        objectName: "wmFocusRunningLabel"
                        visible: focusRow.running
                        Layout.fillWidth: true
                        text: i18n("Focusing")
                        color: palette.text
                        font.pixelSize: 14
                        Accessible.description: expandedRoot.focusSession ? expandedRoot.focusSession.countdown : ""
                        HoverHandler { id: focusRemainingHover }
                        PlasmaComponents.ToolTip {
                            visible: focusRemainingHover.hovered && focusRow.running
                            text: expandedRoot.focusSession ? expandedRoot.focusSession.countdown : ""
                        }
                    }

                    Item { Layout.fillWidth: !focusRow.running; visible: !focusRow.running }

                    FlyoutButton {
                        objectName: "wmFocusButton"
                        enabled: !!expandedRoot.focusSession && (focusRow.running || expandedRoot.focusSession.canStart)
                        Layout.preferredHeight: 26
                        text: focusRow.running ? i18n("End session") : i18n("Focus")
                        nativeIconName: focusRow.running ? "media-playback-stop" : "media-playback-start"
                        Accessible.description: !enabled ? i18n("Notification service not available") : text
                        onClicked: {
                            if (focusRow.running)
                                expandedRoot.focusSession.stop();
                            else
                                expandedRoot.focusSession.start();
                        }
                    }
                }
            }
        }
    }
}
