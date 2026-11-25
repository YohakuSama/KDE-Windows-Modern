// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/components" as Components

Item {
    id: fixture
    width: 360
    height: 480

    ListModel { id: fixtureRows }
    QtObject {
        id: mockHistory
        property int sourceCount: fixtureRows.count
        property int starredCount: 0
        property bool starredOnly: false
        property string selectedUuid: ""
        property string removedUuid: ""
        property int clearRequests: 0
        function moveToTop(uuid) { selectedUuid = uuid; }
        function remove(uuid) { removedUuid = uuid; }
        function clearHistory() { clearRequests++; }
    }

    Components.ClipboardPage {
        id: clipboard
        anchors.fill: parent
        history: mockHistory
        historyRows: fixtureRows
        property int dismissCount: 0
        onDismissed: dismissCount++
    }

    TestCase {
        name: "NativeClipboardCardActions"
        when: windowShown
        function init() {
            fixtureRows.clear();
            mockHistory.selectedUuid = "";
            mockHistory.removedUuid = "";
            mockHistory.clearRequests = 0;
            clipboard.dismissCount = 0;
        }
        function test_emptyAndRealMimeCards() {
            const list = findChild(clipboard, "wmClipboardHistory");
            const clear = findChild(clipboard, "wmClipboardClearAll");
            const empty = findChild(clipboard, "wmClipboardEmpty");
            tryCompare(clear, "visible", false);
            tryCompare(empty, "visible", true);
            fixtureRows.append({uuid:"native-text", display:"Example text", decoration:"", starred:false});
            fixtureRows.append({uuid:"native-image", display:"640x480", decoration:"file:///nonexistent-test-image.png", starred:false});
            tryCompare(list, "count", 2);
            tryCompare(empty, "visible", false);
            tryCompare(clear, "visible", true);
            tryVerify(() => list.itemAtIndex(0) && list.itemAtIndex(1));
            const textCard = list.itemAtIndex(0);
            const imageCard = list.itemAtIndex(1);
            compare(textCard.displayText, "Example text");
            verify(!textCard.hasImage);
            verify(imageCard.hasImage);
            mouseClick(textCard, 20, 25);
            compare(mockHistory.selectedUuid, "native-text");
            mouseClick(imageCard, 20, 25);
            compare(mockHistory.selectedUuid, "native-image");
            compare(clipboard.dismissCount, 2);
            mouseClick(findChild(textCard, "wmClipboardPin"));
            tryCompare(textCard, "pinned", true);
            mouseClick(findChild(imageCard, "wmClipboardRemove"));
            compare(mockHistory.removedUuid, "native-image");
            mouseClick(clear);
            compare(mockHistory.clearRequests, 1);
        }
    }
}
