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

    function i18n(text, arg) { return arg === undefined ? text : text.replace("%1", arg); }
    function i18nc(context, text) {
        return context === "@info calendar display locale (translate to a Qt locale name)" ? "zh_CN" : text;
    }
    function i18np(singular, plural, n) {
        return (n === 1 ? singular : plural).replace("%1", n);
    }

    ListModel { id: notifications }
    QtObject {
        id: mockSettings
        property var notificationsInhibitedUntil
        function save() {}
    }
    FocusSession { id: focusState; settings: mockSettings }
    QtObject {
        id: clock
        property date currentTime: new Date(2026, 10, 25, 5, 0)
        property string timeFormatWithSeconds: "HH:mm:ss"
        property string timeFormat: "HH:mm"
        property var focusSession: focusState
        property bool expanded: true
        function closeFlyout() { expanded = false; }
        readonly property bool flyoutOpen: expanded
        property rect popupScreenGeometry: Qt.rect(0, 0, 1280, 720)
        property real popupPanelExtent: 48
        property bool notificationsAvailable: true
        property bool notificationsInhibited: false
        property var notificationModel: notifications
        property var notificationSettings: mockSettings
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
        function test_chineseCalendarWithIndependentLocale() {
            compare(popup.calendarLocale.name, "zh_CN");
            tryCompare(findChild(popup, "wmCalendarDateHeading"), "text", "11月25日 星期三");
            tryCompare(findChild(popup, "wmCalendarMonthHeading"), "text", "2026年11月");
            compare(popup.sectionGap, 12);
        }
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
            const notificationPanel = findChild(popup, "wmNotificationPanel");
            const calendarPanel = findChild(popup, "wmCalendarPanel");
            const footer = findChild(popup, "wmFocusFooter");
            verify(content !== null && calendar !== null && bar !== null && grid !== null
                && notificationPanel !== null && calendarPanel !== null && footer !== null);
            for (const h of [600, 720, 900]) {
                clock.popupScreenGeometry = Qt.rect(0, 0, 1280, h);
                tryVerify(() => {
                    const pos = calendar.mapToItem(popup, 0, 0);
                    const gridPos = grid.mapToItem(popup, 0, 0);
                    const footerPos = footer.mapToItem(popup, 0, 0);
                    return calendar.height > 150 && pos.y >= 0
                        && calendarPanel.y >= notificationPanel.y + notificationPanel.height + 8
                        && pos.y + calendar.height <= footerPos.y
                        && grid.height >= 6 * grid.cellHeight + 5 * grid.spacing - 1
                        && gridPos.y + grid.height <= footerPos.y
                        && footerPos.y + footer.height <= popup.height + 1;
                }, 2000);
                verify(!bar.visible || !bar.indicatorVisible);
            }
            clock.popupScreenGeometry = Qt.rect(0, 0, 1280, 720);
        }
        function test_focusSurvivesPopupClosing() {
            focusState.durationMinutes = 30;
            focusState.start();
            verify(focusState.running);
            clock.expanded = false;
            verify(focusState.running);
            clock.expanded = true;
            focusState.stop();
            verify(!focusState.running);
        }
        function test_collapseCalendarDoesNotCollapseWindow() {
            popup.calendarExpanded = false;
            verify(popup.implicitHeight >= 220);
            popup.calendarExpanded = true;
            verify(popup.implicitHeight >= 400);
        }
    }
}
