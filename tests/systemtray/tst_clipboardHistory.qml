// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/components" as Components

Item {
    width: 360
    height: 440

    Components.ClipboardPage {
        id: page
        anchors.fill: parent
        emojiPickerEnabled: false
        historySource: Component {
            ListModel {
                property int starredCount: 0
                ListElement { uuid: "text-1"; display: "Actual clipboard text"; type: 2; decoration: ""; starred: false }
                ListElement { uuid: "image-1"; display: "Image"; type: 4; decoration: ""; starred: false }
            }
        }
        historyController: QtObject {
            property string selectedUuid: ""
            property int clearCalls: 0
            function moveToTop(uuid) { selectedUuid = uuid; }
            function remove(uuid) {
                for (let i = 0; i < page.historyModel.count; ++i) {
                    if (page.historyModel.get(i).uuid === uuid) {
                        page.historyModel.remove(i);
                        break;
                    }
                }
            }
            function clearHistory() {
                ++clearCalls;
                page.historyModel.clear();
            }
        }
    }
    SignalSpy { id: selection; target: page; signalName: "itemSelected" }
    TestCase {
        name: "ClipboardHistoryCards"
        when: windowShown
        function init() {
            // Let ListView dispose of old delegates before the next test.
            page.historyModel.clear();
            const list = findChild(page, "wmClipboardHistory");
            list.forceLayout();
            tryCompare(list, "count", 0);
            wait(0);
            page.historyModel.append({uuid: "text-1", display: "Actual clipboard text", type: 2, decoration: "", starred: false});
            page.historyModel.append({uuid: "image-1", display: "Image", type: 4, decoration: "", starred: false});
            list.forceLayout();
            tryCompare(list, "count", 2);
            tryVerify(() => list.visible && list.height > 184
                && list.itemAtIndex(0) && list.itemAtIndex(1)
                && list.itemAtIndex(0).width > 100);
            wait(50);
            page.historyModel.starredCount = 0;
            page.historyController.selectedUuid = "";
            page.historyController.clearCalls = 0;
            selection.clear();
        }
        function test_realRolesAndSelection() {
            const list = findChild(page, "wmClipboardHistory");
            tryCompare(list, "count", 2);
            tryVerify(() => list.itemAtIndex(0) && list.itemAtIndex(1));
            const textCard = list.itemAtIndex(0);
            const imageCard = list.itemAtIndex(1);
            compare(findChild(textCard, "wmClipboardText").text, "Actual clipboard text");
            compare(textCard.isImage, false);
            compare(imageCard.isImage, true);
            compare(findChild(imageCard, "wmClipboardPreview").visible, true);
            const target = findChild(textCard, "wmClipboardSelect");
            mouseClick(target, 20, target.height / 2);
            compare(page.historyController.selectedUuid, "text-1");
            compare(selection.count, 1);
            const imageTarget = findChild(imageCard, "wmClipboardSelect");
            mouseClick(imageTarget, 20, imageTarget.height / 2);
            compare(page.historyController.selectedUuid, "image-1");
            compare(selection.count, 2);
        }
        function test_pinAndConditionalClear() {
            const list = findChild(page, "wmClipboardHistory");
            tryVerify(() => list.itemAtIndex(0));
            const card = list.itemAtIndex(0);
            const pin = findChild(card, "wmClipboardPin");
            verify(pin.visible);
            mouseClick(pin, pin.width / 2, pin.height / 2);
            tryVerify(() => page.historyModel.get(0).starred === true);
            tryVerify(() => list.itemAtIndex(0)?.pinned === true);
            const clear = findChild(page, "wmClipboardClearAll");
            page.historyModel.starredCount = 2;
            tryCompare(clear, "visible", false);
            page.historyModel.starredCount = 0;
            tryCompare(clear, "visible", true);
            mouseClick(clear, clear.width / 2, clear.height / 2);
            compare(page.historyController.clearCalls, 1);
            tryCompare(clear, "visible", false);
            tryCompare(findChild(page, "wmClipboardEmpty"), "visible", true);
        }
    }
}
