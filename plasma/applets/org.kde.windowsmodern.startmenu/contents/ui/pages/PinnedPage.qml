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

ColumnLayout {
    id: pinnedPage

    spacing: Kirigami.Units.largeSpacing

    property alias favoritesList: favoritesListView
    property int columns: width >= 690 ? 8 : (width >= 430 ? 6 : 4)

    signal showAllAppsRequested
    signal keyNavUpFromList

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
        if (favoritesListView.currentIndex >= 0 && favoritesListView.model) {
            favoritesListView.model.trigger(favoritesListView.currentIndex, "", null);
            root.closeMenu();
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
            buttonHeight: 25
            flat: true
            iconName: "go-next"
            text: i18n("All apps")
            Layout.rightMargin: Kirigami.Units.mediumSpacing
            onClicked: pinnedPage.showAllAppsRequested()
        }
    }

    // Responsive pinned grid, limited to a few visible rows. Extra pins
    // remain scrollable and reorderable without affecting the All list.
    GridView {
        id: favoritesListView
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(Math.max(1, Plasmoid.configuration.numberRows),
            Math.ceil(count / pinnedPage.columns)) * cellHeight
        visible: count > 0
        clip: true
        interactive: contentHeight > height
        cellWidth: Math.max(1, Math.floor(width / pinnedPage.columns))
        cellHeight: Math.max(80, Kirigami.Units.iconSizes.medium + 2 * Kirigami.Units.gridUnit + 12)
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: -1

        // Drag-reorder tracking.  draggingIndex is the index currently
        // being dragged (or -1); dropTargetIndex is where it would land
        // if released (or -1).  Delegates read these to show the drop
        // indicator and lift the dragged row.
        property int draggingIndex: -1
        property int dropTargetIndex: -1

        PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar {
            policy: PlasmaComponents3.ScrollBar.AsNeeded
        }

        delegate: ListItemDelegate {
            gridMode: true
            iconSize: Kirigami.Units.iconSizes.medium
            dragEnabled: true
        }

        highlightMoveDuration: 0
        keyNavigationEnabled: true

        Keys.onReturnPressed: pinnedPage.activateCurrent()
        Keys.onEnterPressed: pinnedPage.activateCurrent()

        Keys.onUpPressed: event => {
            if (currentIndex < pinnedPage.columns) {
                event.accepted = true;
                pinnedPage.keyNavUpFromList();
            }
        }
    }
    PlasmaComponents3.Label {
        Layout.fillWidth: true
        text: i18n("No pinned apps")
        color: Kirigami.Theme.disabledTextColor
        visible: favoritesListView.count === 0
    }

}
