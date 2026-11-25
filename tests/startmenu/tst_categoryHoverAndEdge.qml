// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest

Item {
    id: fixture
    width: 680
    height: 600
    ListModel {
        id: catalog
        property int launchedSourceRow: -1
        // Return false so this isolated UI test does not try to close a live shell.
        function trigger(row, action, argument) {
            launchedSourceRow = row;
            return false;
        }
        ListElement { display: "Dolphin"; favoriteId: "applications:org.kde.dolphin.desktop" }
        ListElement { display: "Kate"; favoriteId: "applications:org.kde.kate.desktop" }
        ListElement { display: "Firefox"; favoriteId: "applications:firefox.desktop" }
        ListElement { display: "Calculator"; favoriteId: "applications:org.kde.kcalc.desktop" }
    }
    TestCase {
        name: "StartCategoryHoverAndEdge"
        when: windowShown
        function test_hoverLaunchAndSidebarGeometry() {
            const component = Qt.createComponent("../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/pages/AllAppsPage.qml");
            tryVerify(() => component.status !== Component.Loading);
            verify(component.status === Component.Ready, component.errorString());
            const page = component.createObject(fixture, {
                width: 560, height: 500, categoryMode: true, flatModel: catalog,
                scrollbarEdgeOffset: 24
            });
            verify(page !== null);
            tryCompare(page.allAppsList, "count", 2);
            const bar = findChild(page, "wmStartCategoryScrollBar");
            verify(bar !== null);
            tryCompare(page.allAppsList, "contentColumnWidth", page.width);
            tryVerify(() => Math.abs(bar.mapToItem(page, bar.width, 0).x - (page.width + 24)) < 1);
            let slot;
            tryVerify(() => {
                slot = findChild(page, "wmStartCategorySlot_0_0");
                return slot && slot.hasApp && slot.width > 0;
            });
            verify(slot.appName.length > 0);
            mouseMove(slot, slot.width / 2, slot.height / 2);
            tryCompare(slot, "hovered", true);
            mouseClick(slot, slot.width / 2, slot.height / 2);
            tryCompare(catalog, "launchedSourceRow", slot.entry.index);

            const categoryLabel = findChild(page, "wmStartCategoryLabel");
            verify(categoryLabel);
            mouseMove(categoryLabel, categoryLabel.width / 2, categoryLabel.height / 2);
            tryCompare(categoryLabel, "hovered", true);
            mouseClick(categoryLabel, categoryLabel.width / 2, categoryLabel.height / 2);
            tryCompare(page, "inCategory", true);
            const overlay = findChild(page, "wmStartCategoryOverlay");
            verify(overlay);
            tryCompare(overlay, "opacity", 1);
            page.backToCategories();
            tryCompare(page, "inCategory", false);

            let contextRow = -1;
            page.appContextMenuRequested.connect((entry, x, y) => { contextRow = entry.index; });
            mouseClick(slot, slot.width / 2, slot.height / 2, Qt.RightButton);
            compare(contextRow, slot.entry.index);
            page.destroy();
        }
    }
}
