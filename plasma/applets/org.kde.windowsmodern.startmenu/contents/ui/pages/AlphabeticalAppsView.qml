// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kitemmodels as KItemModels
import "../components"
import "../code/alphabeticalApps.js" as Alphabetical

FocusScope {
    id: view
    objectName: "wmAlphabeticalApps"
    property var sourceModel: null
    readonly property var model: sourceModel
    property bool showApps: true
    property bool gridMode: false
    property bool alphabeticalGrouping: true
    property Component header: null
    readonly property var headerItem: rowsView.headerItem
    property int scrollbarEdgeOffset: 0
    readonly property int scrollGutter: scrollbarEdgeOffset > 0 ? 0 : 18
    HoverHandler { id: alphabeticalViewportHover }
    readonly property real contentColumnWidth: Math.max(1, width - scrollGutter)
    readonly property int columns: !gridMode ? 1 : contentColumnWidth >= 430 ? 6 : contentColumnWidth >= 320 ? 4 : 3
    readonly property int cellWidth: Math.max(1, Math.floor(contentColumnWidth / columns))
    readonly property int cellHeight: gridMode ? 84 : Math.max(36, Math.floor(Kirigami.Units.gridUnit * 1.8) + 2)
    readonly property int headingHeight: 36
    property int currentIndex: -1
    property var sourceEntries: []
    readonly property var entries: showApps ? sourceEntries : []
    readonly property int count: entries.length
    readonly property var visualRows: Alphabetical.buildRows(entries, columns, alphabeticalGrouping)
    property bool letterIndexOpen: false
    property real letterIndexScrollY: 0
    readonly property var letterIndexEntries: Alphabetical.letterIndex(visualRows)
    signal applicationActivated(int sourceRow)
    signal navigateToHeader()

    // A snapshot is rebuilt only when the actual application model changes.
    // Keep Qt's role values (QIcon/QUrl/actionList) intact, and keep the
    // proxy's row number so actions go back through its mapToSource().
    function refresh() {
        const source = sourceModel;
        const next = [];
        if (source !== null && source !== undefined) {
            const size = typeof source === "number" ? source
                : typeof source.rowCount === "function" ? source.rowCount()
                : Number(source.count || 0);
            const roles = ["display", "name", "group", "decoration", "description", "favoriteId",
                "url", "actionList", "isParent", "disabled", "isNewlyInstalled"];
            const roleIds = {};
            if (typeof source.get !== "function" && typeof source.index === "function" && typeof source.data === "function") {
                for (const role of roles)
                    roleIds[role] = source.KItemModels.KRoleNames.role(role);
            }
            for (let row = 0; row < size; ++row) {
                const entry = {index: row};
                if (typeof source.get === "function") {
                    const value = source.get(row);
                    for (const role of roles) {
                        if (value && value[role] !== undefined) entry[role] = value[role];
                    }
                } else if (typeof source.index === "function" && typeof source.data === "function") {
                    const index = source.index(row, 0);
                    for (const role of roles) {
                        const id = roleIds[role];
                        if (id !== undefined && id >= 0) {
                            const value = source.data(index, id);
                            if (value !== undefined && value !== null) entry[role] = value;
                        }
                    }
                }
                next.push(entry);
            }
        }
        const old = currentIndex >= 0 ? entries[currentIndex] : null;
        const identity = old ? String(old.favoriteId || old.url || "") : "";
        sourceEntries = next;
        if (!showApps) {
            currentIndex = -1;
        } else if (identity) {
            currentIndex = next.findIndex(entry => String(entry.favoriteId || entry.url || "") === identity);
        } else if (currentIndex >= count) {
            currentIndex = count - 1;
        }
    }

    Timer {
        id: refreshTimer
        interval: 0
        onTriggered: view.refresh()
    }
    function scheduleRefresh() { refreshTimer.restart(); }
    onSourceModelChanged: scheduleRefresh()
    onShowAppsChanged: if (!showApps) {
        currentIndex = -1;
        letterIndexOpen = false;
    }
    onAlphabeticalGroupingChanged: if (!alphabeticalGrouping) letterIndexOpen = false
    onCountChanged: if (!count) letterIndexOpen = false
    Component.onCompleted: scheduleRefresh()
    Connections {
        target: typeof view.sourceModel === "object" ? view.sourceModel : null
        ignoreUnknownSignals: true
        function onModelReset() { view.scheduleRefresh(); }
        function onRowsInserted() { view.scheduleRefresh(); }
        function onRowsRemoved() { view.scheduleRefresh(); }
        function onRowsMoved() { view.scheduleRefresh(); }
        function onLayoutChanged() { view.scheduleRefresh(); }
        function onDataChanged() { view.scheduleRefresh(); }
    }

    function positionViewAtBeginning() { rowsView.positionViewAtBeginning(); }
    function positionViewAtIndex(sourceIndex, mode) {
        const pos = Alphabetical.locate(visualRows, sourceIndex);
        if (pos.row >= 0)
            rowsView.positionViewAtIndex(pos.row, mode === GridView.Beginning ? ListView.Beginning
                : mode === GridView.End ? ListView.End : ListView.Contain);
    }
    onCurrentIndexChanged: {
        if (currentIndex >= 0) positionViewAtIndex(currentIndex, GridView.Contain);
    }

    function activateRow(row) {
        if (row < 0 || row >= count) return;
        currentIndex = row;
        if (!entries[row].disabled) applicationActivated(row);
    }
    function moveVertical(direction) {
        currentIndex = Alphabetical.verticalNeighbor(visualRows, currentIndex, direction);
    }
    function moveHorizontal(direction) {
        currentIndex = Alphabetical.horizontalNeighbor(visualRows, currentIndex, direction);
    }

    function openLetterIndex() {
        if (!alphabeticalGrouping || !count || letterIndexOpen) return;
        rowsView.cancelFlick();
        letterIndexScrollY = rowsView.contentY;
        letterIndexOpen = true;
    }
    function closeLetterIndex(restoreFocus) {
        if (!letterIndexOpen) return;
        letterIndexOpen = false;
        if (restoreFocus) {
            rowsView.forceActiveFocus(Qt.OtherFocusReason);
            rowsView.forceLayout();
            rowsView.contentY = letterIndexScrollY;
        }
    }

    function jumpToLetter(letter) {
        const entry = letterIndexEntries.find(item => item.label === letter);
        if (!entry || !entry.available) return false;
        closeLetterIndex(true);
        // Resolve the section against the current model, not a captured
        // row number after a queued model reset.
        currentIndex = entry.sourceIndex;
        positionViewAtIndex(currentIndex, GridView.Beginning);
        return true;
    }

    ListView {
        id: rowsView
        anchors.fill: parent
        objectName: "wmStartAlphabeticalRows"
        focus: !view.letterIndexOpen
        enabled: !view.letterIndexOpen
        keyNavigationEnabled: false
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: view.visualRows
        header: view.header
        currentIndex: -1
        spacing: 0

        delegate: Item {
            id: visualRow
            required property var modelData
            width: view.contentColumnWidth
            height: (modelData.heading ? view.headingHeight : 0) + view.cellHeight

            PlasmaComponents3.Label {
                id: sectionLabel
                objectName: "wmStartLetterHeading"
                width: Math.min(parent.width, Math.max(44, implicitWidth + 10))
                height: visible ? view.headingHeight : 0
                visible: visualRow.modelData.heading.length > 0
                text: visualRow.modelData.heading
                readonly property bool hovered: sectionHeadingMouse.containsMouse
                color: Kirigami.Theme.textColor
                font.pixelSize: Math.max(13, Kirigami.Theme.defaultFont.pixelSize)
                font.weight: Font.Medium
                background: Rectangle {
                    radius: 4
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                        Kirigami.Theme.textColor.b, sectionHeadingMouse.containsPress ? 0.12
                            : sectionLabel.hovered || sectionLabel.activeFocus ? 0.07 : 0)
                    Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                }
                verticalAlignment: Text.AlignVCenter
                leftPadding: 10
                textFormat: Text.PlainText
                activeFocusOnTab: visible && view.alphabeticalGrouping
                Accessible.role: Accessible.Button
                Accessible.name: text + ", " + i18n("Open letter index")
                Accessible.description: i18n("Choose a letter to jump to its apps")
                Accessible.onPressAction: view.openLetterIndex()
                Keys.onReturnPressed: view.openLetterIndex()
                Keys.onEnterPressed: view.openLetterIndex()
                Keys.onSpacePressed: view.openLetterIndex()
                MouseArea {
                    id: sectionHeadingMouse
                    objectName: "wmStartLetterHeadingHitArea"
                    anchors.fill: parent
                    enabled: sectionLabel.visible && view.alphabeticalGrouping
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: view.openLetterIndex()
                }
            }

            Row {
                y: sectionLabel.height
                width: parent.width
                height: view.cellHeight
                spacing: 0

                Repeater {
                    model: visualRow.modelData.entries
                    delegate: ListItemDelegate {
                        required property var modelData
                        suppliedView: view
                        appData: modelData
                        itemIndex: modelData.index
                        width: view.cellWidth
                        height: view.cellHeight
                        gridMode: view.gridMode
                        iconSize: gridMode ? 32 : 24
                        showInstallBadge: true
                    }
                }
            }
        }

        PlasmaComponents3.ScrollBar.vertical: StartScrollBar {
            objectName: "wmStartAlphabeticalScrollBar"
            parent: view
            anchors.top: rowsView.top
            anchors.bottom: rowsView.bottom
            anchors.right: rowsView.right
            anchors.rightMargin: -view.scrollbarEdgeOffset
            visible: rowsView.visible && !view.letterIndexOpen && size < 1
            viewportHovered: alphabeticalViewportHover.hovered
            scrolling: rowsView.moving
            z: 5
        }
        StartWheelHandler { view: rowsView; rowHeight: Math.min(40, view.cellHeight) }
    }

    LetterIndex {
        id: letterIndex
        anchors.fill: parent
        z: 20
        opened: view.letterIndexOpen
        letters: view.letterIndexEntries
        onLetterActivated: letter => view.jumpToLetter(letter)
        onBackRequested: view.closeLetterIndex(true)
    }

    Keys.onPressed: event => {
        if (!count || letterIndexOpen) return;
        const position = Alphabetical.locate(visualRows, currentIndex);
        switch (event.key) {
        case Qt.Key_Up:
            if (position.row === 0) {
                positionViewAtBeginning();
                navigateToHeader();
            } else moveVertical(-1);
            break;
        case Qt.Key_Down: moveVertical(1); break;
        case Qt.Key_Left: moveHorizontal(-1); break;
        case Qt.Key_Right: moveHorizontal(1); break;
        case Qt.Key_Home: currentIndex = visualRows[0].entries[0].index; break;
        case Qt.Key_End: {
            const last = visualRows[visualRows.length - 1].entries;
            currentIndex = last[last.length - 1].index;
            break;
        }
        case Qt.Key_PageUp:
        case Qt.Key_PageDown:
            for (let i = 0; i < Math.max(1, Math.floor(height / cellHeight)); ++i)
                moveVertical(event.key === Qt.Key_PageUp ? -1 : 1);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            activateRow(currentIndex >= 0 ? currentIndex : visualRows[0].entries[0].index);
            break;
        default: return;
        }
        event.accepted = true;
    }
}
