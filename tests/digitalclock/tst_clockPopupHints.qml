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
        id: blurBackend
        property bool supported: true
        property int calls: 0
        property bool lastEnabled: false
        function setSplitPopupBlur(content, first, second, radius, enabled) {
            calls++;
            lastEnabled = enabled;
            return supported && enabled && first.width > 0 && second.width > 0
                && radius === 8;
        }
    }
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
        property bool popupVerticalPanel: false
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
        function test_splitAcrylicUsesExistingBackendOrSolidFallback() {
            const panel = findChild(popup, "wmNotificationPanel");
            compare(popup.splitAcrylic, false);
            compare(panel.color.a, 1);
            popup.splitBlurProvider = blurBackend;
            popup.allowSplitAcrylic = true;
            tryCompare(popup, "splitAcrylic", true);
            verify(panel.color.a < 1);
            popup.allowSplitAcrylic = false;
            tryCompare(popup, "splitAcrylic", false);
            compare(blurBackend.lastEnabled, false);
            compare(panel.color.a, 1);
            blurBackend.supported = false;
            const calls = blurBackend.calls;
            popup.allowSplitAcrylic = true;
            tryVerify(() => blurBackend.calls > calls);
            compare(popup.splitAcrylic, false);
            popup.splitBlurProvider = null;
            popup.allowSplitAcrylic = false;
            blurBackend.supported = true;
        }
        function test_chineseCalendarWithIndependentLocale() {
            compare(popup.calendarLocale.name, "zh_CN");
            tryCompare(findChild(popup, "wmCalendarDateHeading"), "text", "11月25日 星期三");
            tryCompare(findChild(popup, "wmCalendarMonthHeading"), "text", "2026年11月");
            compare(popup.sectionGap, 12);
        }
        function test_panelOrientationAndThickness() {
            clock.popupPanelExtent = 120;
            compare(popup.availableScreenHeight, 568);
            clock.popupVerticalPanel = true;
            compare(popup.availableScreenHeight, 688);
            clock.popupScreenGeometry = Qt.rect(0, 0, 440, 720);
            compare(popup.popupWidth, 296);
            clock.popupScreenGeometry = Qt.rect(0, 0, 1280, 720);
            clock.popupPanelExtent = 48;
            clock.popupVerticalPanel = false;
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
        function test_shortScreenDoesNotClipCalendarFooter() {
            const footer = findChild(popup, "wmFocusFooter");
            clock.popupScreenGeometry = Qt.rect(0, 0, 800, 360);
            tryCompare(popup, "calendarCanExpand", false);
            tryVerify(() => footer.mapToItem(popup, 0, 0).y + footer.height <= popup.height + 1);
            clock.popupScreenGeometry = Qt.rect(0, 0, 1280, 720);
            tryCompare(popup, "calendarBodyShown", true);
        }
        function test_notificationPanelAdaptsAndHidesClearAll() {
            clock.popupScreenGeometry = Qt.rect(0, 0, 1280, 900);
            const panel = findChild(popup, "wmNotificationPanel");
            const calendar = findChild(popup, "wmCalendarPanel");
            const clear = findChild(popup, "wmClearNotifications");
            const dnd = findChild(popup, "wmDoNotDisturbBanner");
            const empty = findChild(popup, "wmEmptyNotifications");
            verify(panel && calendar && clear && dnd && empty);
            notifications.clear();
            clock.notificationsInhibited = false;
            tryCompare(clear, "visible", false);
            tryCompare(empty, "visible", true);
            tryCompare(dnd, "visible", false);
            tryVerify(() => panel.height >= 220);
            const emptyHeight = panel.height;
            const calendarHeight = calendar.height;
            notifications.append({applicationName:"System", summary:"A real notification layout",
                body:"An example message which takes up more space than the empty state.", closable:true,
                isGroup:false, isInGroup:false, expired:false});
            tryCompare(clear, "visible", true);
            tryCompare(empty, "visible", false);
            tryVerify(() => panel.height > emptyHeight);
            compare(calendar.height, calendarHeight);
            const populatedHeight = panel.height;
            const populatedPopupHeight = popup.height;
            clock.notificationsInhibited = true;
            tryCompare(dnd, "visible", true);
            tryCompare(panel, "height", populatedHeight);
            compare(popup.height, populatedPopupHeight);
            clock.notificationsInhibited = false;
            tryCompare(dnd, "visible", false);
            for (let i = 0; i < 15; ++i)
                notifications.append({applicationName:"System", summary:"Notification "+i,
                    body:"A longer body.", closable:true, isGroup:false, isInGroup:false, expired:false});
            tryVerify(() => popup.height <= popup.availableScreenHeight && panel.height > emptyHeight);
            notifications.clear();
            tryCompare(panel, "height", emptyHeight);
            tryCompare(clear, "visible", false);
            const emptyPopupHeight = popup.height;
            clock.notificationsInhibited = true;
            tryCompare(dnd, "visible", true);
            tryCompare(panel, "height", emptyHeight);
            compare(calendar.height, calendarHeight);
            compare(popup.height, emptyPopupHeight);
            tryCompare(clear, "visible", false);
            clock.notificationsInhibited = false;
            tryCompare(dnd, "visible", false);
            tryCompare(panel, "height", emptyHeight);
            clock.popupScreenGeometry = Qt.rect(0, 0, 1280, 720);
        }
        function test_focusFooterRealActions() {
            focusState.stop();
            focusState.durationMinutes = 30;
            mockSettings.notificationsInhibitedUntil = undefined;
            const decrease = findChild(popup, "wmFocusDecrease");
            const increase = findChild(popup, "wmFocusIncrease");
            const duration = findChild(popup, "wmFocusDuration");
            const running = findChild(popup, "wmFocusRunningLabel");
            const button = findChild(popup, "wmFocusButton");
            verify(decrease && increase && duration && running && button);
            tryCompare(decrease, "visible", true);
            tryCompare(increase, "visible", true);
            tryCompare(running, "visible", false);
            mouseClick(decrease);
            tryCompare(focusState, "durationMinutes", 25);
            mouseClick(increase);
            tryCompare(focusState, "durationMinutes", 30);
            mouseClick(button);
            tryCompare(focusState, "running", true);
            verify(mockSettings.notificationsInhibitedUntil.getTime() === focusState.endTime);
            tryCompare(decrease, "visible", false);
            tryCompare(increase, "visible", false);
            tryCompare(duration, "visible", false);
            tryCompare(running, "visible", true);
            compare(button.text, "End session");
            mouseClick(button);
            tryCompare(focusState, "running", false);
            tryCompare(decrease, "visible", true);
            tryCompare(running, "visible", false);
            compare(mockSettings.notificationsInhibitedUntil, undefined);
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
