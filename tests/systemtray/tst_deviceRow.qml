// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/components" as Components

Item {
    width: 360
    height: 240
    ListModel {
        id: mockActions
        property string defaultActionName: "eject"
        property string defaultActionText: "Eject"
        property string requested: ""
        function actionTriggered(name) { requested = name; }
    }
    Components.DeviceRow {
        id: row
        width: 320
        height: implicitHeight
        description: "USB drive"
        mounted: true
        actions: mockActions
    }
    TestCase {
        name: "DeviceRowNativeAction"
        when: windowShown
        function init() {
            mockActions.requested = "";
            row.present = true;
            row.busy = false;
            row.expanded = false;
        }
        function test_nativeDefault() {
            verify(row.hasDefault);
            verify(row.canOperate);
            row.triggerAction(row.defaultName);
            compare(mockActions.requested, "eject");
        }
        function test_busyAndRemoved() {
            row.expanded = true;
            row.busy = true;
            verify(!row.expanded);
            row.triggerAction(row.defaultName);
            compare(mockActions.requested, "");
            row.busy = false;
            row.present = false;
            row.triggerAction(row.defaultName);
            compare(mockActions.requested, "");
        }
    }
}
