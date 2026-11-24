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
        if (allAppsListView.currentIndex >= 0 && allAppsListView.model) {
            allAppsListView.model.trigger(allAppsListView.currentIndex, "", null);
            root.closeMenu();
        }
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
        header: allAppsPage.homeHeader
        headerPositioning: ListView.InlineHeader

        PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar {
            policy: PlasmaComponents3.ScrollBar.AsNeeded
        }

        delegate: ListItemDelegate {
            iconSize: Kirigami.Units.iconSizes.smallMedium
        }

        highlightMoveDuration: 0

        Keys.onUpPressed: event => {
            if (currentIndex <= 0) {
                event.accepted = true;
                allAppsListView.positionViewAtBeginning();
                allAppsPage.keyNavUpFromList();
            }
        }
    }
}
