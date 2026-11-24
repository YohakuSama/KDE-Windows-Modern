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
        readonly property int scrollGutter: 14
        readonly property real contentColumnWidth: Math.max(1, width - scrollGutter)
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: -1
        model: allAppsPage.categoryMode
            ? (allAppsPage.categoryChild || allAppsPage.categoryModel)
            : allAppsPage.flatModel
        function activateRow(row) { allAppsPage.activateRow(row); }
        header: allAppsPage.homeHeader
        headerPositioning: ListView.InlineHeader

        PlasmaComponents3.ScrollBar.vertical: StartScrollBar {}
        StartWheelHandler {
            view: allAppsListView
            rowHeight: Math.floor(Kirigami.Units.gridUnit * 1.8) + allAppsListView.spacing
        }

        delegate: ListItemDelegate {
            iconSize: Kirigami.Units.iconSizes.smallMedium
        }

        highlightMoveDuration: 0

        Keys.onReturnPressed: allAppsPage.activateCurrent()
        Keys.onEnterPressed: allAppsPage.activateCurrent()
        // Qt Quick Keys has no Home/End-specific signals. Use its generic
        // pressed handler so the entire applet can load on Plasma 6.
        Keys.onPressed: event => {
            if (count <= 0) return;
            if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
                currentIndex = event.key === Qt.Key_Home ? 0 : count - 1;
                positionViewAtIndex(currentIndex, event.key === Qt.Key_Home ? ListView.Beginning : ListView.End);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
                const step = Math.max(1, Math.floor(height / (Math.floor(Kirigami.Units.gridUnit * 1.8) + spacing)));
                currentIndex = Math.max(0, Math.min(count - 1,
                    Math.max(0, currentIndex) + (event.key === Qt.Key_PageUp ? -step : step)));
                positionViewAtIndex(currentIndex, ListView.Contain);
                event.accepted = true;
            }
        }

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
