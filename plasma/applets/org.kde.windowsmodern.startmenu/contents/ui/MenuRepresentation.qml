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

    // The compact representation is the actual Start button in the panel.
    // Keep this item visible: a hidden toggle item is not a reliable anchor.
    readonly property Item startButton: parent
    readonly property bool menuShown: root.visible

    // Native Plasma positions the popup relative to an Item in the panel's
    // window, including its real output and work area on Wayland and X11.
    // Shift only the horizontal anchor when selecting a screen alignment;
    // never assign global window coordinates to the dialog itself.
    Item {
        id: popupAnchor
        width: main.startButton ? main.startButton.width : 0
        height: main.startButton ? main.startButton.height : 0
    }

    function toggleMenu() {
        if (root.visible) {
            root.visible = false;
            return;
        }
        if (!startButton || startButton.width <= 0 || startButton.height <= 0)
            return;

        const horizontal = Plasmoid.location === PlasmaCore.Types.BottomEdge
                        || Plasmoid.location === PlasmaCore.Types.TopEdge;
        popupAnchor.x = 0;
        if (horizontal) {
            const pos = startButton.mapToGlobal(0, 0);
            popupAnchor.x = PopupPosition.horizontalAnchorOffset(
                Plasmoid.configuration.displayPosition, Plasmoid.screenGeometry,
                { x: pos.x, width: startButton.width });
        }
        root.visible = true;
    }

    Plasmoid.status: root.visible ? PlasmaCore.Types.RequiresAttentionStatus : PlasmaCore.Types.PassiveStatus

    PlasmaCore.Dialog {
        id: root

        objectName: "popupWindow"
        // AppletPopup establishes the Plasma shell popup role before the
        // window is mapped. Dialog uses visualParent for placement on show
        // and resize, rather than racing the compositor with x/y writes.
        type: PlasmaCore.Dialog.AppletPopup
        flags: Qt.Dialog
        visualParent: popupAnchor
        location: Plasmoid.location
        floating: Kirigami.Units.smallSpacing
        visible: false
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
        property bool showMoreRecent: false

        onSearchingChanged: {
            if (searching) {
                allAppsPage.resetCategory();
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
                reset();
            } else {
                leftColumnState = 0;
                sharedContextMenu.close();
                powerMenu.close();
            }
        }

        function reset() {
            startSearch.searchText = "";
            leftColumnState = 0;
            showMoreRecent = false;
            // Nothing highlighted until hovered or picked with the arrow keys,
            // as on Windows (a ListView makes its first item current as soon
            // as it has items, so the first pinned app always looked selected).
            if (root.pinnedPage) {
                root.pinnedPage.favoritesList.currentIndex = -1;
                root.pinnedPage.favoritesList.positionViewAtBeginning();
            }
            allAppsPage.resetCategory();
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

        FocusScope {
            id: rootItem

            readonly property int margin: 28
            readonly property rect screen: Plasmoid.screenGeometry
            readonly property bool largeLayout: Plasmoid.configuration.startMenuSize === 2
                || (Plasmoid.configuration.startMenuSize === 0 && screen.width >= 1440)
            readonly property bool showRecentSection: Plasmoid.configuration.showRecentSection
                && (Plasmoid.configuration.showRecentApps || Plasmoid.configuration.showRecentDocs)
            readonly property int wantedWidth: largeLayout ? 768 : 560
            readonly property int wantedHeight: largeLayout ? 720 : 640
            width: Math.max(1, Math.min(wantedWidth, screen.width > 0 ? screen.width - 2 * margin : wantedWidth))
            height: Math.max(1, Math.min(wantedHeight, screen.height > 0 ? screen.height - 3 * margin : wantedHeight))
            focus: true

            // Note: do NOT auto-redirect to the search field here.
            // onFocusChanged fires when any child calls forceActiveFocus(),
            // and stealing focus back makes it impossible to type from lists.
            // Initial search focus is handled by reset().

            Plasma5Support.DataSource {
                id: commandSource
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

            // KDE supplies the application categories and their translated names.
            // Flatten only the nested entries inside each category, not the root.
            Kicker.AppsModel {
                id: nativeCategoryModel
                flat: true
                sorted: true
                showTopLevelItems: true
                showSeparators: false
                appletInterface: kicker
            }

            Connections {
                target: nativeCategoryModel
                function onModelAboutToBeReset() {
                    allAppsPage.resetCategory();
                }
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
                anchors.topMargin: 16

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
                onSearchNavUp: rootItem.navigateFromSearch(-1)
                onSearchNavDown: rootItem.navigateFromSearch(1)
                onSearchActivateFirstResult: {
                    rootItem.activateCurrentItem();
                }
                onSearchEscapePressed: {
                    if (powerMenu.opened) {
                        powerMenu.close();
                    } else if (startSearch.searchText !== "") {
                        root.reset();
                    } else if (allAppsPage.inCategory) {
                        allAppsPage.backToCategories();
                    } else if (root.leftColumnState === 1) {
                        root.leftColumnState = 0;
                        allAppsPage.allAppsList.positionViewAtBeginning();
                        startSearch.focusSearch();
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
                anchors.topMargin: 22
                anchors.bottomMargin: 0

                AllAppsPage {
                    id: allAppsPage
                    anchors.fill: parent
                    visible: root.leftColumnState !== 2
                    showAllSection: Plasmoid.configuration.showAllSection
                    flatModel: sortedAppsModel
                    categoryModel: nativeCategoryModel
                    categoryMode: Plasmoid.configuration.allAppsViewMode === 2
                    gridMode: Plasmoid.configuration.allAppsViewMode === 1
                    onKeyNavUpFromList: {
                        root.leftColumnState = 0;
                        allAppsPage.allAppsList.positionViewAtBeginning();
                        startSearch.focusSearch();
                    }

                    homeHeader: Component {
                        ColumnLayout {
                            width: allAppsPage.allAppsList.contentColumnWidth
                            height: implicitHeight
                            spacing: 20
                            property alias pinnedSectionItem: pinnedSection

                            PinnedPage {
                                id: pinnedSection
                                Layout.fillWidth: true
                                visible: Plasmoid.configuration.showPinnedSection && favoritesList.count > 0
                                favoritesList.model: globalFavorites
                                onShowAllAppsRequested: {
                                    root.leftColumnState = 1;
                                    allAppsPage.scrollToAll();
                                    allAppsPage.tryActivate(0);
                                }
                                onKeyNavUpFromList: startSearch.focusSearch()
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: rootItem.showRecentSection && recentGrid.count > 0
                                PlasmaComponents3.Label {
                                    Layout.fillWidth: true
                                    text: i18n("Recent")
                                    Accessible.description: i18n("Recently used applications and documents")
                                    font.weight: Font.DemiBold
                                }
                                AToolButton {
                                    visible: recentGrid.count > recentGrid.recentColumns * 2
                                    flat: true
                                    linkStyle: true
                                    iconName: root.showMoreRecent ? "go-up" : "go-next"
                                    text: root.showMoreRecent ? i18n("Show less") : i18n("More")
                                    onClicked: root.showMoreRecent = !root.showMoreRecent
                                }
                            }

                            GridView {
                                id: recentGrid
                                Layout.fillWidth: true
                                readonly property int recentColumns: rootItem.largeLayout ? 3 : 2
                                Layout.preferredHeight: (root.showMoreRecent
                                    ? Math.ceil(count / recentColumns) : Math.min(2, Math.ceil(count / recentColumns))) * cellHeight
                                cellWidth: Math.max(1, Math.floor(width / recentColumns))
                                cellHeight: 40
                                visible: rootItem.showRecentSection && count > 0
                                model: rootItem.showRecentSection ? recentUsage : null
                                clip: true
                                // The outer list is the only vertical scroller.
                                interactive: false
                                boundsBehavior: Flickable.StopAtBounds
                                currentIndex: -1
                                delegate: ListItemDelegate { iconSize: Kirigami.Units.iconSizes.smallMedium }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: Plasmoid.configuration.showAllSection
                                Layout.bottomMargin: Kirigami.Units.smallSpacing
                                spacing: Kirigami.Units.smallSpacing

                                PlasmaComponents3.Label {
                                    Layout.fillWidth: true
                                    text: i18n("All")
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    font.weight: Font.DemiBold
                                }

                                PlasmaComponents3.Button {
                                    id: viewSelector
                                    Layout.preferredWidth: Math.max(132, implicitWidth)
                                    Layout.preferredHeight: 30
                                    readonly property var modes: [i18n("List"), i18n("Grid"), i18n("Category")]
                                    text: i18n("View: %1", modes[Plasmoid.configuration.allAppsViewMode] || modes[0])
                                    contentItem: RowLayout {
                                        spacing: 6
                                        PlasmaComponents3.Label {
                                            Layout.fillWidth: true
                                            text: viewSelector.text
                                            horizontalAlignment: Text.AlignRight
                                        }
                                        Kirigami.Icon {
                                            Layout.preferredWidth: 12
                                            Layout.preferredHeight: 12
                                            source: "go-down-symbolic"
                                        }
                                    }
                                    background: Rectangle {
                                        radius: 4
                                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                            Kirigami.Theme.textColor.b, viewSelector.hovered || viewSelector.activeFocus ? 0.06 : 0)
                                    }
                                    onClicked: modeMenu.open()
                                    function choose(index) {
                                        root.leftColumnState = 1;
                                        allAppsPage.resetCategory();
                                        Plasmoid.configuration.allAppsViewMode = index;
                                        Qt.callLater(allAppsPage.focusFirstApp);
                                    }

                                    Menu {
                                        id: modeMenu
                                        x: viewSelector.width - width
                                        y: viewSelector.height + 4
                                        width: 148
                                        padding: 4
                                        background: Rectangle {
                                            radius: 8
                                            color: Kirigami.Theme.backgroundColor
                                            border.width: 1
                                            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                                Kirigami.Theme.textColor.b, 0.12)
                                        }
                                        component ModeItem: MenuItem {
                                            required property int mode
                                            implicitHeight: 36
                                            leftPadding: 32
                                            rightPadding: 10
                                            text: viewSelector.modes[mode]
                                            indicator: Kirigami.Icon {
                                                x: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 13
                                                height: 13
                                                source: "emblem-ok-symbolic"
                                                visible: Plasmoid.configuration.allAppsViewMode === mode
                                            }
                                            contentItem: PlasmaComponents3.Label {
                                                text: parent.text
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            background: Rectangle {
                                                radius: 4
                                                color: parent.highlighted
                                                    ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                                        Kirigami.Theme.textColor.b, 0.08) : "transparent"
                                            }
                                            onTriggered: viewSelector.choose(mode)
                                        }
                                        ModeItem { mode: 2 }
                                        ModeItem { mode: 1 }
                                        ModeItem { mode: 0 }
                                    }
                                }
                            }
                        }
                    }
                }

                SearchPage {
                    id: searchPage
                    anchors.fill: parent
                    visible: root.leftColumnState === 2
                    onFocusSearchRequested: startSearch.focusSearch()
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
                height: 56
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
                    anchors.leftMargin: 28
                    anchors.rightMargin: 28
                    spacing: 8

                    PlasmaComponents3.ToolButton {
                        id: accountButton
                        text: Plasmoid.configuration.hideAccountIdentity ? "" : (kuser.fullName || kuser.loginName)
                        Layout.maximumWidth: rootItem.width * 0.32
                        Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignVCenter
                        Accessible.name: i18n("Account")
                        Accessible.description: accountButton.text || i18n("Account")
                        onClicked: {
                            powerMenu.accountMode = true;
                            powerMenu.visualParent = accountButton;
                            powerMenu.open();
                        }
                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Item {
                                id: avatarArea
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                Layout.alignment: Qt.AlignVCenter
                                Image {
                                    id: userAvatar
                                    anchors.fill: parent
                                    source: Plasmoid.configuration.hideAccountIdentity ? "" : kuser.faceIconUrl
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
                                Image {
                                    anchors.fill: parent
                                    source: Qt.resolvedUrl("default-account.svg")
                                    fillMode: Image.PreserveAspectFit
                                    visible: userAvatar.status !== Image.Ready
                                }
                            }
                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                visible: !Plasmoid.configuration.hideAccountIdentity
                                text: accountButton.text
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                            }
                        }
                        PlasmaComponents3.ToolTip { text: i18n("Account") }
                    }

                    Item { Layout.fillWidth: true }

                    SystemLocationsRow {
                        id: systemLocations
                        visible: Plasmoid.configuration.showRightColumn
                        Layout.fillWidth: visible
                        Layout.maximumWidth: implicitWidth
                        Layout.minimumWidth: 0
                        executable: commandSource
                        onShortcutInvoked: root.closeMenu()
                    }

                    PlasmaComponents3.ToolButton {
                        id: powerButton
                        text: i18n("Power")
                        icon.name: "system-shutdown-symbolic"
                        icon.width: 20
                        icon.height: 20
                        display: PlasmaComponents3.AbstractButton.IconOnly
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignVCenter
                        contentItem: Item {
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                roundToIconSize: false
                                isMask: true
                                color: Kirigami.Theme.textColor
                                source: "system-shutdown-symbolic"
                            }
                        }
                        onClicked: {
                            powerMenu.accountMode = false;
                            powerMenu.visualParent = powerButton;
                            powerMenu.open();
                        }
                        PlasmaComponents3.ToolTip { text: parent.text }
                    }
                }
            }

            // ── Account / power popup (reuse one in-dialog menu) ───────────
            ShutdownMenu {
                id: powerMenu
                anchors.fill: parent
                onClosed: {
                    if (root.visible && powerMenu.visualParent)
                        powerMenu.visualParent.forceActiveFocus();
                }
                onAccountSettingsRequested: {
                    commandSource.exec("systemsettings kcm_users");
                    root.closeMenu();
                }
                onActionInvoked: root.closeMenu()
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

            function hasPinnedApps() {
                return Plasmoid.configuration.showPinnedSection
                    && root.pinnedPage && root.pinnedPage.favoritesList.count > 0;
            }

            function navigateFromSearch(direction) {
                if (root.leftColumnState === 0 && !hasPinnedApps())
                    root.leftColumnState = 1;
                const page = root.leftColumnState === 0 ? root.pinnedPage
                           : root.leftColumnState === 1 ? allAppsPage : searchPage;
                if (!page)
                    return;
                if (direction < 0)
                    page.navigateUp();
                else
                    page.navigateDown();
                focusActivePageResults();
            }

            function focusActivePageResults() {
                if (root.leftColumnState === 0 && !hasPinnedApps())
                    root.leftColumnState = 1;
                if (root.leftColumnState === 0) {
                    root.pinnedPage.tryActivate(Math.max(0, root.pinnedPage.favoritesList.currentIndex));
                } else if (root.leftColumnState === 1 && allAppsPage.allAppsList.count > 0) {
                    allAppsPage.tryActivate(Math.max(0, allAppsPage.activeView.currentIndex));
                } else if (root.leftColumnState === 2 && searchPage.resultsView.count > 0) {
                    searchPage.tryActivate(Math.max(0, searchPage.resultsView.currentIndex), 0);
                } else {
                    accountButton.forceActiveFocus();
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
                if (powerMenu.opened) {
                    // The footer popup owns input until dismissed.
                    event.accepted = true;
                    if (event.key === Qt.Key_Escape)
                        powerMenu.close();
                    return;
                }

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
                    if (powerMenu.opened) {
                        powerMenu.close();
                    } else if (root.searching) {
                        root.reset();
                    } else if (root.leftColumnState === 1 && allAppsPage.inCategory) {
                        allAppsPage.backToCategories();
                    } else if (root.leftColumnState === 1) {
                        root.leftColumnState = 0;
                        allAppsPage.allAppsList.positionViewAtBeginning();
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
            allAppsPage.resetCategory();
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
