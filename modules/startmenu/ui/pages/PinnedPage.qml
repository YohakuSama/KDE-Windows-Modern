/***************************************************************************
 *   License: GPL-3.0-or-later
 *   Author: Jeysef
 *
 *   Pinned application grid using the same Kicker favorites model and
 *   shared delegate as All. The header shortcut scrolls to installed apps.
 ***************************************************************************/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

import "../components"
import "../code/startMenuMetrics.js" as Metrics

ColumnLayout {
    id: pinnedPage

    spacing: 8

    property alias favoritesList: favoritesListView
    property int columns: width >= 8 * Metrics.gridCellWidth ? 8 : (width >= 430 ? 6 : (width >= 320 ? 4 : 3))
    readonly property bool showAllPinned: Plasmoid.configuration.showAllPinned
    readonly property int previewRows: Math.max(1, Plasmoid.configuration.numberRows)

    signal showAllAppsRequested
    signal keyNavUpFromList
    signal applicationActivated
    signal appContextMenuRequested(var entry, int row, real x, real y)

    function tryActivate(row) {
        if (favoritesListView.count > 0) {
            favoritesListView.currentIndex = Math.min(row, favoritesListView.count - 1);
            favoritesListView.forceActiveFocus();
        }
    }

    function navigateUp() {
        if (favoritesListView.count > 0) {
            favoritesListView.currentIndex = Math.max(0, favoritesListView.currentIndex - pinnedPage.columns);
        }
    }

    function navigateDown() {
        if (favoritesListView.count > 0) {
            favoritesListView.currentIndex = Math.min(favoritesListView.count - 1,
                favoritesListView.currentIndex < 0 ? 0 : favoritesListView.currentIndex + pinnedPage.columns);
        }
    }

    function activateCurrent() {
        if (favoritesListView.currentIndex >= 0) {
            favoritesListView.activateRow(favoritesListView.currentIndex);
        }
    }

    // ── Header row: "Pinned" + spacer + "All apps >" ─────────────────────
    RowLayout {
        id: headerRow
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.Label {
            text: i18n("Pinned")
            color: Kirigami.Theme.textColor
            font.pointSize: Kirigami.Theme.defaultFont.pointSize
            font.weight: Font.DemiBold
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        AToolButton {
            visible: favoritesListView.count > pinnedPage.columns * pinnedPage.previewRows
            flat: true
            linkStyle: true
            iconName: pinnedPage.showAllPinned ? "go-up" : "go-down"
            text: pinnedPage.showAllPinned ? i18n("Show less") : i18n("Show all")
            onClicked: {
                Plasmoid.configuration.showAllPinned = !pinnedPage.showAllPinned;
                if (!pinnedPage.showAllPinned) {
                    favoritesListView.currentIndex = -1;
                    favoritesListView.positionViewAtBeginning();
                }
            }
        }
    }

    // Extra pins expand into the shared home list, avoiding a second
    // nested scroll area. The original Kicker drag-to-reorder stays intact.
    GridView {
        id: favoritesListView
        Layout.fillWidth: true
        Layout.preferredHeight: (pinnedPage.showAllPinned ? Math.ceil(count / pinnedPage.columns)
            : Math.min(pinnedPage.previewRows, Math.ceil(count / pinnedPage.columns))) * cellHeight
        visible: count > 0
        clip: true
        interactive: false
        layoutDirection: favoritesListView.LayoutMirroring.enabled ? Qt.RightToLeft : Qt.LeftToRight
        cellWidth: Math.max(1, Math.floor(width / pinnedPage.columns))
        cellHeight: Metrics.gridCellHeight
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: -1

        // Drag-reorder tracking.  draggingIndex is the index currently
        // being dragged (or -1); dropTargetIndex is where it would land
        // if released (or -1).  Delegates read these to show the drop
        // indicator and lift the dragged row.
        property int draggingIndex: -1
        property int dropTargetIndex: -1

        function activateRow(row) {
            if (row < 0 || row >= count || !model || typeof model.trigger !== "function")
                return;
            currentIndex = row;
            if (model.trigger(row, "", null))
                pinnedPage.applicationActivated();
        }

        delegate: ListItemDelegate {
            id: pinnedEntry
            gridMode: true
            iconSize: Metrics.gridAppIconSize
            dragEnabled: true
            contextHandler: (data, row, x, y) => {
                const pos = pinnedEntry.mapToItem(pinnedPage, x, y);
                pinnedPage.appContextMenuRequested(data, row, pos.x, pos.y);
            }
        }

        highlightMoveDuration: 0
        keyNavigationEnabled: true

        Keys.onReturnPressed: pinnedPage.activateCurrent()
        Keys.onEnterPressed: pinnedPage.activateCurrent()

        onCurrentIndexChanged: {
            if (currentIndex >= pinnedPage.columns * pinnedPage.previewRows)
                Plasmoid.configuration.showAllPinned = true;
        }

        Keys.onUpPressed: event => {
            if (currentIndex < pinnedPage.columns) {
                event.accepted = true;
                pinnedPage.keyNavUpFromList();
            }
        }
    }

}
