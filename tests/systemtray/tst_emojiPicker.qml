// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/components" as Components

Item {
    width: 360
    height: 350
    Components.EmojiPicker { id: picker; anchors.fill: parent }
    TestCase {
        name: "EmojiPickerCategories"
        when: windowShown
        function test_nativeEmojiAndLocalCategories() {
            picker.mode = "emoji";
            const grid = findChild(picker, "wmEmojiGrid");
            tryVerify(() => grid.count > 0);
            picker.mode = "symbols";
            const local = findChild(picker, "wmSymbolGrid");
            tryVerify(() => local.visible && local.count > 0);
            const search = findChild(picker, "wmEmojiSearch");
            const clear = findChild(picker, "wmEmojiSearchClear");
            verify(clear !== null);
            compare(clear.visible, false);
            search.text = "€";
            tryCompare(clear, "visible", true);
            tryCompare(local, "count", 1);
            mouseClick(clear, clear.width / 2, clear.height / 2);
            tryCompare(search, "text", "");
            search.text = "€";
            tryCompare(local, "count", 1);
            picker.mode = "kaomoji";
            tryCompare(search, "text", "");
            tryVerify(() => local.count > 0);
            picker.mode = "emoji";
            tryCompare(grid, "visible", true);
        }
    }
}
