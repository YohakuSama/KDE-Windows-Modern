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
    property bool showAllSection: true
    property bool categoryMode: false
    property bool gridMode: false
    readonly property bool showCategoryCards: categoryMode
    readonly property var activeView: inCategory ? categoryGrid : allAppsListView
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
    onShowAllSectionChanged: if (!showAllSection) resetCategory()

    function focusFirstApp() {
        scrollToAll();
        tryActivate(0);
    }

    function backToCategories() {
        const row = categoryRow;
        resetCategory();
        Qt.callLater(function() {
            allAppsListView.positionViewAtIndex(row, GridView.Contain);
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
                Qt.callLater(function() {
                    categoryGrid.currentIndex = -1;
                    categoryGrid.positionViewAtBeginning();
                    categoryGrid.forceActiveFocus();
                });
                return;
            }
        }
        if (source.trigger(row, "", null))
            root.closeMenu();
    }

    function scrollToAll() {
        if (allAppsListView.count > 0)
            allAppsListView.positionViewAtIndex(0, GridView.Beginning);
        else
            allAppsListView.positionViewAtBeginning();
    }

    signal backRequested
    signal keyNavUpFromList

    function tryActivate(row) {
        if (activeView.count > 0) {
            activeView.currentIndex = Math.min(row, activeView.count - 1);
            activeView.forceActiveFocus();
        }
    }

    function navigateUp() {
        if (activeView.count > 0)
            activeView.currentIndex = Math.max(0, activeView.currentIndex - activeView.columns);
    }

    function navigateDown() {
        if (activeView.count > 0)
            activeView.currentIndex = Math.min(activeView.count - 1, activeView.currentIndex < 0 ? 0 : activeView.currentIndex + activeView.columns);
    }

    function activateCurrent() {
        activeView.activateRow(Math.max(0, activeView.currentIndex));
    }

    // A single native scroller for all three views and the inline home header.
    GridView {
        id: allAppsListView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        interactive: !allAppsPage.inCategory
        readonly property int scrollGutter: 18
        readonly property real contentColumnWidth: Math.max(1, width - scrollGutter)
        readonly property int columns: allAppsPage.showCategoryCards || allAppsPage.gridMode
            ? (contentColumnWidth >= 690 ? 4 : contentColumnWidth >= 360 ? 3 : 2) : 1
        cellWidth: Math.max(1, Math.floor(contentColumnWidth / columns))
        cellHeight: allAppsPage.showCategoryCards ? cellWidth + 16
            : allAppsPage.gridMode ? 82 : Math.max(34, Math.floor(Kirigami.Units.gridUnit * 1.8) + 2)
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: -1
        model: !allAppsPage.showAllSection ? null
            : allAppsPage.categoryMode
                ? allAppsPage.categoryModel
                : allAppsPage.flatModel
        function activateRow(row) { allAppsPage.activateRow(row); }
        header: allAppsPage.homeHeader

        PlasmaComponents3.ScrollBar.vertical: StartScrollBar {}
        StartWheelHandler {
            view: allAppsListView
            rowHeight: Math.min(40, allAppsListView.cellHeight)
        }

        delegate: allAppsPage.showCategoryCards ? categoryCard : applicationRow

        Component {
            id: applicationRow
            ListItemDelegate {
                gridMode: allAppsPage.gridMode
                iconSize: allAppsPage.gridMode ? 32 : 24
            }
        }

        Component {
            id: categoryCard
            Item {
                id: card
                width: allAppsListView.cellWidth
                height: allAppsListView.cellHeight
                readonly property int categoryIndex: index
                readonly property string categoryName: model.display ?? ""
                readonly property var childModel: allAppsListView.model
                    ? allAppsListView.model.modelForRow(categoryIndex) : null
                readonly property int appCount: childModel ? Math.max(0, childModel.count || 0) : 0

                function appIcon(row) {
                    // Qt::DecorationRole, preserving the Kicker application's actual icon.
                    return childModel && row >= 0 && row < appCount
                        ? childModel.data(childModel.index(row, 0), 1) : "";
                }

                function openCategory() {
                    allAppsListView.forceActiveFocus();
                    allAppsListView.currentIndex = categoryIndex;
                    allAppsPage.activateRow(categoryIndex);
                }

                Accessible.role: Accessible.Button
                Accessible.name: categoryName
                Accessible.onPressAction: openCategory()

                Rectangle {
                    id: surface
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 8
                    height: Math.max(1, width)
                    radius: 8
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                        Kirigami.Theme.textColor.b, cardHover.hovered
                            || (card.GridView.isCurrentItem && allAppsListView.activeFocus) ? 0.09 : 0.04)

                    HoverHandler { id: cardHover }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: card.openCategory()
                    }

                    Grid {
                        anchors.centerIn: parent
                        width: parent.width * 0.84
                        height: width
                        columns: 2
                        spacing: 4
                        Repeater {
                            model: 4
                            delegate: Item {
                                id: slot
                                required property int index
                                width: (surface.width * 0.84 - 4) / 2
                                height: width
                                readonly property bool cluster: index === 3 && card.appCount > 4
                                readonly property bool hasApp: index < card.appCount

                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: Math.min(32, parent.width * 0.7)
                                    height: width
                                    roundToIconSize: false
                                    visible: slot.hasApp && !slot.cluster
                                    source: card.appIcon(slot.index)
                                }

                                Grid {
                                    visible: slot.cluster
                                    anchors.centerIn: parent
                                    columns: 2
                                    spacing: 2
                                    Repeater {
                                        model: Math.min(4, Math.max(0, card.appCount - 3))
                                        delegate: Kirigami.Icon {
                                            required property int index
                                            width: Math.min(15, slot.width * 0.34)
                                            height: width
                                            roundToIconSize: false
                                            source: card.appIcon(index + 3)
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: slot.hasApp
                                    onClicked: {
                                        if (slot.cluster)
                                            card.openCategory();
                                        else if (card.childModel.trigger(slot.index, "", null))
                                            root.closeMenu();
                                    }
                                }
                            }
                        }
                    }

                    // Kicker can contain a top-level launchable item rather than a category.
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 32
                        height: width
                        visible: !card.childModel
                        source: model.decoration ?? ""
                        roundToIconSize: false
                    }
                }

                PlasmaComponents3.Label {
                    anchors.top: surface.bottom
                    anchors.topMargin: 6
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    horizontalAlignment: Text.AlignHCenter
                    text: card.categoryName
                    font.pixelSize: 12
                    maximumLineCount: 1
                    elide: Text.ElideRight
                    textFormat: Text.PlainText

                    MouseArea { anchors.fill: parent; onClicked: card.openCategory() }
                }
            }
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
                positionViewAtIndex(currentIndex, event.key === Qt.Key_Home ? GridView.Beginning : GridView.End);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
                const step = Math.max(1, Math.floor(height / cellHeight)) * columns;
                currentIndex = Math.max(0, Math.min(count - 1,
                    Math.max(0, currentIndex) + (event.key === Qt.Key_PageUp ? -step : step)));
                positionViewAtIndex(currentIndex, GridView.Contain);
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
            if (currentIndex < columns) {
                event.accepted = true;
                allAppsListView.positionViewAtBeginning();
                allAppsPage.keyNavUpFromList();
            }
        }
    }
    // Keep the category cards and their scroll position behind this overlay.
    // Explicit parent avoids adding an extra row to ColumnLayout or placing
    // the overlay inside the Flickable's scrolling contentItem.
    Item {
        id: categoryOverlay
        parent: allAppsListView
        anchors.fill: parent
        z: 100
        visible: allAppsPage.inCategory
        objectName: "wmStartCategoryOverlay"

        MouseArea {
            anchors.fill: parent
            onClicked: allAppsPage.backToCategories()
        }

        Rectangle {
            id: categorySurface
            objectName: "wmStartCategorySurface"
            anchors.centerIn: parent
            width: Math.max(1, Math.min(parent.width - 24, 512))
            height: Math.max(1, Math.min(parent.height - 24,
                70 + Math.max(1, Math.ceil(categoryGrid.count / categoryGrid.columns)) * categoryGrid.cellHeight + 20))
            radius: 8
            readonly property bool dark: {
                const c = Kirigami.Theme.backgroundColor;
                return (c.r * 0.299 + c.g * 0.587 + c.b * 0.114) < 0.5;
            }
            color: dark ? "#252525" : "#F9F9F9"
            border.width: 1
            border.color: dark ? "#404040" : "#E4E4E4"

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    text: allAppsPage.categoryTitle
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                GridView {
                    id: categoryGrid
                    objectName: "wmStartCategoryGrid"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: allAppsPage.categoryChild
                    readonly property int columns: width >= 340 ? 4 : width >= 240 ? 3 : 2
                    cellWidth: Math.max(1, Math.floor((width - 12) / columns))
                    cellHeight: 82
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: -1
                    function activateRow(row) {
                        if (model && row >= 0 && row < count && model.trigger(row, "", null))
                            root.closeMenu();
                    }
                    delegate: ListItemDelegate {
                        gridMode: true
                        iconSize: 32
                    }
                    PlasmaComponents3.ScrollBar.vertical: StartScrollBar {}
                    StartWheelHandler {
                        view: categoryGrid
                        rowHeight: categoryGrid.cellHeight
                    }
                    Keys.onReturnPressed: activateRow(currentIndex)
                    Keys.onEnterPressed: activateRow(currentIndex)
                    Keys.onEscapePressed: allAppsPage.backToCategories()
                }
            }
        }
    }

}
