// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/code/controlMetrics.js" as ControlMetrics
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/code/startMenuMetrics.js" as Metrics

TestCase {
    name: "StartAllAppsComponent"
    ListModel {
        id: catalogApps
        property int triggeredRow: -1
        function trigger(row, actionId, argument) {
            triggeredRow = row;
            return true;
        }
        ListElement { display: "Dolphin"; favoriteId: "applications:org.kde.dolphin.desktop" }
        ListElement { display: "Kate"; favoriteId: "applications:org.kde.kate.desktop" }
        ListElement { display: "Firefox"; favoriteId: "applications:firefox.desktop" }
        ListElement { display: "Calculator"; favoriteId: "applications:org.kde.kcalc.desktop" }
    }

    function test_categoryOverlayUsesRealApps() {
        const component = Qt.createComponent("../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/pages/AllAppsPage.qml");
        tryVerify(() => component.status !== Component.Loading);
        verify(component.status === Component.Ready, component.errorString());
        const page = component.createObject(null, {width: 620, height: 600, categoryMode: true, flatModel: catalogApps});
        verify(page !== null);
        tryCompare(page.allAppsList, "count", 2);
        tryVerify(() => !!findChild(page, "wmStartCategoryCardSurface"));
        compare(findChild(page, "wmStartCategoryCardSurface").radius, ControlMetrics.cardSurfaceRadius);
        page.activateRow(0);
        tryCompare(page, "inCategory", true);
        const categorySurface = findChild(page, "wmStartCategorySurface");
        verify(categorySurface);
        compare(categorySurface.radius, ControlMetrics.cardSurfaceRadius);
        compare(page.categoryChild.length, 3);
        compare(page.categoryKey, "productivity");
        const grid = findChild(page, "wmStartCategoryGrid");
        verify(grid !== null);
        compare(grid.cellHeight, Metrics.gridCellHeight);
        tryCompare(grid, "count", 3);
        tryCompare(grid, "columns", 4);
        page.backToCategories();
        tryCompare(page, "inCategory", false);
        page.destroy();
    }

    function test_sharedControlRadii() {
        const buttonComponent = Qt.createComponent("../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/components/AToolButton.qml");
        tryVerify(() => buttonComponent.status !== Component.Loading);
        verify(buttonComponent.status === Component.Ready, buttonComponent.errorString());
        const button = buttonComponent.createObject(null, {width: 180, height: 32});
        verify(button !== null);
        compare(button.radius, ControlMetrics.controlCornerRadius);

        const rowComponent = Qt.createComponent("../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/components/ListItemDelegate.qml");
        tryVerify(() => rowComponent.status !== Component.Loading);
        verify(rowComponent.status === Component.Ready, rowComponent.errorString());
        const row = rowComponent.createObject(null, {width: 180, height: 40});
        verify(row !== null);
        const hover = findChild(row, "wmStartListItemHoverBackground");
        const focus = findChild(row, "wmStartListItemFocusBackground");
        verify(hover !== null);
        verify(focus !== null);
        compare(hover.radius, ControlMetrics.controlCornerRadius);
        compare(focus.radius, ControlMetrics.controlCornerRadius);
        button.destroy();
        row.destroy();
    }

    function test_loadAllAppsPage() {
        const component = Qt.createComponent("../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/pages/AllAppsPage.qml");
        tryVerify(() => component.status !== Component.Loading);
        verify(component.status === Component.Ready, component.errorString());
    }

    function test_responsiveViewColumns() {
        const component = Qt.createComponent("../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/pages/AllAppsPage.qml");
        tryVerify(() => component.status !== Component.Loading);
        verify(component.status === Component.Ready, component.errorString());
        const page = component.createObject(null, {width: 500, height: 600, categoryMode: true});
        verify(page !== null);
        tryCompare(page.allAppsList, "columns", 3);
        page.width = 760;
        tryCompare(page.allAppsList, "columns", 4);
        page.categoryMode = false;
        tryCompare(page.allAppsList, "columns", 1);
        page.gridMode = true;
        tryCompare(page.allAppsList, "columns", 6);
        page.flatModel = 12;
        tryCompare(page.allAppsList, "count", 12);
        page.showAllSection = false;
        tryCompare(page.allAppsList, "count", 0);
        page.destroy();
    }

    function test_explicitSignalsWithoutOuterShellScope() {
        const pinnedComponent = Qt.createComponent("../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/pages/PinnedPage.qml");
        tryVerify(() => pinnedComponent.status !== Component.Loading);
        verify(pinnedComponent.status === Component.Ready, pinnedComponent.errorString());
        const pinned = pinnedComponent.createObject(null, {width: 480, height: 240});
        verify(pinned !== null);
        pinned.favoritesList.model = catalogApps;
        let activatedCount = 0;
        let contextRow = -1;
        pinned.applicationActivated.connect(() => { activatedCount++; });
        pinned.appContextMenuRequested.connect((entry, row) => { contextRow = row; });
        catalogApps.triggeredRow = -1;
        pinned.favoritesList.activateRow(1);
        compare(catalogApps.triggeredRow, 1);
        compare(activatedCount, 1);
        pinned.favoritesList.forceLayout();
        tryVerify(() => pinned.favoritesList.itemAtIndex(0) !== null);
        const firstTile = pinned.favoritesList.itemAtIndex(0);
        verify(firstTile !== null);
        firstTile.openContextMenu(4, 4);
        compare(contextRow, 0);
        pinned.destroy();
    }
}
