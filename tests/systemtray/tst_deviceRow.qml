// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/components" as Components

Item {
    function i18n(message) { return message; }
    width: 360
    height: 260

    ListModel {
        id: mockActions
        property string defaultActionName: "eject"
        property string defaultActionText: "Eject"
        property string requested: ""
        function actionTriggered(name) { requested = name; }
        ListElement { Name: "eject"; Text: "Eject" }
        ListElement { Name: "open"; Text: "Open" }
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

        function test_nativeDefaultAction() {
            verify(row.hasDefault);
            verify(row.canOperate);
            const button = findChild(row, "wmDeviceDefaultAction");
            tryVerify(() => button && button.visible && button.enabled);
            mouseClick(button, button.width / 2, button.height / 2);
            compare(mockActions.requested, "eject");
        }

        function test_moreActionsUseNativeDispatcher() {
            const more = findChild(row, "wmDeviceMoreActions");
            tryVerify(() => more && more.visible);
            mouseClick(more, more.width / 2, more.height / 2);
            tryVerify(() => {
                const buttons = findChildren(row, "wmDeviceOtherAction");
                return buttons.some(button => button.visible && button.text === "Open");
            });
            const open = findChildren(row, "wmDeviceOtherAction").find(button => button.visible && button.text === "Open");
            mouseClick(open, open.width / 2, open.height / 2);
            compare(mockActions.requested, "open");
        }

        function test_busyAndRemovedDevicesCannotBeOperated() {
            row.expanded = true;
            row.busy = true;
            tryCompare(row, "expanded", false);
            verify(!row.canOperate);
            const button = findChild(row, "wmDeviceDefaultAction");
            tryCompare(button, "enabled", false);
            row.triggerAction("eject");
            compare(mockActions.requested, "");

            row.busy = false;
            row.present = false;
            verify(!row.canOperate);
            tryCompare(button, "visible", false);
            row.triggerAction("eject");
            compare(mockActions.requested, "");
        }
    }
}
