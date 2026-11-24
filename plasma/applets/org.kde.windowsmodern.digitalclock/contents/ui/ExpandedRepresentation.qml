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
    property bool calendarOnly: false
    property real historyAnchorY: 0
    readonly property alias historyAnchor: secondaryAnchor

    readonly property var clockTimeLocale: Qt.locale(DateFormat.clockLocaleName(
        Plasmoid.configuration.use24hFormat, Qt.locale().name))
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
    readonly property int margin: calendarOnly ? 0 : 2
    readonly property int sectionGap: 12
    readonly property int sectionInset: 12
    readonly property int calendarHeaderHeight: 50
    readonly property int focusFooterHeight: 48
    readonly property int bodyInset: 12
    readonly property bool showLargeClock: Plasmoid.configuration.showTimeInNotificationCenter
    readonly property var focusSession: clockApplet.focusSession
    readonly property var panelScreen: clockApplet.popupScreenGeometry
    readonly property real screenWidth: Number(panelScreen?.width || 0)
    readonly property real screenHeight: Number(panelScreen?.height || 0)
    readonly property real panelExtent: Math.min(96, Math.max(0, Number(clockApplet.popupPanelExtent) || 48))
    readonly property int availableScreenHeight: screenHeight >= 100
        ? Math.max(1, Math.floor(screenHeight - panelExtent - 32)) : 720
    readonly property int configuredWidth: Math.max(240, Number(Plasmoid.configuration.expandedWidth) || 320)
    readonly property int popupWidth: Math.min(configuredWidth, screenWidth >= 100
        ? Math.max(1, Math.floor(screenWidth - 24)) : configuredWidth)
    // Collapsing the calendar transfers space to notifications. The total
    // height must not collapse to the calendar's own height.
    readonly property int flyoutTotalHeight: Math.min(740, availableScreenHeight)
    readonly property int collapsedCalendarHeight: calendarHeaderHeight + focusFooterHeight + 1
    readonly property int expandedCalendarHeight: Math.max(collapsedCalendarHeight,
        Math.min(452 + (showLargeClock ? 52 : 0), flyoutTotalHeight - sectionGap - 110))
    readonly property int calendarHeight: calendarExpanded ? expandedCalendarHeight : collapsedCalendarHeight
    readonly property int popupHeight: calendarOnly ? calendarHeight : flyoutTotalHeight

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
        if (typeof clockApplet.closeFlyout === "function")
            clockApplet.closeFlyout();
        else
            clockApplet.expanded = false;
        event.accepted = true;
    }

    // In the standard horizontal taskbar, each section lives in its own
    // native AppletPopup. The combined variant is a fallback for vertical
    // panels and very short screens. Both share the same content metrics.
    readonly property real calendarBodyBudget: Math.max(0, expandedCalendarHeight
        - calendarHeaderHeight - focusFooterHeight - 2 * bodyInset - 2)

    // Anchor for the history window, aligned with the calendar's native
    // frame edge. This Item is not drawn and never accepts input.
    Item {
        id: secondaryAnchor
        width: expandedRoot.width
        height: 1
        y: expandedRoot.historyAnchorY
    }

    ColumnLayout {
        id: mainColumn
        objectName: "wmClockContent"
        anchors.fill: parent
        anchors.margins: expandedRoot.margin
        spacing: expandedRoot.sectionGap

        Rectangle {
            id: notificationPanel
            objectName: "wmNotificationPanel"
            visible: !expandedRoot.calendarOnly
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: history.minimumSectionHeight + 2 * expandedRoot.sectionInset
            Layout.preferredHeight: 224
            radius: 8
            color: palette.panelTint
            border.width: 0

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
            Layout.fillHeight: expandedRoot.calendarOnly
            Layout.preferredHeight: expandedRoot.calendarOnly
                ? expandedRoot.calendarHeight : calendarContent.implicitHeight
            Layout.minimumHeight: Layout.preferredHeight
            Layout.maximumHeight: Layout.preferredHeight
            radius: 8
            color: expandedRoot.calendarOnly ? "transparent" : palette.panelTint
            border.width: 0

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
                        text: expandedRoot.calendarExpanded ? i18n("Collapse calendar") : i18n("Expand calendar")
                        icon.name: expandedRoot.calendarExpanded ? "go-down-symbolic" : "go-up-symbolic"
                        display: PlasmaComponents.AbstractButton.IconOnly
                        onClicked: expandedRoot.calendarExpanded = !expandedRoot.calendarExpanded
                        PlasmaComponents.ToolTip { text: parent.text }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    visible: expandedRoot.calendarExpanded
                    color: palette.panelBorder
                }

                ColumnLayout {
                    id: calendarBody
                    Layout.fillWidth: true
                    Layout.fillHeight: expandedRoot.calendarOnly && visible
                    Layout.leftMargin: expandedRoot.sectionInset
                    Layout.rightMargin: expandedRoot.sectionInset
                    Layout.topMargin: visible ? expandedRoot.bodyInset : 0
                    Layout.bottomMargin: visible ? expandedRoot.bodyInset : 0
                    visible: expandedRoot.calendarExpanded
                    spacing: 6

                    RowLayout {
                        id: timeRow
                        visible: expandedRoot.showLargeClock
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
                                    return expandedRoot.clockTimeLocale.toString(expandedRoot.clockApplet.currentTime, fmt.replace(/\s+AP/i, ""));
                                }
                                return expandedRoot.clockTimeLocale.toString(expandedRoot.clockApplet.currentTime, fmt);
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
                            visible: expandedRoot.clockApplet.timeFormatWithSeconds.toLowerCase().includes("ap")
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignTop
                            textFormat: Text.PlainText
                            text: expandedRoot.clockTimeLocale.toString(expandedRoot.clockApplet.currentTime, "AP")
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
                        focus: expandedRoot.calendarExpanded
                        dayHeightLimit: Math.max(12, Math.min(40, Math.floor(
                            (expandedRoot.calendarBodyBudget - chromeHeight
                             - (timeRow.visible ? timeRow.implicitHeight + calendarBody.spacing : 0)
                             - (timeZoneView.visible ? timeZoneView.Layout.preferredHeight + calendarBody.spacing : 0)
                             - (agenda.visible ? agenda.implicitHeight + calendarBody.spacing : 0)) / 6)))
                    }

                    TimeZoneView {
                        id: timeZoneView
                        applet: expandedRoot.clockApplet
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? Math.min(84, implicitHeight) : 0
                        Layout.minimumHeight: 0
                        Layout.maximumHeight: Layout.preferredHeight
                        visible: Plasmoid.configuration.selectedTimeZones.length > 1
                            || Plasmoid.configuration.showLocalTimezone
                    }

                    DayAgenda {
                        id: agenda
                        calendarLocale: expandedRoot.calendarLocale
                        Layout.fillWidth: true
                        visible: calendarView.selectedDayEvents.length > 0
                            && expandedRoot.calendarBodyBudget >= 260
                        date: calendarView.selectedDate
                        events: calendarView.selectedDayEvents
                        maximumEvents: Math.max(1, Math.min(4, Math.floor(
                            (expandedRoot.calendarBodyBudget - calendarView.chromeHeight - 6 * 24
                             - (timeRow.visible ? timeRow.implicitHeight + calendarBody.spacing : 0)
                             - (timeZoneView.visible ? timeZoneView.Layout.preferredHeight + calendarBody.spacing : 0)
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

                    FlyoutButton {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        enabled: !!expandedRoot.focusSession && !expandedRoot.focusSession.running
                            && expandedRoot.focusSession.durationMinutes > 5
                        text: i18n("Decrease focus duration")
                        icon.name: "list-remove"
                        display: PlasmaComponents.AbstractButton.IconOnly
                        onClicked: expandedRoot.focusSession.adjust(-5)
                        PlasmaComponents.ToolTip { text: parent.text }
                    }
                    PlasmaComponents.Label {
                        Layout.preferredWidth: 76
                        horizontalAlignment: Text.AlignHCenter
                        textFormat: Text.PlainText
                        text: expandedRoot.focusSession && expandedRoot.focusSession.running
                            ? expandedRoot.focusSession.countdown
                            : i18n("%1 mins", expandedRoot.focusSession ? expandedRoot.focusSession.durationMinutes : 30)
                        color: palette.text
                        font.pixelSize: 12
                        font.features: { "tnum": 1 }
                    }
                    FlyoutButton {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        enabled: !!expandedRoot.focusSession && !expandedRoot.focusSession.running
                            && expandedRoot.focusSession.durationMinutes < 240
                        text: i18n("Increase focus duration")
                        icon.name: "list-add"
                        display: PlasmaComponents.AbstractButton.IconOnly
                        onClicked: expandedRoot.focusSession.adjust(5)
                        PlasmaComponents.ToolTip { text: parent.text }
                    }

                    Item { Layout.fillWidth: true }

                    FlyoutButton {
                        objectName: "wmFocusButton"
                        enabled: !!expandedRoot.focusSession
                        Layout.preferredHeight: 26
                        text: expandedRoot.focusSession && expandedRoot.focusSession.running
                            ? i18n("Stop focus") : i18n("Focus")
                        icon.name: expandedRoot.focusSession && expandedRoot.focusSession.running
                            ? "media-playback-stop" : "media-playback-start"
                        onClicked: {
                            if (expandedRoot.focusSession.running)
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
