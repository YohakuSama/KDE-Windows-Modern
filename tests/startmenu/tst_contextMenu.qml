// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/components" as Start
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/code/startMenuMetrics.js" as Metrics
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/code/controlMetrics.js" as ControlMetrics

Item {
    id: host
    width: 420
    height: 300
    Start.ContextMenu { id: menu; anchors.fill: parent }
    ListModel {
        id: sourceModel
        ListElement { title: "First" }
        ListElement { title: "Second" }
    }
    SignalSpy { id: invoked; target: menu; signalName: "actionTriggered" }
    TestCase {
        name: "StartContextMenu"
        when: windowShown
        function init() { menu.close(); tryCompare(menu, "opened", false); invoked.clear(); }
        function test_keyboardSkipsSeparatorsAndDisabled() {
            menu.open([{text: "Open", actionId: "open"},
                {type: "separator"}, {text: "Disabled", actionId: "disabled", enabled: false},
                {text: "Remove", actionId: "remove", actionArgument: 0}], 10, 10, {index: 7});
            const popup = findChild(menu, "wmStartContextPopup");
            tryCompare(popup, "opened", true);
            compare(popup.contentItem.currentIndex, -1);
            keyClick(Qt.Key_Down);
            compare(popup.contentItem.currentIndex, 0);
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Return);
            tryCompare(menu, "opened", false);
            tryCompare(invoked, "count", 1);
            compare(invoked.signalArguments[0][0], "remove");
            compare(invoked.signalArguments[0][1], 0);
            compare(invoked.signalArguments[0][2].index, 7);
        }
        function test_neutralOpeningAndUpNavigation() {
            menu.open([{text: "Open", actionId: "open", icon: "document-open-symbolic"},
                {type: "separator"}, {text: "Remove", actionId: "remove"}], 10, 10, {});
            const popup = findChild(menu, "wmStartContextPopup");
            tryCompare(popup, "opened", true);
            compare(popup.contentItem.currentIndex, -1);
            tryVerify(() => popup.contentItem.itemAtIndex(0) !== null);
            const row = popup.contentItem.itemAtIndex(0);
            compare(row.height, menu.rowHeight);
            compare(Metrics.menuRowHeight, 32);
            compare(Metrics.menuRowRadius, ControlMetrics.controlCornerRadius);
            compare(Metrics.menuRadius, ControlMetrics.overlayCornerRadius);
            verify(menu.rowHeight >= Metrics.menuRowHeight);
            compare(row.background.radius, Metrics.menuRowRadius);
            const glyph = findChild(row, "wmStartActionGlyph");
            verify(glyph);
            tryCompare(glyph, "width", Metrics.menuGlyphSize);
            keyClick(Qt.Key_Up);
            compare(popup.contentItem.currentIndex, 2);
            keyClick(Qt.Key_Escape);
            tryCompare(menu, "opened", false);
            compare(invoked.count, 0);
        }
        function test_modelChangesDismissCapturedRow() {
            menu.open([{text: "Open", actionId: "open"}], 10, 10, {model: sourceModel, index: 0});
            tryCompare(menu, "opened", true);
            sourceModel.move(0, 1, 1);
            tryCompare(menu, "opened", false);
            compare(invoked.count, 0);
        }
        function test_largeMenuBoundedAndDismissible() {
            const actions = [];
            for (let i = 0; i < 30; ++i) actions.push({text: "Action " + i, actionId: "action" + i});
            menu.open(actions, 410, 290, {});
            const popup = findChild(menu, "wmStartContextPopup");
            tryCompare(popup, "opened", true);
            verify(popup.x >= Metrics.popupEdgeInset && popup.x + popup.width <= host.width - Metrics.popupEdgeInset);
            verify(popup.y >= Metrics.popupEdgeInset && popup.y + popup.height <= host.height - Metrics.popupEdgeInset);
            keyClick(Qt.Key_Escape);
            tryCompare(menu, "opened", false);
            compare(invoked.count, 0);
        }
        function test_outsideAndMouseSelection() {
            menu.open([{text: "Open", actionId: "open"}], 100, 60, {});
            const popup = findChild(menu, "wmStartContextPopup");
            tryCompare(popup, "opened", true);
            mouseClick(host, 10, 10);
            tryCompare(menu, "opened", false);
            compare(invoked.count, 0);
            menu.open([{text: "Open", actionId: "open"}], 100, 60, {});
            tryCompare(popup, "opened", true);
            const row = popup.contentItem.itemAtIndex(0);
            verify(row !== null);
            mouseClick(row, row.width / 2, row.height / 2);
            tryCompare(invoked, "count", 1);
            tryCompare(menu, "opened", false);
        }
    }
}
