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
    property bool gridMode: false
    readonly property bool showCategoryCards: categoryMode && !inCategory
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
                Qt.callLater(focusFirstApp);
                return;
            }
        }
        if (source.trigger(row, "", null))
            root.closeMenu();
    }

    function scrollToAll() {
        if (allAppsListView.count > 0)
            allAppsListView.positionViewAtIndex(0, GridView.Beginning);
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
            allAppsListView.currentIndex = Math.max(0, allAppsListView.currentIndex - allAppsListView.columns);
        }
    }

    function navigateDown() {
        if (allAppsListView.count > 0) {
            allAppsListView.currentIndex = Math.min(allAppsListView.count - 1, allAppsListView.currentIndex < 0 ? 0 : allAppsListView.currentIndex + allAppsListView.columns);
        }
    }

    function activateCurrent() {
        activateRow(allAppsListView.currentIndex);
    }

    // A single native scroller for all three views and the inline home header.
    GridView {
        id: allAppsListView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        interactive: true
        readonly property int scrollGutter: 18
        readonly property real contentColumnWidth: Math.max(1, width - scrollGutter)
        readonly property int columns: allAppsPage.showCategoryCards || allAppsPage.gridMode
            ? (contentColumnWidth >= 690 ? 4 : contentColumnWidth >= 360 ? 3 : 2) : 1
        cellWidth: Math.max(1, Math.floor(contentColumnWidth / columns))
        cellHeight: allAppsPage.showCategoryCards ? cellWidth + 16
            : Math.max(34, Math.floor(Kirigami.Units.gridUnit * 1.8) + 2)
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: -1
        model: allAppsPage.categoryMode
            ? (allAppsPage.categoryChild || allAppsPage.categoryModel)
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
                iconSize: 24
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
                readonly property int appCount: childModel ? childModel.count : 0

                function appIcon(row) {
                    // Qt::DecorationRole, preserving the Kicker application's actual icon.
                    return childModel && row >= 0 && row < appCount
                        ? childModel.data(childModel.index(row, 0), 1) : "";
                }

                function openCategory() {
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
}
