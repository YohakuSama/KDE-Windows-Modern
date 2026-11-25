// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/lib" as Lib

Item {
    width: 360
    height: 300
    ColumnLayout {
        anchors.fill: parent
        Lib.PageHeader {
            id: header
            title: "Bluetooth"
            showSwitch: true
            onSwitchToggled: switchChecked = !switchChecked
        }
        Item { Layout.fillHeight: true }
    }
    SignalSpy { id: toggled; target: header; signalName: "switchToggled" }
    SignalSpy { id: wentBack; target: header; signalName: "back" }
    SignalSpy { id: action; target: header; signalName: "actionTriggered" }
    TestCase {
        name: "DetailHeaderGeometry"
        when: windowShown
        function center(item) { return item.mapToItem(header, 0, item.height / 2).y; }
        function test_commonCenterlineAndSwitch() {
            header.showSwitch = true;
            header.showAction = false;
            header.switchChecked = false;
            const back = findChild(header, "wmDetailBack");
            const title = findChild(header, "wmDetailTitle");
            const sw = findChild(header, "wmDetailSwitch");
            const track = findChild(sw, "wmDetailSwitchTrack");
            verify(back && title && sw && track);
            tryVerify(() => back.width > 0 && sw.width > 0);
            verify(Math.abs(center(back) - center(title)) <= 1);
            verify(Math.abs(center(title) - center(track)) <= 1);
            compare(track.width, 40);
            compare(track.height, 20);
            toggled.clear();
            mouseClick(sw, sw.width / 2, sw.height / 2);
            compare(toggled.count, 1);
            tryCompare(header, "switchChecked", true);
            wentBack.clear();
            mouseClick(back, back.width / 2, back.height / 2);
            compare(wentBack.count, 1);
        }
        function test_conditionalAction() {
            header.showSwitch = false;
            header.showAction = true;
            header.actionText = "Clear all";
            const button = findChild(header, "wmDetailAction");
            tryCompare(button, "visible", true);
            action.clear();
            mouseClick(button, button.width / 2, button.height / 2);
            compare(action.count, 1);
            header.showAction = false;
            tryCompare(button, "visible", false);
        }
    }
}
