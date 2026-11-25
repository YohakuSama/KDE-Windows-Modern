// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/components" as Start

Item {
    width: 560
    height: 360

    Start.FluentViewSelector {
        id: selector
        objectName: "wmViewSelector"
        x: 40
        y: 40
        width: implicitWidth
        choices: ["List", "Grid", "Category"]
        labelFormat: "View: %1"
        currentIndex: 0
    }

    TestCase {
        name: "StartViewSelector"
        when: windowShown

        function test_geometryStableAcrossSelection() {
            const initialWidth = selector.implicitWidth;
            for (let index = 0; index < selector.count; ++index) {
                selector.currentIndex = index;
                compare(selector.implicitWidth, initialWidth);
            }
            verify(selector.implicitHeight >= 32);
            selector.choices = ["列表", "网格", "按类别分组"];
            selector.labelFormat = "视图：%1";
            selector.currentIndex = 2;
            tryCompare(selector, "displayText", "视图：按类别分组");
            verify(selector.implicitWidth > 0);
            const label = findChild(selector, "wmViewSelectorText");
            verify(label !== null && label.visible);
            tryVerify(() => label.width >= label.implicitWidth);
            selector.labelFormat = "%1";
            tryCompare(label, "text", "按类别分组");
            tryVerify(() => label.width >= label.implicitWidth);
        }

        function test_popup() {
            selector.choices = ["List", "Grid", "Category"];
            selector.labelFormat = "View: %1";
            selector.currentIndex = 0;
            selector.popup.open();
            tryCompare(selector.popup, "visible", true);
            compare(selector.popup.width, selector.width);
            verify(selector.popup.height >= 3 * selector.rowHeight);
            selector.popup.close();
            tryCompare(selector.popup, "visible", false);
        }
    }
}
