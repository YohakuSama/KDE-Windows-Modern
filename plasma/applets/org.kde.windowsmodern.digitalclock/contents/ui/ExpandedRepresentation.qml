/*
    SPDX-FileCopyrightText: 2026 Jeysef

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "code/dateformat.js" as DateFormat

Item {
    id: expandedRoot
    property bool calendarExpanded: true

    Win11Palette { id: palette }

    // A single flyout with notification history above the existing calendar.
    // Plasma supplies its frame, blur and shadow; the children use one palette.
    readonly property int margin: Kirigami.Units.largeSpacing
    readonly property int availableScreenHeight: Plasmoid.screenGeometry.height > 0
        ? Math.max(Kirigami.Units.gridUnit * 8,
                   Plasmoid.screenGeometry.height - Kirigami.Units.gridUnit * 5)
        : 720
    implicitWidth: Plasmoid.configuration.expandedWidth
    Layout.preferredWidth: implicitWidth
    Layout.maximumWidth: implicitWidth
    implicitHeight: Math.min(availableScreenHeight, Math.ceil(mainColumn.implicitHeight + 2 * margin))
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight
    Layout.maximumHeight: implicitHeight
    clip: true

    Flickable {
        id: viewport
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight + 2 * expandedRoot.margin
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

        ColumnLayout {
            id: mainColumn
            x: expandedRoot.margin
            y: expandedRoot.margin
            width: Math.max(1, viewport.width - 2 * expandedRoot.margin)
            spacing: Kirigami.Units.largeSpacing

            NotificationHistory {
                Layout.fillWidth: true
                currentTime: root.currentTime
                notificationsAvailable: root.notificationsAvailable
                effectiveDnd: root.notificationsInhibited
                notificationModel: root.notificationModel
                settings: root.notificationSettings
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
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Kirigami.Units.smallSpacing / 2

                    PlasmaComponents.Label {
                        id: timeHeader
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        textFormat: Text.PlainText
                        text: {
                            const fmt = root.timeFormatWithSeconds;
                            // Render the AM/PM suffix separately so it can be smaller.
                            if (fmt.toLowerCase().includes("ap")) {
                                return Qt.locale().toString(root.currentTime, fmt.replace(/\s+AP/i, ""));
                            }
                            return Qt.locale().toString(root.currentTime, fmt);
                        }
                        color: palette.text
                        font {
                            family: Kirigami.Theme.defaultFont.family
                            weight: Font.DemiBold
                            pixelSize: Kirigami.Units.gridUnit * 3
                            features: { "tnum": 1 }
                        }
                    }

                    PlasmaComponents.Label {
                        id: amPmLabel
                        visible: root.timeFormatWithSeconds.toLowerCase().includes("ap")
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignTop
                        textFormat: Text.PlainText
                        text: Qt.locale().toString(root.currentTime, "AP")
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
                        // Windows 11 shows the locale's long date without the year.
                        text: Qt.locale().toString(root.currentTime,
                                                   DateFormat.longDateWithoutYear(Qt.locale().dateFormat(Locale.LongFormat)))
                        color: palette.textSecondary
                        font {
                            family: Kirigami.Theme.defaultFont.family
                            pixelSize: Kirigami.Units.gridUnit * 1.1
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
                Layout.fillWidth: true
                visible: expandedRoot.calendarExpanded
                focus: visible
            }

            // ── Optional timezone list ──
            TimeZoneView {
                id: timeZoneView
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
