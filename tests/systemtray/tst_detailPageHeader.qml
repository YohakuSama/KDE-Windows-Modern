// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/lib" as Lib

Item {
    width: 360
    height: 100
    ColumnLayout {
        anchors.fill: parent
        Lib.PageHeader {
            id: header
            title: "Bluetooth"
            showSwitch: true
            property int toggleRequests: 0
            property int backRequests: 0
            onSwitchToggled: { toggleRequests++; switchChecked = !switchChecked; }
            onBack: backRequests++
        }
        Item { Layout.fillHeight: true }
    }
    TestCase {
        name: "DetailPageHeaderAlignment"
        when: windowShown
        function test_centerAndRealActions() {
            const back = findChild(header, "wmPageBack");
            const title = findChild(header, "wmPageTitle");
            const radio = findChild(header, "wmPageSwitch");
            verify(back && title && radio);
            tryVerify(() => back.width > 0 && title.width > 0 && radio.width > 0);
            verify(Math.abs(back.y + back.height / 2 - (title.y + title.height / 2)) <= 1);
            verify(Math.abs(back.y + back.height / 2 - (radio.y + radio.height / 2)) <= 1);
            mouseClick(radio);
            compare(header.toggleRequests, 1);
            compare(header.switchChecked, true);
            mouseClick(back);
            compare(header.backRequests, 1);
        }
    }
}
