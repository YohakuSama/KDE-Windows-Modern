/***************************************************************************
 *   License: GPL-3.0-or-later
 *   Author: Jeysef
 *
 *   Windows 11 Start shell: search, scrollable Pinned / Recent / All,
 *   and independent account / folder / power footer.
 *   Pages live in pages/, shared components in components/.
 *   Keyboard input is handled by a single top-level handler on rootItem
 *   so any printable character appends to the search field regardless
 *   of which page or child widget currently holds focus.
 ***************************************************************************/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kitemmodels 1.0 as KItemModels
import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.private.kicker 0.1 as Kicker

import "components"
import "pages"
import "code/tools.js" as Tools
import "code/theme.js" as Theme
import "code/popupPosition.js" as PopupPosition

Item {
    id: main

    // One row of sortedAppsModel, exposed by name for lookupAppByDisplayName().
    component AppLookupEntry: Item {
        required property int index
        required property var model
        readonly property string displayName: (model.display !== undefined) ? model.display : ""
        readonly property string favoriteId: (model.favoriteId !== undefined) ? model.favoriteId : ""
        readonly property var url: (model.url !== undefined) ? model.url : ""
        readonly property var actionList: (model.actionList !== undefined) ? model.actionList : null
    }

    // This Item's `visible` is only a toggle (flipping it opens or closes the
    // popup); menuShown is whether the popup is actually open.
    readonly property bool menuShown: root.visible

    onVisibleChanged: {
        root.visible = !root.visible
    }

    Plasmoid.status: root.visible ? PlasmaCore.Types.RequiresAttentionStatus : PlasmaCore.Types.PassiveStatus

    PlasmaCore.Dialog {
        id: root

        objectName: "popupWindow"
        flags: Qt.WindowStaysOnTopHint
        location: PlasmaCore.Types.Floating
        hideOnWindowDeactivate: true

        // Match the panel's popup preference by default, like Quick Settings
        // and the clock. Explicit translucency/opacity choices still override it.
        backgroundHints: {
            const mode = Plasmoid.configuration.menuTranslucency;
            const panelOpaque = (Plasmoid.containmentDisplayHints
                & PlasmaCore.Types.ContainmentPrefersOpaqueBackground) !== 0;
            return (mode === Theme.menuTranslucencyOpaque
                    || (mode === Theme.menuTranslucencyFollowTheme && panelOpaque))
                ? PlasmaCore.Dialog.SolidBackground
                : PlasmaCore.Dialog.StandardBackground;
        }

        property bool searching: startSearch.searchText !== ""

        // Keyboard target: 0 = pinned, 1 = all apps, 2 = search results.
        // Pinned and All now share the same scrollable home.
        readonly property var pinnedPage: allAppsPage.allAppsList.headerItem?.pinnedSectionItem ?? null
        property int leftColumnState: 0

        onSearchingChanged: {
            if (searching) {
                leftColumnState = 2;
                // Reset scroll position when entering search mode.
                searchPage.resultsView.contentY = 0;
                searchPage.resultsView.currentIndex = 0;
            } else {
                leftColumnState = 0;
            }
        }

        onVisibleChanged: {
            if (visible) {
                reposition();
                reset();
            } else {
                leftColumnState = 0;
                sharedContextMenu.close();
                powerMenu.close();
            }
        }

        onHeightChanged: if (visible) reposition()
        onWidthChanged: if (visible) reposition()

        function reposition() {
            var pos = popupPosition(width, height);
            x = pos.x; y = pos.y;
        }

        function toggle() {
            main.visible = !main.visible
        }

        function reset() {
            startSearch.searchText = "";
            leftColumnState = 0;
            // Nothing highlighted until hovered or picked with the arrow keys,
            // as on Windows (a ListView makes its first item current as soon
            // as it has items, so the first pinned app always looked selected).
            if (root.pinnedPage) {
                root.pinnedPage.favoritesList.currentIndex = -1;
                root.pinnedPage.favoritesList.positionViewAtBeginning();
            }
            allAppsPage.allAppsList.currentIndex = -1;
            allAppsPage.allAppsList.positionViewAtBeginning();
            // Reset the search filter pills to "All".
            searchPage.resultsView.singleRunner = "";
            // Defer focus until the dialog has finished laying out.
            Qt.callLater(startSearch.focusSearch);
        }

        function closeMenu() {
            root.visible = false;
        }

        function popupPosition(width, height) {
            // The compact representation creates this item as its child.
            // Use its actual screen geometry, including floating panel offsets.
            const button = main.parent;
            const topLeft = button.mapToGlobal(0, 0);
            const location = Plasmoid.location;
            const edge = location === PlasmaCore.Types.BottomEdge ? "bottom"
                       : location === PlasmaCore.Types.TopEdge ? "top"
                       : location === PlasmaCore.Types.LeftEdge ? "left"
                       : location === PlasmaCore.Types.RightEdge ? "right"
                       : "floating";
            const pos = PopupPosition.position(
                Plasmoid.configuration.displayPosition, edge, button.screenGeometry,
                { x: topLeft.x, y: topLeft.y, width: button.width, height: button.height },
                { width: width, height: height }, Kirigami.Units.smallSpacing);
            return Qt.point(pos.x, pos.y);
        }

        FocusScope {
            id: rootItem

            readonly property int margin: Kirigami.Units.gridUnit
            readonly property rect screen: Plasmoid.screenGeometry
            readonly property int wantedWidth: screen.width >= 1440 ? 768 : 600
            width: Math.max(1, Math.min(wantedWidth, screen.width > 0 ? screen.width - 2 * margin : wantedWidth))
            height: Math.max(1, Math.min(720, screen.height > 0 ? screen.height - 4 * margin : 720))
            focus: true

            // Note: do NOT auto-redirect to the search field here.
            // onFocusChanged fires when any child calls forceActiveFocus(),
            // and stealing focus back makes it impossible to type from lists.
            // Initial search focus is handled by reset().

            Plasma5Support.DataSource {
                id: executable
                engine: "executable"
                connectedSources: []

                onNewData: function (source, data) {
                    disconnectSource(source);
                }

                function exec(cmd) {
                    connectSource(cmd);
                }
            }

            KCoreAddons.KUser { id: kuser }

            KItemModels.KSortFilterProxyModel {
                id: sortedAppsModel

                sortRoleName: {
                    var m = Plasmoid.configuration.allAppsSortMode;
                    if (m === 4) return "description";
                    if (m === 2 || m === 3) return "url";
                    return "display";
                }
                sortOrder: {
                    var m = Plasmoid.configuration.allAppsSortMode;
                    return (m === 1 || m === 3) ? Qt.DescendingOrder : Qt.AscendingOrder;
                }

                // Map a proxy row through to the source model so delegates
                // can call view.model.trigger(index, ...) uniformly whether
                // the model is the favorites model or this sorted proxy.
                function trigger(row, actionId, argument) {
                    var srcIdx = mapToSource(index(row, 0));
                    if (srcIdx.valid && sourceModel) {
                        return sourceModel.trigger(srcIdx.row, actionId, argument);
                    }
                    return false;
                }

                property var favoritesModel: sourceModel ? sourceModel.favoritesModel : null
            }

            Kicker.RecentUsageModel {
                id: recentUsage
                shownItems: Plasmoid.configuration.showRecentApps && Plasmoid.configuration.showRecentDocs
                    ? Kicker.RecentUsageModel.AppsAndDocs
                    : Plasmoid.configuration.showRecentApps
                        ? Kicker.RecentUsageModel.OnlyApps : Kicker.RecentUsageModel.OnlyDocs
                ordering: Kicker.RecentUsageModel.Recent
            }

            StartSearchField {
                id: startSearch
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: rootItem.margin

                onSearchTextChanged: {
                    // Explicitly push the query to Milou ResultsView.
                    searchPage.resultsView.queryString = startSearch.searchText;
                    // Reset scroll to top on new query — only when
                    // the search page is active to avoid warnings
                    // from setting properties on a non-visible view.
                    if (root.leftColumnState === 2) {
                        searchPage.resultsView.contentY = 0;
                        searchPage.resultsView.currentIndex = 0;
                    }
                }
                onSearchFocusResults: rootItem.focusActivePageResults()
                onSearchNavUp: {
                    if (root.leftColumnState === 0) root.pinnedPage?.navigateUp();
                    else if (root.leftColumnState === 1) allAppsPage.navigateUp();
                    else if (root.leftColumnState === 2) searchPage.navigateUp();
                }
                onSearchNavDown: {
                    if (root.leftColumnState === 0) root.pinnedPage?.navigateDown();
                    else if (root.leftColumnState === 1) allAppsPage.navigateDown();
                    else if (root.leftColumnState === 2) searchPage.navigateDown();
                }
                onSearchActivateFirstResult: {
                    rootItem.activateCurrentItem();
                }
                onSearchEscapePressed: {
                    if (startSearch.searchText !== "") {
                        startSearch.searchText = "";
                    } else {
                        root.closeMenu();
                    }
                }
                onTabOut: rootItem.focusActivePageResults()
            }

            Item {
                id: pageArea
                anchors.top: startSearch.bottom
                anchors.bottom: footer.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: rootItem.margin

                AllAppsPage {
                    id: allAppsPage
                    anchors.fill: parent
                    visible: root.leftColumnState !== 2
                    onKeyNavUpFromList: {
                        root.leftColumnState = 0;
                        allAppsPage.allAppsList.positionViewAtBeginning();
                        startSearch.focusSearch();
                    }

                    homeHeader: Component {
                        ColumnLayout {
                            width: allAppsPage.allAppsList.width
                            height: implicitHeight
                            spacing: Kirigami.Units.largeSpacing
                            property alias pinnedSectionItem: pinnedSection

                            PinnedPage {
                                id: pinnedSection
                                Layout.fillWidth: true
                                favoritesList.model: globalFavorites
                                onShowAllAppsRequested: {
                                    root.leftColumnState = 1;
                                    allAppsPage.scrollToAll();
                                    allAppsPage.tryActivate(0);
                                }
                                onKeyNavUpFromList: startSearch.focusSearch()
                            }

                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                text: i18n("Recent")
                                font.weight: Font.DemiBold
                                visible: Plasmoid.configuration.showRecentApps || Plasmoid.configuration.showRecentDocs
                            }

                            GridView {
                                id: recentGrid
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(2, Math.ceil(count / 2)) * cellHeight
                                cellWidth: Math.max(1, Math.floor(width / 2))
                                cellHeight: Math.max(48, Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.gridUnit)
                                visible: (Plasmoid.configuration.showRecentApps || Plasmoid.configuration.showRecentDocs) && count > 0
                                model: visible || Plasmoid.configuration.showRecentApps || Plasmoid.configuration.showRecentDocs
                                    ? recentUsage : null
                                clip: true
                                interactive: contentHeight > height
                                boundsBehavior: Flickable.StopAtBounds
                                currentIndex: -1
                                delegate: ListItemDelegate { iconSize: Kirigami.Units.iconSizes.smallMedium }
                            }

                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                text: i18n("No recent items")
                                color: Kirigami.Theme.disabledTextColor
                                visible: (Plasmoid.configuration.showRecentApps || Plasmoid.configuration.showRecentDocs) && recentGrid.count === 0
                            }

                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                Layout.bottomMargin: Kirigami.Units.smallSpacing
                                text: i18n("All")
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }

                SearchPage {
                    id: searchPage
                    anchors.fill: parent
                    visible: root.leftColumnState === 2
                    onContextMenuRequested: function(actions, x, y, context) {
                        var pos = searchPage.mapToItem(sharedContextMenu, x, y);
                        sharedContextMenu.open(actions, pos.x, pos.y, context);
                    }
                }
            }

            Rectangle {
                id: footer
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: footerRow.implicitHeight + rootItem.margin
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                               Kirigami.Theme.textColor.b, 0.035)

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: Kirigami.Theme.textColor
                    opacity: Theme.separatorOpacity
                }

                RowLayout {
                    id: footerRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: rootItem.margin
                    anchors.rightMargin: rootItem.margin
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents3.ToolButton {
                        id: accountButton
                        text: kuser.fullName || kuser.loginName
                        Layout.maximumWidth: rootItem.width * 0.32
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                        onClicked: {
                            executable.exec("systemsettings kcm_users");
                            root.closeMenu();
                        }
                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Item {
                                id: avatarArea
                                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                Layout.preferredHeight: Layout.preferredWidth
                                Image {
                                    id: userAvatar
                                    anchors.fill: parent
                                    source: kuser.faceIconUrl
                                    cache: false
                                    fillMode: Image.PreserveAspectCrop
                                    visible: status === Image.Ready
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: avatarArea.width
                                            height: avatarArea.height
                                            radius: width / 2
                                        }
                                    }
                                }
                                Kirigami.Icon {
                                    anchors.fill: parent
                                    source: "avatar-default"
                                    visible: userAvatar.status !== Image.Ready
                                }
                            }
                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                text: accountButton.text
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                            }
                        }
                        PlasmaComponents3.ToolTip { text: i18n("Account settings") }
                    }

                    Item { Layout.fillWidth: true }

                    SystemLocationsRow {
                        id: systemLocations
                        visible: Plasmoid.configuration.showRightColumn
                        Layout.fillWidth: visible
                        Layout.maximumWidth: implicitWidth
                        Layout.minimumWidth: 0
                        executable: executable
                    }

                    PlasmaComponents3.ToolButton {
                        id: powerButton
                        text: i18n("Power")
                        icon.name: "system-shutdown"
                        display: PlasmaComponents3.AbstractButton.IconOnly
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                        Layout.preferredHeight: Layout.preferredWidth
                        onClicked: {
                            powerMenu.visualParent = powerButton;
                            powerMenu.open();
                        }
                        PlasmaComponents3.ToolTip { text: parent.text }
                    }
                }
            }

            // ── Power options popup (in-dialog, not a separate window) ────
            ShutdownMenu {
                id: powerMenu
                anchors.fill: parent
                onClosed: {
                    startSearch.focusSearch();
                }
            }

            // ── Shared context menu for list delegates ─────────────────────
            ContextMenu {
                id: sharedContextMenu
                anchors.fill: parent
                onActionTriggered: function(actionId, argument, context) {
                    rootItem.handleContextAction(actionId, argument, context)
                }
            }

            function handleContextAction(actionId, argument, context) {
                // Milou runner actions: invoke the named action on the
                // current match via ResultsView.runAction().
                if (actionId === "_milou_runner_action" && context && context.kind === "milou") {
                    if (argument && typeof argument.actionIndex !== "undefined") {
                        searchPage.resultsView.currentIndex = argument.matchIndex
                        searchPage.resultsView.runAction(argument.actionIndex)
                    }
                    return
                }

                // "Open" fallback for results with no runner actions
                // (e.g. plain app launches from krunner_services).
                if (actionId === "_milou_open" && context && context.kind === "milou") {
                    if (argument) {
                        searchPage.resultsView.currentIndex = argument.matchIndex
                        searchPage.resultsView.runCurrentIndex(null)
                    }
                    return
                }

                var model = context ? (context.resolvedModel || context.model) : null;
                var idx = context ? (context.resolvedIndex !== undefined ? context.resolvedIndex : context.index) : -1;
                var close = (Tools.triggerAction(model, idx, actionId, argument) === true);
                if (close) {
                    root.closeMenu();
                }
            }

            function focusActivePageResults() {
                if (root.leftColumnState === 0) {
                    root.pinnedPage?.tryActivate(0);
                } else if (root.leftColumnState === 1) {
                    allAppsPage.tryActivate(0);
                } else {
                    searchPage.tryActivate(0, 0);
                }
            }

            function activateCurrentItem() {
                if (root.leftColumnState === 0) {
                    root.pinnedPage?.activateCurrent();
                } else if (root.leftColumnState === 1) {
                    allAppsPage.activateCurrent();
                } else if (root.leftColumnState === 2) {
                    searchPage.activateCurrent();
                }
            }

            // App lookup for search-result context menus: given a display
            // name, find the matching row in sortedAppsModel so the menu can
            // offer the same actions (and trigger them on the right row) as
            // the All Apps list.
            //
            // Scans the helper Repeater's live delegates on demand rather than
            // caching: when the proxy re-sorts it rebinds model data onto the
            // existing delegates, so any cache keyed at creation time goes
            // stale. One linear scan per right-click is negligible.
            // Returns { row, favoriteId, url, actionList } or null.
            function lookupAppByDisplayName(displayName) {
                if (!displayName) return null;
                for (let i = 0; i < appLookupRepeater.count; ++i) {
                    const item = appLookupRepeater.itemAt(i) as AppLookupEntry;
                    if (item && item.displayName === displayName) {
                        return {
                            row: item.index,
                            favoriteId: item.favoriteId,
                            url: item.url,
                            actionList: item.actionList
                        };
                    }
                }
                return null;
            }

            // Off-screen helper that exposes sortedAppsModel's roles by name
            // (QAbstractItemModel roleNames() aren't reachable from QML). A
            // Repeater, not a ListView: it instantiates ALL delegates, while a
            // ListView only creates the ones near its viewport.
            Column {
                x: -9999
                y: -9999
                width: 0
                height: 0
                visible: true

                Repeater {
                    id: appLookupRepeater
                    model: sortedAppsModel
                    delegate: AppLookupEntry {}
                }
            }

            // ── Single global keyboard handler ─────────────────────────────
            //
            // Registered once on rootItem. Any printable character typed
            // anywhere in the menu appends to the search field and switches
            // to the search page. Escape/Backspace route to search or close.
            // Navigation keys (Tab, arrows, Enter) are left for children to
            // handle, and only reach here if no child consumed them.
            Keys.onPressed: event => {

                // Ctrl+digit launches a pinned favorite (1..9).
                if (event.modifiers === Qt.ControlModifier) {
                    var digit = event.key - Qt.Key_1;
                    if (digit >= 0 && digit <= 8) {
                        var count = globalFavorites.count;
                        if (digit < count) {
                            event.accepted = true;
                            globalFavorites.trigger(digit, "", null);
                            root.closeMenu();
                        }
                        return;
                    }
                }

                // Ignore pure modifier presses.
                if (event.key === Qt.Key_Shift || event.key === Qt.Key_Control
                        || event.key === Qt.Key_Alt || event.key === Qt.Key_Meta
                        || event.key === Qt.Key_AltGr) {
                    return;
                }

                // Let Tab/Backtab navigate the focus chain normally.
                if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                    return;
                }

                if (event.key === Qt.Key_Escape) {
                    event.accepted = true;
                    if (root.searching) {
                        reset();
                    } else if (root.leftColumnState === 1) {
                        root.leftColumnState = 0;
                        startSearch.focusSearch();
                    } else {
                        root.closeMenu();
                    }
                    return;
                }

                // Backspace from a list: delete last search char.
                if (event.key === Qt.Key_Backspace) {
                    event.accepted = true;
                    startSearch.searchText = startSearch.searchText.slice(0, -1);
                    return;
                }

                // Arrow / Enter / Page / Home / End are navigation: let the
                // focused child handle them.
                if (event.key === Qt.Key_Up || event.key === Qt.Key_Down
                        || event.key === Qt.Key_Left || event.key === Qt.Key_Right
                        || event.key === Qt.Key_Enter || event.key === Qt.Key_Return
                        || event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown
                        || event.key === Qt.Key_Home || event.key === Qt.Key_End) {
                    return;
                }

                // Any other printable character: append directly to the
                // searchText property (aliased to the TextField's text).
                // This works regardless of which item has focus — no need
                // to steal focus or guard on activeFocus.  The onTextChanged
                // → onSearchingChanged chain handles the page switch.
                // When the search field itself has focus it handles its own
                // input natively and this handler never fires.
                if (event.text !== "" && event.text !== "\t"
                        && !(event.modifiers & Qt.ControlModifier)) {
                    event.accepted = true;
                    startSearch.searchText = startSearch.searchText + event.text;
                }
            }
        }

        function setModels() {
            sortedAppsModel.sourceModel = findRowModel(rootModel, "KICKER_ALL_MODEL");
            allAppsPage.allAppsList.model = sortedAppsModel;
        }

        // Locate a rootModel child row by its description.  The Kicker
        // models expose "description" as a Q_PROPERTY (not a data role),
        // so we read it off the model returned by modelForRow().
        function findRowModel(parentModel, description) {
            if (!parentModel) return null;
            for (var i = 0; i < parentModel.rowCount(); i++) {
                var m = parentModel.modelForRow(i);
                if (m && m.description === description) {
                    return m;
                }
            }
            return null;
        }

        Component.onCompleted: {
            rootModel.refreshed.connect(setModels);
            reset();
            rootModel.refresh();
        }
    }
}
