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
import org.kde.plasma.clock as PlasmaClock
import org.kde.plasma.private.digitalclock as DigitalClockPrivate
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: timeZoneView
    required property var applet

    Win11Palette { id: palette }

    spacing: Kirigami.Units.smallSpacing

    PlasmaComponents.Label {
        Layout.fillWidth: true
        text: i18n("Time Zones")
        color: palette.text
        font {
            weight: Font.Bold
            pixelSize: Kirigami.Units.gridUnit
        }
    }

    ListView {
        id: clocksList
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        Layout.preferredHeight: contentHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: FluentScrollBar {}
        Kirigami.WheelHandler {
            target: clocksList
            filterMouseEvents: true
            keyNavigationEnabled: false
            verticalStepSize: 120
        }

        model: timeZoneView.applet.selectedTimeZonesDeduplicatingExplicitLocalTimeZone()

        delegate: RowLayout {
            id: listItem

            required property string modelData

            readonly property bool isCurrentTimeZone: tzClock.timeZone === timeZoneView.applet.currentTimeZone
            readonly property string tzLabel: {
                switch (Plasmoid.configuration.displayTimezoneFormat) {
                case 0: // Code
                    return tzClock.timeZoneCode;
                case 1: // City
                    return DigitalClockPrivate.TimeZonesI18n.i18nCity(tzClock.timeZone);
                case 2: // Offset from UTC time
                    return tzClock.timeZoneOffset;
                }
                return "";
            }

            width: ListView.view.width
            height: Kirigami.Units.gridUnit * 2

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: listItem.tzLabel
                color: listItem.isCurrentTimeZone ? palette.text : palette.textSecondary
                font.weight: listItem.isCurrentTimeZone ? Font.Bold : Font.Normal
                textFormat: Text.PlainText
                elide: Text.ElideRight
            }

            PlasmaComponents.Label {
                text: timeZoneView.applet.formatTime(tzClock.dateTime, Plasmoid.configuration.showSeconds === 2)
                color: listItem.isCurrentTimeZone ? palette.text : palette.textSecondary
                font.weight: listItem.isCurrentTimeZone ? Font.Bold : Font.Normal
                textFormat: Text.PlainText
            }

            PlasmaComponents.Label {
                visible: !listItem.isCurrentTimeZone
                text: timeZoneView.applet.formatOffset(tzClock.dateTime)
                color: palette.textSecondary
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                textFormat: Text.PlainText
            }

            PlasmaClock.Clock {
                id: tzClock
                timeZone: listItem.modelData
                trackSeconds: Plasmoid.configuration.showSeconds === 2
            }
        }
    }
}
