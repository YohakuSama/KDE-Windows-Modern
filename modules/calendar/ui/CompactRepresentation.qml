/*
    SPDX-FileCopyrightText: 2026 Jeysef

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtCore

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.clock as PlasmaClock
import org.kde.plasma.private.digitalclock as DigitalClockPrivate
import org.kde.kirigami as Kirigami

import "code/dateformat.js" as DateFormat
import "code/popupGeometry.js" as PopupGeometry
import "code/notificationPresentation.js" as NotificationPresentation
import "code/colorType.js" as ColorType

MouseArea {
    id: main
    objectName: "windowsmodern-digitalclock-compactrepresentation"

    activeFocusOnTab: true
    hoverEnabled: true

    Layout.fillWidth: false
    Layout.fillHeight: true

    required property var plasmoidItem

    readonly property real panelHeight: parent ? parent.height : height
    readonly property var panelWindow: main.Window.window
    readonly property rect panelGeometry: panelWindow
        ? Qt.rect(panelWindow.x, panelWindow.y, panelWindow.width, panelWindow.height) : Qt.rect(0, 0, 0, 0)
    onPanelGeometryChanged: if (clockDialog && clockDialog.visible) clockDialog.visible = false
    readonly property bool showBell: NotificationPresentation.showBell(
        Plasmoid.configuration.showNotificationButton,
        Plasmoid.formFactor !== PlasmaCore.Types.Vertical,
        plasmoidItem.notificationsAvailable, plasmoidItem.notificationModel.count,
        plasmoidItem.notificationsInhibited)
    readonly property string filledDndAsset: String(StandardPaths.locate(StandardPaths.GenericDataLocation,
        "windows-modern/native-assets/icons/status/wm-notification-snooze-filled-symbolic.svg", StandardPaths.LocateFile))
    readonly property string panelNotificationIcon: NotificationPresentation.panelBellIcon(
        plasmoidItem.notificationIcon, plasmoidItem.notificationsInhibited,
        ColorType.isDark(Kirigami.Theme.backgroundColor),
        filledDndAsset.length > 0)
    readonly property var popupCoordinator: plasmoidItem.popupCoordinator ?? null
    // Close on reconfiguration; reopening uses the current focus group or
    // native deactivation. The pin preference still governs focus loss.
    onPopupCoordinatorChanged: if (clockDialog && clockDialog.visible) clockDialog.visible = false
    property bool wasExpanded: false
    function toggleFlyout(previous = plasmoidItem.flyoutOpen) {
        clockDialog.toggle(previous);
    }

    // The dialog is constructed alongside its real panel item, just like
    // Start. A null/reparented representation must never map a popup at (0,0).
    Item {
        id: clockPopupAnchor
        width: main.width
        height: main.height
        function sync() {
            const edge = Plasmoid.location === PlasmaCore.Types.BottomEdge ? "bottom"
            : Plasmoid.location === PlasmaCore.Types.TopEdge ? "top"
            : Plasmoid.location === PlasmaCore.Types.LeftEdge ? "left"
            : Plasmoid.location === PlasmaCore.Types.RightEdge ? "right" : "";
            const pos = main.mapToGlobal(0, 0);
            const offset = PopupGeometry.normalOffset(edge, main.panelGeometry,
                {x: pos.x, y: pos.y, width: main.width, height: main.height});
            x = offset.x;
            y = offset.y;
        }
    }

    // Verify mapped geometry, not merely a successfully loaded QML tree.
    Timer {
        id: clockGeometryProbe
        interval: 200
        onTriggered: {
            if (!clockDialog.visible) return;
            const a = main.mapToGlobal(0, 0);
            const panel = main.panelGeometry;
            const screen = Plasmoid.screenGeometry;
            const x = clockDialog.x, y = clockDialog.y;
            const w = clockDialog.width, h = clockDialog.height;
            const location = Plasmoid.location;
            let gap = 0;
            let axisOverlap = false;
            if (location === PlasmaCore.Types.BottomEdge || location === PlasmaCore.Types.TopEdge) {
                gap = location === PlasmaCore.Types.BottomEdge ? panel.y - (y + h) : y - (panel.y + panel.height);
                axisOverlap = x <= a.x + main.width && x + w >= a.x;
            } else if (location === PlasmaCore.Types.LeftEdge || location === PlasmaCore.Types.RightEdge) {
                gap = location === PlasmaCore.Types.LeftEdge ? x - (panel.x + panel.width) : panel.x - (x + w);
                axisOverlap = y <= a.y + main.height && y + h >= a.y;
            }
            const inBounds = x >= screen.x - 2 && y >= screen.y - 2
                && x + w <= screen.x + screen.width + 2 && y + h <= screen.y + screen.height + 2;
            const ok = inBounds && axisOverlap && Math.abs(gap - PopupGeometry.popupGap()) <= 3;
            console.info("WM_POPUP clock", ok ? "OK" : "POSITION_MISMATCH",
                x, y, w, h, "anchor", a.x, a.y, main.width, main.height, "gap", gap);
        }
    }

    PlasmaCore.Dialog {
        id: clockDialog
        objectName: "wmClockSplitPopup"
        type: PlasmaCore.Dialog.AppletPopup
        flags: Qt.Dialog
        visualParent: clockPopupAnchor
        location: Plasmoid.location
        floating: PopupGeometry.popupGap()
        backgroundHints: PlasmaCore.Dialog.NoBackground
        visible: false
        hideOnWindowDeactivate: !main.popupCoordinator && !Plasmoid.configuration.pin
        property bool wmKeepOnDeactivate: Plasmoid.configuration.pin
        function closeCoordinatedPopup() { visible = false; }
        function dismissFromUser() {
            visible = false;
            if (main.popupCoordinator)
                main.popupCoordinator.restoreShellPopupFocus();
        }
        function applyNotificationSlide() {
            const provider = main.plasmoidItem.splitBlurProvider;
            if (provider && typeof provider.setNotificationPopupSlide === "function")
                provider.setNotificationPopupSlide(clockPopupContent);
        }
        onVisibleChanged: {
            if (visible) {
                applyNotificationSlide();
                clockGeometryProbe.restart();
            } else clockGeometryProbe.stop();
            if (clockPopupContent) clockPopupContent.scheduleSplitBlur();
        }
        onWidthChanged: if (visible) {
            applyNotificationSlide();
            clockGeometryProbe.restart();
        }
        onHeightChanged: if (visible) {
            applyNotificationSlide();
            clockGeometryProbe.restart();
        }

        function toggle(previous) {
            if (previous) { dismissFromUser(); return; }
            if (!clockPopupAnchor.Window.window || !clockPopupAnchor.visible
                || clockPopupAnchor.width <= 0 || clockPopupAnchor.height <= 0) {
                console.warn("WM_POPUP clock: panel anchor not mapped");
                return;
            }
            clockPopupAnchor.sync();
            if (main.popupCoordinator)
                main.popupCoordinator.prepareShellPopup("clock", clockDialog);
            applyNotificationSlide();
            visible = true;
            requestActivate();
        }

        mainItem: ExpandedRepresentation {
            id: clockPopupContent
            clockApplet: main.plasmoidItem
            splitBlurProvider: main.plasmoidItem.splitBlurProvider
            allowSplitAcrylic: main.plasmoidItem.allowSplitAcrylic
            width: implicitWidth
            height: implicitHeight
            focus: true
            Keys.onEscapePressed: clockDialog.dismissFromUser()
        }
    }

    Component.onCompleted: plasmoidItem.panelPopup = clockDialog
    Component.onDestruction: {
        if (plasmoidItem && plasmoidItem.panelPopup === clockDialog)
            plasmoidItem.panelPopup = null;
    }

    // The panel sizes applets from their Layout hints; without them the
    // clock got a square cell and a full-year date overflowed it.
    readonly property int leadingInset: 4
    readonly property int trailingInset: showBell ? 0 : Kirigami.Units.smallSpacing
    readonly property int bellCellWidth: 24
    readonly property int bellIconSize: Math.max(1, Math.min(16, Math.floor(panelHeight)))
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
        const wanted = Plasmoid.configuration.autoFontAndSize
            ? 12 : (baseFont.pixelSize > 0
                ? baseFont.pixelSize : Math.round(baseMetrics.height / lineHeightFactor));
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
        } else if (format === "regionalDate") {
            return Qt.locale().toString(d, DateFormat.shortDateFullYear(Qt.locale().dateFormat(Locale.ShortFormat)));
        } else {
            return Qt.formatDate(d, DateFormat.windowsShortDate());
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
    onPressed: wasExpanded = plasmoidItem.flyoutOpen
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
        visible: main.containsMouse || main.activeFocus || main.plasmoidItem.flyoutOpen
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                       Kirigami.Theme.textColor.b, main.containsPress ? 0.12 : 0.06)
    }

    RowLayout {
        id: panelContent
        anchors.fill: parent
        anchors.leftMargin: main.leadingInset
        anchors.rightMargin: main.trailingInset
        spacing: 4

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

                text: DateFormat.formatClockTime(main.plasmoidItem.clockTimeLocale, clock.dateTime,
                    Plasmoid.configuration.showSeconds === 2 ? main.plasmoidItem.timeFormatWithSeconds : main.plasmoidItem.timeFormat)

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
            objectName: "wmTaskbarNotificationButton"
            visible: main.showBell
            Layout.alignment: Qt.AlignVCenter
            // Keep the final cell fixed. The six-pixel Show Desktop
            // sliver supplies the trailing gap; don't add another inset.
            Layout.minimumWidth: main.bellCellWidth
            Layout.preferredWidth: main.bellCellWidth
            Layout.maximumWidth: main.bellCellWidth
            Layout.minimumHeight: Math.min(main.panelHeight, 24)
            Layout.preferredHeight: Math.min(main.panelHeight, 32)
            Layout.maximumHeight: Layout.preferredHeight
            text: i18n("Notification center")
            display: PlasmaComponents.AbstractButton.IconOnly
            icon.name: main.panelNotificationIcon
            // A compact notification glyph, with an independent click target.
            icon.width: main.bellIconSize
            icon.height: main.bellIconSize
            padding: 0
            contentItem: Item {
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.min(main.bellIconSize, parent.width, parent.height)
                    height: width
                    roundToIconSize: false
                    isMask: true
                    color: Kirigami.Theme.textColor
                    fallback: ""
                    visible: String(source).length > 0
                    source: {
                        const name = main.panelNotificationIcon;
                        const file = StandardPaths.locate(StandardPaths.GenericDataLocation,
                            "windows-modern/native-assets/icons/status/" + name + ".svg", StandardPaths.LocateFile);
                        if (String(file).length > 0) return file;
                        const fallback = StandardPaths.locate(StandardPaths.GenericDataLocation,
                            "windows-modern/native-assets/icons/status/" + name.replace(/-symbolic$/, "") + ".svg",
                            StandardPaths.LocateFile);
                        return String(fallback);
                    }
                }
            }
            Accessible.name: text
            Accessible.description: main.plasmoidItem.notificationStatusText
            property bool wasExpanded: false
            onPressed: wasExpanded = main.plasmoidItem.flyoutOpen
            onClicked: main.toggleFlyout(wasExpanded)
            PlasmaComponents.ToolTip {
                text: main.plasmoidItem.notificationStatusText
                visible: notificationButton.hovered && !main.plasmoidItem.flyoutOpen
            }
        }
    }
}
