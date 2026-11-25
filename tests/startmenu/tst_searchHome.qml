// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/pages" as Pages

Item {
    id: fixture
    width: 760
    height: 640
    function i18n(value) { return value; }
    ListModel {
        id: apps
        ListElement { display: "Test application"; decoration: "application-x-executable"; disabled: false }
        property int launches: 0
        function trigger(row, action, argument) {
            if (row !== 0) return false;
            launches++;
            return true;
        }
    }
    Pages.SearchHome {
        id: page
        anchors.fill: parent
        suggestedModel: apps
        topAppsModel: apps
    }
    SignalSpy { id: querySpy; target: page; signalName: "searchRequested" }
    SignalSpy { id: launchSpy; target: page; signalName: "applicationActivated" }
    TestCase {
        name: "SearchHome"
        when: windowShown
        function test_actions() {
            const quick = findChild(page, "wmQuickSearch_1");
            verify(quick);
            mouseMove(quick);
            tryCompare(quick, "hovered", true);
            mouseClick(quick);
            compare(querySpy.count, 1);
            compare(querySpy.signalArguments[0][0], "Sound");
            const item = findChild(page, "wmSuggested_0");
            verify(item);
            mouseClick(item);
            compare(apps.launches, 1);
            compare(launchSpy.count, 1);
            const top = findChild(page, "wmTopApp_0");
            verify(top);
            mouseClick(top);
            compare(apps.launches, 2);
            compare(launchSpy.count, 2);
        }
        function test_emptyAndNarrow() {
            page.suggestedModel = null;
            page.topAppsModel = null;
            tryCompare(findChild(page, "wmSearchSuggestions"), "count", 0);
            tryCompare(findChild(page, "wmSearchTopApps"), "count", 0);
            fixture.width = 300;
            verify(!page.twoColumns);
            verify(findChild(page, "wmQuickSearch_0").width > 0);
            fixture.width = 760;
            page.suggestedModel = apps;
            page.topAppsModel = apps;
        }
    }
}
