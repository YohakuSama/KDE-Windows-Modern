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
}
