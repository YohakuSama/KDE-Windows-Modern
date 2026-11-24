/*
    SPDX-FileCopyrightText: 2026 Jeysef

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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

    Flickable {
        id: viewport
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.height + 2 * expandedRoot.margin
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        QQC2.ScrollBar.vertical: FluentScrollBar {}
        Kirigami.WheelHandler {
            target: viewport
            filterMouseEvents: true
            keyNavigationEnabled: false
            verticalStepSize: 120
        }

        ColumnLayout {
            id: mainColumn
            x: expandedRoot.margin
            y: expandedRoot.margin
            width: Math.max(1, (viewport.width > 0 ? viewport.width : expandedRoot.implicitWidth)
                - 2 * expandedRoot.margin)
            height: implicitHeight
            spacing: Kirigami.Units.largeSpacing

            NotificationHistory {
                Layout.fillWidth: true
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
                        text: Qt.locale().toString(expandedRoot.clockApplet.currentTime,
                                                   DateFormat.longDateWithoutYear(Qt.locale().dateFormat(Locale.LongFormat)))
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
                applet: expandedRoot.clockApplet
                Layout.fillWidth: true
                visible: expandedRoot.calendarExpanded
                focus: visible
            }

            // ── Optional timezone list ──
            TimeZoneView {
                id: timeZoneView
                applet: expandedRoot.clockApplet
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? Kirigami.Units.gridUnit * 8 : 0
                visible: expandedRoot.calendarExpanded && (Plasmoid.configuration.selectedTimeZones.length > 1 || Plasmoid.configuration.showLocalTimezone)
            }

            Rectangle {
                Layout.fillWidth: true
                visible: expandedRoot.calendarExpanded
                implicitHeight: 1
                color: palette.surfaceBorder
            }

            DayAgenda {
                Layout.fillWidth: true
                visible: expandedRoot.calendarExpanded
                date: calendarView.selectedDate
                events: calendarView.selectedDayEvents
            }
        }
    }
}
