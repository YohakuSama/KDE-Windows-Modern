/***************************************************************************
 *   License: GPL-3.0-or-later
 *   Author: Jeysef
 *
 *   Search results shown in the left column when the search field has text.
 *   Uses Milou.ResultsView (the same component the default Plasma Kickoff
 *   uses) for the model/scrolling/keyboard logic, with a custom delegate
 *   and full-row collapsible category headers.
 ***************************************************************************/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.milou as Milou

import "../components"
import "../code/tools.js" as Tools
import "../code/theme.js" as Theme

Item {
    id: searchPage

    width: parent.width
    height: parent.height

    property alias resultsView: resultsView
    property int scrollbarEdgeOffset: 0
    HoverHandler { id: searchViewportHover }

    // Emitted by result delegates when the user right-clicks.  The shell
    // (MenuRepresentation) owns the shared ContextMenu instance and opens
    // it — delegates inside Milou.ResultsView can't resolve that id
    // directly due to Qt 6 Repeater delegate scoping.
    signal contextMenuRequested(var actions, real globalX, real globalY, var context)
    signal focusSearchRequested

    // Track collapsed categories as a comma-separated string so QML
    // binding updates fire reliably (var objects don't notify on nested
    // key changes).
    property string collapsedCategories: ""

    // The pointer selects a result only once it really moves, as on
    // Windows: results that appear under a resting pointer (you opened
    // Start with the mouse over it and typed) must not steal the
    // selection from the best match that Enter runs. Qt sends hover
    // events when content moves under a still pointer, so movement is
    // judged by screen position. Reset whenever the query changes.
    property point lastPointer: Qt.point(-1, -1)
    property bool pointerMoved: false

    function trackPointer(item, x, y) {
        const p = item.mapToGlobal(x, y);
        if (lastPointer.x >= 0 && (Math.abs(p.x - lastPointer.x) > 1 || Math.abs(p.y - lastPointer.y) > 1)) {
            pointerMoved = true;
        }
        lastPointer = p;
        return pointerMoved;
    }

    Connections {
        target: resultsView
        function onQueryStringChanged() {
            searchPage.pointerMoved = false;
            searchPage.collapsedCategories = "";
        }
    }

    function isCollapsed(cat) {
        if (!cat) return false
        var parts = collapsedCategories.split(",")
        return parts.indexOf(cat) >= 0
    }

    function toggleCollapsed(cat) {
        if (!cat) return
        var parts = collapsedCategories ? collapsedCategories.split(",") : []
        var idx = parts.indexOf(cat)
        if (idx >= 0) {
            parts.splice(idx, 1)
        } else {
            parts.push(cat)
        }
        collapsedCategories = parts.join(",")
        resultsView.forceLayout()
        if (!rowSelectable(resultsView.currentIndex))
            resultsView.currentIndex = firstSelectable(0, 1);
    }

    function rowSelectable(row) {
        if (row < 0 || row >= resultsView.count) return false;
        const model = resultsView.model;
        const index = model.index(row, 0);
        return !isCollapsed(model.data(index, Milou.ResultsModel.CategoryRole))
            && model.data(index, Milou.ResultsModel.EnabledRole) !== false;
    }

    function firstSelectable(row, direction) {
        for (let i = row; i >= 0 && i < resultsView.count; i += direction) {
            if (rowSelectable(i)) return i;
        }
        return -1;
    }

    function moveSelection(direction) {
        const current = resultsView.currentIndex;
        const start = current < 0 ? (direction > 0 ? 0 : resultsView.count - 1) : current + direction;
        const next = firstSelectable(start, direction);
        if (next < 0) return false;
        resultsView.currentIndex = next;
        resultsView.positionViewAtIndex(next, ListView.Contain);
        return true;
    }

    function activateFilter(runner) {
        if (resultsView.singleRunner === runner) return;
        const query = resultsView.queryString;
        resultsView.singleRunner = runner;
        resultsView.queryString = "";
        resultsView.queryString = query;
    }

    function tryActivate(row, col) {
        if (resultsView.count > 0) {
            const start = Math.max(0, Math.min(row, resultsView.count - 1));
            const next = firstSelectable(start, 1);
            resultsView.currentIndex = next >= 0 ? next : firstSelectable(start - 1, -1);
            if (resultsView.currentIndex >= 0) resultsView.forceActiveFocus();
        }
    }

    function navigateUp() { moveSelection(-1); }
    function navigateDown() { moveSelection(1); }

    function activateCurrent() {
        const row = resultsView.currentIndex;
        if (!rowSelectable(row)) return;
        // Do not queue an unrelated first result if the custom delegate
        // is hidden or the query is still changing. Close only on success.
        if (resultsView.model.run(resultsView.model.index(row, 0)))
            resultsView.activated();
    }

    function activateFirstResult() {
        resultsView.currentIndex = firstSelectable(0, 1);
        activateCurrent();
    }

    // ── Filter pills (rounded chips) ────────────────────────────────────
    Flow {
        id: filterPillsWrapper
        anchors.top: parent.top
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.searching
        height: implicitHeight
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            // Runner ids must match the runners loaded by main.qml's
            // RunnerModel.  "" means "all runners".
            model: [
                { label: i18n("All"),      runner: "" },
                { label: i18n("Apps"),     runner: "krunner_services" },
                { label: i18n("Files"),    runner: "baloosearch" },
                { label: i18n("Settings"), runner: "krunner_systemsettings" },
                { label: i18n("Actions"),  runner: "krunner_powerdevil" }
            ]
            delegate: Rectangle {
                id: filterPill
                required property var modelData

                readonly property bool active: resultsView.singleRunner === modelData.runner

                radius: 4
                implicitHeight: Math.max(28, pillLabel.implicitHeight + 8)
                implicitWidth: pillLabel.implicitWidth + Kirigami.Units.largeSpacing * 2
                width: Math.max(1, Math.min(implicitWidth, filterPillsWrapper.width))
                height: implicitHeight
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: modelData.label
                Accessible.onPressAction: searchPage.activateFilter(modelData.runner)
                Keys.onReturnPressed: searchPage.activateFilter(modelData.runner)
                Keys.onEnterPressed: searchPage.activateFilter(modelData.runner)
                Keys.onSpacePressed: searchPage.activateFilter(modelData.runner)
                color: active
                       ? Kirigami.Theme.highlightColor
                       : (pillHover.containsMouse
                          ? Qt.rgba(Kirigami.Theme.textColor.r,
                                    Kirigami.Theme.textColor.g,
                                    Kirigami.Theme.textColor.b, Theme.buttonFlatHoverOpacity)
                          : Qt.rgba(Kirigami.Theme.textColor.r,
                                    Kirigami.Theme.textColor.g,
                                    Kirigami.Theme.textColor.b, Theme.buttonFlatBackgroundOpacity))
                border.width: active && !activeFocus ? 0 : 1
                border.color: activeFocus ? Kirigami.Theme.highlightColor
                    : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                        Kirigami.Theme.textColor.b, Theme.buttonBorderOpacity)
                Behavior on color { ColorAnimation { duration: 90 } }

                PlasmaComponents3.Label {
                    id: pillLabel
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: filterPill.modelData.label
                    color: filterPill.active ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    font.pixelSize: 12
                    font.weight: filterPill.active ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                    id: pillHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: searchPage.activateFilter(filterPill.modelData.runner)
                }
            }
        }

     }

    // ── Search results (Milou ResultsView with custom delegate) ────────
    Milou.ResultsView {
        id: resultsView
        anchors {
            top: filterPillsWrapper.bottom
            topMargin: Kirigami.Units.largeSpacing
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        clip: true
        highlight: null
        // queryField is left null — we drive queryString explicitly from
        // the shell's search field.  Setting it to a foreign id that
        // isn't in scope here throws a ReferenceError.
        queryField: null
        // queryString is set explicitly by the shell on text change.
        limit: 50

        onActivated: root.closeMenu()

        readonly property int scrollGutter: searchPage.scrollbarEdgeOffset > 0 ? 0 : 18
        readonly property real contentColumnWidth: Math.max(1, width - scrollGutter)
        PlasmaComponents3.ScrollBar.vertical: StartScrollBar {
            objectName: "wmStartSearchScrollBar"
            parent: searchPage
            anchors.top: resultsView.top
            anchors.bottom: resultsView.bottom
            anchors.right: resultsView.right
            anchors.rightMargin: -searchPage.scrollbarEdgeOffset
            visible: resultsView.visible && size < 1
            viewportHovered: searchViewportHover.hovered
            scrolling: resultsView.moving
            z: 5
        }
        StartWheelHandler {
            view: resultsView
            rowHeight: Math.floor(Kirigami.Units.gridUnit * 1.6)
        }

        // Custom section header: full-row, collapsible
        section.delegate: Rectangle {
            width: resultsView.contentColumnWidth
            height: headerRow.implicitHeight + Kirigami.Units.smallSpacing
            color: "transparent"

            readonly property string category: section

            RowLayout {
                id: headerRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    source: searchPage.isCollapsed(section) ? "arrow-right" : "arrow-down"
                    opacity: Theme.dimmedIconOpacity
                }

                PlasmaComponents3.Label {
                    text: section
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Qt.rgba(Kirigami.Theme.textColor.r,
                                   Kirigami.Theme.textColor.g,
                                   Kirigami.Theme.textColor.b, Theme.headerSeparatorOpacity)
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: searchPage.toggleCollapsed(section)
            }
        }

        // Custom delegate: icon left, text right, no inline category
        delegate: Item {
            id: resultDelegate

            width: resultsView.contentColumnWidth
            height: visible ? Math.floor(Kirigami.Units.gridUnit * 1.6) : 0
            enabled: model.enabled !== false

            required property int index
            required property var model

            readonly property bool isCurrent: ListView.isCurrentItem

            Accessible.role: Accessible.ListItem
            Accessible.name: resultDelegate.model.display || ""
            Accessible.selected: isCurrent

            // Hover/selection highlight — matches ListItemDelegate style
            Rectangle {
                anchors.fill: parent
                anchors.margins: 0
                radius: Kirigami.Units.smallSpacing
                color: Kirigami.Theme.hoverColor
                opacity: {
                    if (resultMouse.containsMouse && searchPage.pointerMoved) return 1.0
                    if (resultDelegate.isCurrent) return 0.5
                    return 0.0
                }
                Behavior on opacity { NumberAnimation { duration: 90 } }
            }

            RowLayout {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Kirigami.Units.largeSpacing
                anchors.right: parent.right
                anchors.rightMargin: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    source: resultDelegate.model.decoration || ""
                    animated: false
                }

                PlasmaComponents3.Label {
                    id: displayLabel
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    color: Kirigami.Theme.textColor
                    text: resultDelegate.model.display || ""
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                    textFormat: Text.PlainText
                    verticalAlignment: Text.AlignVCenter
                }

                PlasmaComponents3.Label {
                    visible: text.length > 0
                    opacity: Theme.dimmedTextOpacity
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    color: Kirigami.Theme.textColor
                    text: resultDelegate.model.subtext || ""
                    textFormat: Text.PlainText
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 2
                    verticalAlignment: Text.AlignVCenter
                    Layout.maximumWidth: resultsView.width * 0.35
                }
            }

            MouseArea {
                id: resultMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    resultsView.currentIndex = resultDelegate.index
                    if (mouse.button === Qt.RightButton) {
                        openResultContextMenu(mouse.x, mouse.y)
                        return
                    }
                    searchPage.activateCurrent()
                }
                onEntered: {
                    if (searchPage.trackPointer(resultMouse, mouseX, mouseY)) {
                        resultsView.currentIndex = resultDelegate.index
                    }
                }
                onPositionChanged: mouse => {
                    if (searchPage.trackPointer(resultMouse, mouse.x, mouse.y)) {
                        resultsView.currentIndex = resultDelegate.index
                    }
                }
            }

            function openResultContextMenu(localX, localY) {
                var acts = []

                // Runner-provided actions (e.g. "Run in terminal", "Open
                // containing folder"). Milou exposes these via the
                // ActionsRole as a list of {text, iconSource, ...}.
                var runnerActions = resultDelegate.model.actions || []
                for (var i = 0; i < runnerActions.length; i++) {
                    var a = runnerActions[i]
                    acts.push({
                        text: a.text || "",
                        icon: a.iconName || a.iconSource || "",
                        actionId: "_milou_runner_action",
                        actionArgument: { actionIndex: i, matchIndex: resultDelegate.index }
                    })
                }

                // Only a stable desktop-file URL may resolve an app's actions.
                // Localized names can refer to several unrelated results.
                var entry = rootItem.lookupAppByUrls(resultDelegate.model.urls)
                var favModel = (typeof kicker !== "undefined" && kicker.globalFavorites)
                               ? kicker.globalFavorites : null

                var ctx = {
                    model: resultsView.model,
                    index: resultDelegate.index,
                    kind: "milou",
                    matchIndex: resultDelegate.index
                }

                if (entry) {
                    // Resolved: route favorite/model actions through the
                    // all-apps model, on the app's real row, so
                    // triggerAction() works for every action type.
                    ctx.resolvedModel = sortedAppsModel
                    ctx.resolvedIndex = entry.row

                    var appActs = Tools.buildAppActions(i18n, favModel,
                                                        entry.favoriteId,
                                                        entry.url,
                                                        entry.actionList)
                    if (appActs.length > 0) {
                        if (acts.length > 0) acts.push({ type: "separator" })
                        acts = acts.concat(appActs)
                    }
                }

                // Always offer an "Open" action so the menu is never empty.
                if (acts.length === 0) {
                    acts.push({
                        text: i18n("Open"),
                        icon: "window-new",
                        actionId: "_milou_open",
                        actionArgument: { matchIndex: resultDelegate.index }
                    })
                }

                var pos = resultDelegate.mapToItem(searchPage, localX, localY)
                searchPage.contextMenuRequested(acts, pos.x, pos.y, ctx)
            }

            // Hide items in collapsed categories
            visible: !searchPage.isCollapsed(resultDelegate.ListView.section)
        }

        Keys.onReturnPressed: searchPage.activateCurrent()
        Keys.onEnterPressed: searchPage.activateCurrent()

        Keys.onUpPressed: event => {
            event.accepted = true;
            if (!searchPage.moveSelection(-1)) searchPage.focusSearchRequested();
        }
        Keys.onDownPressed: event => {
            event.accepted = true;
            searchPage.moveSelection(1);
        }
        // The inherited Milou Tab handlers expect its native delegate.
        // Our custom delegate has no per-action focus, so move by row.
        Keys.onTabPressed: event => {
            event.accepted = true;
            if (!searchPage.moveSelection(1)) searchPage.focusSearchRequested();
        }
        Keys.onBacktabPressed: event => {
            event.accepted = true;
            if (!searchPage.moveSelection(-1)) searchPage.focusSearchRequested();
        }
        Keys.onHomePressed: event => {
            event.accepted = true;
            currentIndex = searchPage.firstSelectable(0, 1);
        }
        Keys.onEndPressed: event => {
            event.accepted = true;
            currentIndex = searchPage.firstSelectable(count - 1, -1);
        }
    }
}
