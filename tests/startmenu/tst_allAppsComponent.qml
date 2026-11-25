// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest

TestCase {
    name: "StartAllAppsComponent"
    function test_loadAllAppsPage() {
        const component = Qt.createComponent("../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/pages/AllAppsPage.qml");
        tryVerify(() => component.status !== Component.Loading);
        verify(component.status === Component.Ready, component.errorString());
    }

    function test_responsiveViewColumns() {
        const component = Qt.createComponent("../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/pages/AllAppsPage.qml");
        tryVerify(() => component.status !== Component.Loading);
        verify(component.status === Component.Ready, component.errorString());
        const page = component.createObject(null, {width: 500, height: 600, categoryMode: true});
        verify(page !== null);
        tryCompare(page.allAppsList, "columns", 3);
        page.width = 760;
        tryCompare(page.allAppsList, "columns", 4);
        page.categoryMode = false;
        tryCompare(page.allAppsList, "columns", 1);
        page.gridMode = true;
        tryCompare(page.allAppsList, "columns", 6);
        page.flatModel = 12;
        tryCompare(page.allAppsList, "count", 12);
        page.showAllSection = false;
        tryCompare(page.allAppsList, "count", 0);
        page.destroy();
    }
}
