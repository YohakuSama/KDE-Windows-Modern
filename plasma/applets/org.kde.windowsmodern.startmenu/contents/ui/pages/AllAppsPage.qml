/***************************************************************************
 *   License: GPL-3.0-or-later
 *   Author: Jeysef
 *
 *   Scrollable All list with an inline Pinned/Recent header. Keep the
 *   existing sorted Kicker model and ListItemDelegate.
 ***************************************************************************/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

import "../components"

ColumnLayout {
    id: allAppsPage

    spacing: Kirigami.Units.largeSpacing

    property alias allAppsList: allAppsListView
    property Component homeHeader: null
    property var flatModel: null
    property var categoryModel: null
    property bool categoryMode: false
    property var categoryChild: null
    property string categoryTitle: ""
    property int categoryRow: 0
    readonly property bool inCategory: categoryMode && categoryChild !== null

    function resetCategory() {
        categoryChild = null;
        categoryTitle = "";
        categoryRow = 0;
    }

    onCategoryModeChanged: resetCategory()

    function focusFirstApp() {
        scrollToAll();
        tryActivate(0);
    }

    function backToCategories() {
        const row = categoryRow;
        resetCategory();
        Qt.callLater(function() {
            allAppsListView.positionViewAtIndex(row, ListView.Contain);
            tryActivate(row);
        });
    }

    function activateRow(row) {
        const source = allAppsListView.model;
        if (!source || row < 0 || row >= allAppsListView.count)
            return;
        if (categoryMode && !inCategory) {
            const child = source.modelForRow(row);
            if (child) {
                categoryRow = row;
                categoryTitle = source.labelForRow(row);
                categoryChild = child;
                Qt.callLater(focusFirstApp);
                return;
            }
        }
        if (source.trigger(row, "", null))
            root.closeMenu();
    }

    function scrollToAll() {
        if (allAppsListView.count > 0)
            allAppsListView.positionViewAtIndex(0, ListView.Beginning);
    }

    signal backRequested
    signal keyNavUpFromList

    function tryActivate(row) {
        if (allAppsListView.count > 0) {
            allAppsListView.currentIndex = Math.min(row, allAppsListView.count - 1);
            allAppsListView.forceActiveFocus();
        }
    }

    function navigateUp() {
        if (allAppsListView.count > 0) {
            allAppsListView.currentIndex = Math.max(0, allAppsListView.currentIndex - 1);
        }
    }

    function navigateDown() {
        if (allAppsListView.count > 0) {
            allAppsListView.currentIndex = Math.min(allAppsListView.count - 1, allAppsListView.currentIndex + 1);
        }
    }

    function activateCurrent() {
        activateRow(allAppsListView.currentIndex);
    }

    // ── All apps vertical list ───────────────────────────────────────────
    ListView {
        id: allAppsListView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        interactive: true
        spacing: Kirigami.Units.smallSpacing / 2
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: -1
        model: allAppsPage.categoryMode
            ? (allAppsPage.categoryChild || allAppsPage.categoryModel)
            : allAppsPage.flatModel
        function activateRow(row) { allAppsPage.activateRow(row); }
        header: allAppsPage.homeHeader
        headerPositioning: ListView.InlineHeader

        PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar {
            policy: PlasmaComponents3.ScrollBar.AsNeeded
        }

        delegate: ListItemDelegate {
            iconSize: Kirigami.Units.iconSizes.smallMedium
        }

        highlightMoveDuration: 0

        Keys.onReturnPressed: allAppsPage.activateCurrent()
        Keys.onEnterPressed: allAppsPage.activateCurrent()

        Keys.onLeftPressed: event => {
            if (allAppsPage.inCategory) {
                event.accepted = true;
                allAppsPage.backToCategories();
            }
        }
        Keys.onUpPressed: event => {
            if (currentIndex <= 0) {
                event.accepted = true;
                allAppsListView.positionViewAtBeginning();
                allAppsPage.keyNavUpFromList();
            }
        }
    }
}
