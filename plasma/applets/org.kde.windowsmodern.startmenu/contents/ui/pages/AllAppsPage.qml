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

Item {
    id: allAppsPage

    readonly property var allAppsList: categoryMode ? allAppsListView : alphabeticalView
    property Component homeHeader: null
    property var flatModel: null
    property var categoryModel: null
    property var categoryUsageModel: null
    property bool showAllSection: true
    property bool categoryMode: false
    property bool gridMode: false
    property bool alphabeticalGrouping: true
    property int scrollbarEdgeOffset: 0
    signal appContextMenuRequested(var entry, real x, real y)
    HoverHandler { id: homeViewportHover; enabled: !allAppsPage.inCategory }
    readonly property bool showCategoryCards: categoryMode
    readonly property var activeView: inCategory ? categoryGrid : allAppsList
    property var categoryChild: null
    property string categoryTitle: ""
    property string categoryKey: ""
    property int categoryRow: 0
    readonly property bool inCategory: categoryMode && categoryChild !== null

    function resetCategory() {
        categoryChild = null;
        categoryTitle = "";
        categoryKey = "";
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
        const bucket = categoryCatalog.rows[row];
        if (!categoryMode || !bucket || inCategory) return;
        categoryRow = row;
        categoryKey = bucket.key;
        categoryTitle = bucket.label;
        categoryChild = bucket.entries;
        Qt.callLater(function() {
            categoryGrid.currentIndex = -1;
            categoryGrid.positionViewAtBeginning();
            categoryGrid.forceActiveFocus();
        });
    }

    function scrollToAll() {
        if (allAppsList.count > 0)
            allAppsList.positionViewAtIndex(0, GridView.Beginning);
        else
            allAppsList.positionViewAtBeginning();
    }

    function activateFlatRow(row) {
        if (flatModel && row >= 0 && row < alphabeticalView.sourceEntries.length
                && typeof flatModel.trigger === "function"
                && flatModel.trigger(row, "", null))
            root.closeMenu();
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
        if (activeView === alphabeticalView)
            alphabeticalView.moveVertical(-1);
        else if (activeView.count > 0)
            activeView.currentIndex = Math.max(0, activeView.currentIndex - activeView.columns);
    }

    function navigateDown() {
        if (activeView === alphabeticalView)
            alphabeticalView.moveVertical(1);
        else if (activeView.count > 0)
            activeView.currentIndex = Math.min(activeView.count - 1, activeView.currentIndex < 0 ? 0 : activeView.currentIndex + activeView.columns);
    }

    function activateCurrent() {
        activeView.activateRow(Math.max(0, activeView.currentIndex));
    }

    // Only the active view owns the Pinned/Recommended/All header. Each
    // mode has a single vertical scroller; no nested scrolling sections.
    AlphabeticalAppsView {
        id: alphabeticalView
        anchors.fill: parent
        visible: !allAppsPage.categoryMode
        sourceModel: allAppsPage.flatModel
        showApps: !allAppsPage.categoryMode && allAppsPage.showAllSection
        gridMode: allAppsPage.gridMode
        alphabeticalGrouping: allAppsPage.alphabeticalGrouping
        scrollbarEdgeOffset: allAppsPage.scrollbarEdgeOffset
        header: !allAppsPage.categoryMode ? allAppsPage.homeHeader : null
        onApplicationActivated: row => allAppsPage.activateFlatRow(row)
        onNavigateToHeader: allAppsPage.keyNavUpFromList()
    }

    WindowsCategories {
        id: categoryCatalog
        entries: alphabeticalView.sourceEntries
        nativeModel: allAppsPage.categoryModel
        usageModel: allAppsPage.categoryUsageModel
        onRowsChanged: {
            if (!allAppsPage.inCategory) return;
            const row = rows.findIndex(bucket => bucket.key === allAppsPage.categoryKey);
            if (row < 0) {
                allAppsPage.resetCategory();
                return;
            }
            const previous = allAppsPage.categoryChild[categoryGrid.currentIndex];
            const key = previous ? String(previous.favoriteId || previous.url || "") : "";
            allAppsPage.categoryRow = row;
            allAppsPage.categoryTitle = rows[row].label;
            allAppsPage.categoryChild = rows[row].entries;
            categoryGrid.currentIndex = key ? rows[row].entries.findIndex(entry =>
                String(entry.favoriteId || entry.url || "") === key) : -1;
        }
    }

    GridView {
        id: allAppsListView
        anchors.fill: parent
        clip: true
        visible: allAppsPage.categoryMode
        interactive: !allAppsPage.inCategory
        readonly property int scrollGutter: allAppsPage.scrollbarEdgeOffset > 0 ? 0 : 18
        readonly property real contentColumnWidth: Math.max(1, width - scrollGutter)
        readonly property int columns: contentColumnWidth >= 690 ? 4 : contentColumnWidth >= 360 ? 3 : 2
        cellWidth: Math.max(1, Math.floor(contentColumnWidth / columns))
        cellHeight: cellWidth + 24
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: -1
        model: allAppsPage.categoryMode && allAppsPage.showAllSection ? categoryCatalog.rows : []
        function activateRow(row) { allAppsPage.activateRow(row); }
        header: allAppsPage.categoryMode ? allAppsPage.homeHeader : null

        PlasmaComponents3.ScrollBar.vertical: StartScrollBar {
            objectName: "wmStartCategoryScrollBar"
            parent: allAppsPage
            anchors.top: allAppsListView.top
            anchors.bottom: allAppsListView.bottom
            anchors.right: allAppsListView.right
            anchors.rightMargin: -allAppsPage.scrollbarEdgeOffset
            visible: allAppsListView.visible && !allAppsPage.inCategory && size < 1
            viewportHovered: homeViewportHover.hovered
            scrolling: allAppsListView.moving
            z: 5
        }
        StartWheelHandler {
            view: allAppsListView
            rowHeight: Math.min(40, allAppsListView.cellHeight)
        }

        delegate: categoryCard

        Component {
            id: categoryCard
            Item {
                id: card
                width: allAppsListView.cellWidth
                height: allAppsListView.cellHeight
                required property int index
                required property var modelData
                readonly property int categoryIndex: index
                readonly property string categoryName: modelData.label
                readonly property var childModel: modelData.entries
                readonly property int appCount: childModel.length

                function appIcon(row) {
                    return row >= 0 && row < appCount ? childModel[row].decoration || "" : "";
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
                                readonly property var entry: hasApp ? card.childModel[index] : null
                                readonly property string appName: cluster ? card.categoryName
                                    : entry ? String(entry.name || entry.display || "") : ""
                                readonly property bool hovered: slotMouse.containsMouse
                                objectName: "wmStartCategorySlot_" + card.categoryIndex + "_" + index
                                Accessible.role: Accessible.Button
                                Accessible.name: appName
                                Accessible.ignored: !hasApp
                                Accessible.onPressAction: activate()

                                function activate() {
                                    if (!hasApp) return;
                                    if (cluster)
                                        card.openCategory();
                                    else
                                        allAppsPage.activateFlatRow(entry.index);
                                }

                                Rectangle {
                                    objectName: "wmStartCategorySlotHover"
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: 6
                                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                        Kirigami.Theme.textColor.b, slotMouse.containsPress ? 0.12
                                            : slot.hovered ? 0.07 : 0)
                                }

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
                                    id: slotMouse
                                    anchors.fill: parent
                                    enabled: slot.hasApp
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            if (!slot.cluster) {
                                                const pos = slot.mapToItem(allAppsPage, mouse.x, mouse.y);
                                                allAppsPage.appContextMenuRequested(slot.entry, pos.x, pos.y);
                                            }
                                        } else {
                                            slot.activate();
                                        }
                                    }
                                }
                                PlasmaComponents3.ToolTip {
                                    visible: slot.hasApp && slot.hovered && !slotMouse.containsPress
                                    text: slot.appName
                                    delay: Kirigami.Units.toolTipDelay
                                }
                            }
                        }
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
            // Size from the model and available width, not a child layout
            // whose height feeds back into the surface's implicit height.
            readonly property int appColumns: width - 32 >= 340 ? 4 : width - 32 >= 240 ? 3 : 2
            readonly property int appCount: allAppsPage.categoryChild ? allAppsPage.categoryChild.length : 0
            readonly property int appCellHeight: 84
            height: Math.max(1, Math.min(parent.height - 24,
                84 + Math.max(1, Math.ceil(appCount / appColumns)) * appCellHeight))
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
                    model: allAppsPage.categoryChild || []
                    readonly property int columns: categorySurface.appColumns
                    cellWidth: Math.max(1, Math.floor((width - 12) / columns))
                    cellHeight: categorySurface.appCellHeight
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: -1
                    function activateRow(row) {
                        if (row >= 0 && row < count)
                            allAppsPage.activateFlatRow(model[row].index);
                    }
                    // The visual grid has reordered rows, but context
                    // actions must still target the original Kicker proxy.
                    QtObject {
                        id: categoryActions
                        readonly property var model: allAppsPage.flatModel
                        readonly property bool activeFocus: categoryGrid.activeFocus
                        readonly property int currentIndex: categoryGrid.currentIndex >= 0
                            && categoryGrid.currentIndex < categoryGrid.count
                            ? categoryGrid.model[categoryGrid.currentIndex].index : -1
                        function forceActiveFocus() { categoryGrid.forceActiveFocus(); }
                        function activateRow(sourceRow) {
                            const index = categoryGrid.model.findIndex(entry => entry.index === sourceRow);
                            if (index < 0) return;
                            categoryGrid.currentIndex = index;
                            categoryGrid.activateRow(index);
                        }
                    }
                    delegate: ListItemDelegate {
                        required property var modelData
                        suppliedView: categoryActions
                        appData: modelData
                        itemIndex: modelData.index
                        width: categoryGrid.cellWidth
                        height: categoryGrid.cellHeight
                        gridMode: true
                        iconSize: 32
                        showInstallBadge: true
                    }
                    PlasmaComponents3.ScrollBar.vertical: StartScrollBar { scrolling: categoryGrid.moving }
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
