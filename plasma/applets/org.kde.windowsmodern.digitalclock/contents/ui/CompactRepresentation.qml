/*
    SPDX-FileCopyrightText: 2026 Jeysef

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.clock as PlasmaClock
import org.kde.plasma.private.digitalclock as DigitalClockPrivate
import org.kde.kirigami as Kirigami

import "code/dateformat.js" as DateFormat

MouseArea {
    id: main
    objectName: "windowsmodern-digitalclock-compactrepresentation"

    activeFocusOnTab: true
    hoverEnabled: true

    Layout.fillWidth: false
    Layout.fillHeight: true

    required property var plasmoidItem

    readonly property real panelHeight: parent ? parent.height : height
    readonly property bool showBell: Plasmoid.configuration.showNotificationButton
        && Plasmoid.formFactor !== PlasmaCore.Types.Vertical
    property bool wasExpanded: false
    function toggleFlyout(previous = plasmoidItem.expanded) {
        plasmoidItem.expanded = !previous;
    }

    // The panel sizes applets from their Layout hints; without them the
    // clock got a square cell and a full-year date overflowed it.
    readonly property int leadingInset: Kirigami.Units.smallSpacing
    readonly property int trailingInset: showBell ? 0 : Kirigami.Units.smallSpacing
    readonly property int bellCellWidth: 32
    implicitWidth: panelContent.implicitWidth + leadingInset + trailingInset
    implicitHeight: panelHeight
    Layout.minimumWidth: implicitWidth
    Layout.preferredWidth: implicitWidth

    // Font configured by the user or theme defaults.
    readonly property font baseFont: {
        if (Plasmoid.configuration.autoFontAndSize || Plasmoid.configuration.fontFamily.length === 0) {
            return Kirigami.Theme.defaultFont;
        } else {
            return Qt.font({
                family: Plasmoid.configuration.fontFamily,
                pointSize: Plasmoid.configuration.fontSize,
                weight: Plasmoid.configuration.fontWeight,
                styleName: Plasmoid.configuration.fontStyleName,
                italic: Plasmoid.configuration.italicText
            });
        }
    }

    readonly property string timezoneString: {
        const showTimezone = Plasmoid.configuration.showLocalTimezone
            || (Plasmoid.configuration.lastSelectedTimezone !== "Local"
                && !clock.isSystemTimeZone);

        if (!showTimezone) {
            return "";
        }

        switch (Plasmoid.configuration.displayTimezoneFormat) {
        case 0: // Code
            return clock.timeZoneCode;
        case 1: // City
            return DigitalClockPrivate.TimeZonesI18n.i18nCity(clock.timeZone);
        case 2: // Offset from UTC time
            return clock.timeZoneOffset;
        }
        return "";
    }

    readonly property bool showDate: Plasmoid.configuration.showDate
    readonly property bool showTimezone: timezoneString.length > 0

    readonly property int lineCount: 1 + (showDate ? 1 : 0) + (showTimezone ? 1 : 0)

    // Like the Windows taskbar clock, every line uses the normal UI font
    // size (the time is not bigger than the date). The text only shrinks
    // when the panel is too thin to stack the lines at that size.
    readonly property int linePixelSize: {
        // QML uses logical pixels; physical screen DPI would apply fractional
        // scaling twice. Measure the actual configured Qt font instead.
        const wanted = baseFont.pixelSize > 0
            ? baseFont.pixelSize : Math.round(baseMetrics.height / lineHeightFactor);
        const minMargin = 2;
        const fits = Math.floor((panelHeight - 2 * minMargin) / lineCount / lineHeightFactor);
        return Math.max(6, Math.min(wanted, fits));
    }
    // Line height / pixel size of the font, measured once at a large size.
    readonly property real lineHeightFactor: Math.max(1.1, probeMetrics.height / 100)

    FontMetrics {
        id: probeMetrics
        font {
            family: main.baseFont.family
            pixelSize: 100
        }
    }

    FontMetrics {
        id: baseMetrics
        font: main.baseFont
    }

    function dateFormatter(d: date): string {
        const format = Plasmoid.configuration.dateFormat;
        if (format === "custom") {
            return Qt.locale().toString(d, Plasmoid.configuration.customDateFormat);
        } else if (format === "isoDate") {
            return Qt.formatDate(d, Qt.ISODate);
        } else if (format === "longDate") {
            return Qt.formatDate(d, Qt.locale(), Locale.LongFormat);
        } else {
            return Qt.locale().toString(d, DateFormat.shortDateFullYear(Qt.locale().dateFormat(Locale.ShortFormat)));
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: timeLabel.text + (dateLabel.visible ? ", " + dateLabel.text : "")
    Accessible.description: i18n("Open notification center and calendar")
    Accessible.onPressAction: toggleFlyout()
    Keys.onReturnPressed: toggleFlyout()
    Keys.onEnterPressed: toggleFlyout()
    Keys.onSpacePressed: toggleFlyout()

    acceptedButtons: Qt.LeftButton
    onPressed: wasExpanded = plasmoidItem.expanded
    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton)
            toggleFlyout(wasExpanded);
    }

    PlasmaClock.Clock {
        id: clock
        timeZone: Plasmoid.configuration.lastSelectedTimezone
        trackSeconds: Plasmoid.configuration.showSeconds === 2 // Always
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 4
        visible: main.containsMouse || main.activeFocus || main.plasmoidItem.expanded
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                       Kirigami.Theme.textColor.b, main.containsPress ? 0.12 : 0.06)
    }

    RowLayout {
        id: panelContent
        anchors.fill: parent
        anchors.leftMargin: main.leadingInset
        anchors.rightMargin: main.trailingInset
        spacing: Kirigami.Units.smallSpacing

        ColumnLayout {
            id: contentLayout
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            PlasmaComponents.Label {
                id: timeLabel

                Layout.fillWidth: true

                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                textFormat: Text.PlainText

                text: Qt.locale().toString(clock.dateTime, Plasmoid.configuration.showSeconds === 2 ? root.timeFormatWithSeconds : root.timeFormat)

                font {
                    family: main.baseFont.family
                    weight: main.baseFont.weight
                    italic: main.baseFont.italic
                    styleName: main.baseFont.styleName
                    pixelSize: main.linePixelSize
                    features: { "tnum": 1 }
                }
            }

            PlasmaComponents.Label {
                id: dateLabel

                visible: main.showDate
                Layout.fillWidth: true

                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                textFormat: Text.PlainText

                text: main.dateFormatter(clock.dateTime)

                font {
                    family: main.baseFont.family
                    weight: main.baseFont.weight
                    italic: main.baseFont.italic
                    styleName: main.baseFont.styleName
                    pixelSize: main.linePixelSize
                    features: { "tnum": 1 }
                }
            }

            PlasmaComponents.Label {
                id: timeZoneLabel

                visible: main.showTimezone
                Layout.fillWidth: true

                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                textFormat: Text.PlainText

                text: main.timezoneString

                font {
                    family: main.baseFont.family
                    weight: main.baseFont.weight
                    italic: main.baseFont.italic
                    styleName: main.baseFont.styleName
                    pixelSize: main.linePixelSize
                    features: { "tnum": 1 }
                }
            }
        }

        PlasmaComponents.ToolButton {
            id: notificationButton
            visible: main.showBell
            Layout.alignment: Qt.AlignVCenter
            // Keep the final cell fixed. The six-pixel Show Desktop
            // sliver supplies the trailing gap; don't add another inset.
            Layout.minimumWidth: main.bellCellWidth
            Layout.preferredWidth: main.bellCellWidth
            Layout.maximumWidth: main.bellCellWidth
            Layout.preferredHeight: Math.min(main.panelHeight, implicitHeight)
            text: i18n("Notification center")
            display: PlasmaComponents.AbstractButton.IconOnly
            icon.name: main.plasmoidItem.notificationIcon
            icon.width: Kirigami.Units.iconSizes.small
            icon.height: Kirigami.Units.iconSizes.small
            Accessible.name: text
            Accessible.description: main.plasmoidItem.notificationStatusText
            property bool wasExpanded: false
            onPressed: wasExpanded = main.plasmoidItem.expanded
            onClicked: main.toggleFlyout(wasExpanded)
            PlasmaComponents.ToolTip { text: main.plasmoidItem.notificationStatusText }
        }
    }
}
