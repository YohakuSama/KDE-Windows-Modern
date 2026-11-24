// SPDX-License-Identifier: GPL-3.0-or-later
// Instantiate the real full representation with calendar/settings backends
// mocked. This checks component creation and layout, not Wayland mapping.
import QtQuick
import QtQuick.Layouts
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.digitalclock/contents/ui"

Item {
    id: root
    width: 420
    height: 620

    function i18n(text) { return text; }
    function i18nc(context, text) { return text; }
    function i18np(singular, plural, n) {
        return (n === 1 ? singular : plural).replace("%1", n);
    }

    ListModel { id: notifications }
    QtObject {
        id: settings
        property var notificationsInhibitedUntil
        function save() {}
    }
    QtObject {
        id: clock
        property date currentTime: new Date(2026, 10, 25, 5, 0)
        property string timeFormatWithSeconds: "HH:mm:ss"
        property bool expanded: true
        readonly property bool flyoutOpen: expanded
        property rect popupScreenGeometry: Qt.rect(0, 0, 1280, 720)
        property real popupPanelExtent: 48
        property bool notificationsAvailable: true
        property bool notificationsInhibited: false
        property var notificationModel: notifications
        property var notificationSettings: settings
        property string currentTimeZone: "Local"
        function selectedTimeZonesDeduplicatingExplicitLocalTimeZone() { return []; }
    }
    ExpandedRepresentation {
        id: popup
        clockApplet: clock
        width: implicitWidth
        height: implicitHeight
    }
    TestCase {
        name: "ClockExpandedRepresentation"
        when: windowShown
        function test_fullCalendarHasUsableGeometry() {
            compare(popup.implicitWidth, 320);
            verify(popup.implicitHeight >= 400);
            compare(popup.Layout.minimumWidth, popup.implicitWidth);
            compare(popup.Layout.minimumHeight, popup.implicitHeight);
            verify(popup.width >= 300 && popup.height >= 400);
            tryVerify(() => findChildLabel(popup, "Notifications") !== null);
        }
        function findChildLabel(item, text) {
            if (item.text === text && item.visible && item.width > 0 && item.height > 0)
                return item;
            for (const child of item.children) {
                const result = findChildLabel(child, text);
                if (result !== null) return result;
            }
            return null;
        }
        function test_calendarFitsWithoutOuterScroll() {
            const content = findChild(popup, "wmClockContent");
            const calendar = findChild(popup, "wmCalendarSection");
            const bar = findChild(popup, "wmNotificationScrollBar");
            const grid = findChild(popup, "wmCalendarDayGrid");
            verify(content !== null && calendar !== null && bar !== null && grid !== null);
            for (const h of [600, 720, 900]) {
                clock.popupScreenGeometry = Qt.rect(0, 0, 1280, h);
                tryVerify(() => {
                    const pos = calendar.mapToItem(popup, 0, 0);
                    const gridPos = grid.mapToItem(popup, 0, 0);
                    return calendar.height > 150 && pos.y >= 0
                        && pos.y + calendar.height <= popup.height - 15
                        && grid.height >= 6 * grid.cellHeight + 5 * grid.spacing - 1
                        && gridPos.y + grid.height <= popup.height - 15;
                }, 2000);
                verify(!bar.visible || !bar.indicatorVisible);
            }
            clock.popupScreenGeometry = Qt.rect(0, 0, 1280, 720);
        }
        function test_collapseCalendarDoesNotCollapseWindow() {
            popup.calendarExpanded = false;
            verify(popup.implicitHeight >= 220);
            popup.calendarExpanded = true;
            verify(popup.implicitHeight >= 400);
        }
    }
}
