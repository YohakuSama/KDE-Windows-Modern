// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/components" as Components
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/js/controlMetrics.js" as ControlMetrics

Item {
    function i18n(message) { return message; }
    width: 360
    height: 260

    ListModel {
        id: mockActions
        property string defaultActionName: "MountAndOpen"
        property string defaultActionText: "Safely remove"
        property string defaultActionIcon: "media-eject"
        property string requested: ""
        function actionTriggered(name) { requested = name; }
        // ActionsControl does not include its default action in rowCount().
        ListElement { Name: "open"; Text: "Open"; Icon: "document-open-folder" }
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

        function test_sharedDetailRowRadius() {
            compare(row.radius, ControlMetrics.controlCornerRadius);
        }

        function test_nativeDefaultAction() {
            verify(row.hasDefault);
            verify(row.canOperate);
            const button = findChild(row, "wmDeviceDefaultAction");
            tryVerify(() => button && button.visible && button.enabled);
            mouseClick(button, button.width / 2, button.height / 2);
            compare(mockActions.requested, "MountAndOpen");
        }

        function test_moreActionsUseNativeDispatcher() {
            compare(row.additionalActionCount, 1);
            verify(row.hasOtherActions);
            const more = findChild(row, "wmDeviceMoreActions");
            tryVerify(() => more && more.visible);
            mouseClick(more, more.width / 2, more.height / 2);
            tryCompare(row, "expanded", true);
            tryVerify(() => {
                const openButton = findChild(row, "wmDeviceOtherAction_open");
                return openButton && openButton.visible;
            });
            const open = findChild(row, "wmDeviceOtherAction_open");
            mouseClick(open, open.width / 2, open.height / 2);
            compare(mockActions.requested, "open");
        }

        function test_emptyAdditionalActionsKeepsDefault() {
            mockActions.clear();
            tryCompare(row, "additionalActionCount", 0);
            verify(!row.hasOtherActions);
            verify(row.hasDefault);
            mockActions.append({Name: "open", Text: "Open", Icon: "document-open-folder"});
            tryCompare(row, "additionalActionCount", 1);
        }

        function test_busyAndRemovedDevicesCannotBeOperated() {
            row.expanded = true;
            row.busy = true;
            tryCompare(row, "expanded", false);
            verify(!row.canOperate);
            const button = findChild(row, "wmDeviceDefaultAction");
            tryCompare(button, "enabled", false);
            row.triggerAction("MountAndOpen");
            compare(mockActions.requested, "");

            row.busy = false;
            row.present = false;
            verify(!row.canOperate);
            tryCompare(button, "visible", false);
            row.triggerAction("MountAndOpen");
            compare(mockActions.requested, "");
        }
    }
}
