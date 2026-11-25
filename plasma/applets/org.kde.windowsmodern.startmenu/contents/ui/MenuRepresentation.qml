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
import QtQuick.Window
import QtQuick.Controls
import QtCore
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
import "code/popupGeometry.js" as PopupGeometry
import "code/colorType.js" as FooterColors

Item {
    id: main

    // The compact representation is the actual Start button in the panel.
    // Keep this item visible: a hidden toggle item is not a reliable anchor.
    readonly property Item startButton: parent
    readonly property bool menuShown: root.visible
    readonly property bool searchShown: root.visible && root.searching
    readonly property var panelWindow: startButton ? startButton.Window.window : null
    readonly property rect panelGeometry: panelWindow
        ? Qt.rect(panelWindow.x, panelWindow.y, panelWindow.width, panelWindow.height) : Qt.rect(0, 0, 0, 0)
    readonly property bool verticalPanel: Plasmoid.location === PlasmaCore.Types.LeftEdge
        || Plasmoid.location === PlasmaCore.Types.RightEdge
    readonly property real panelExtent: Math.max(0, verticalPanel
        ? (panelGeometry.width || startButton?.width || 0)
        : (panelGeometry.height || startButton?.height || 0))
    // Legacy Dialog does not track every panel move while mapped. Dismiss
    // safely during reconfiguration; the next open uses the new anchor.
    onPanelGeometryChanged: if (root && root.visible) root.closeMenu()

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
        if (!startButton || !popupAnchor.Window.window || !popupAnchor.visible
            || startButton.width <= 0 || startButton.height <= 0)
            return;

        updatePopupAnchor();
        root.visible = true;
    }

    function updatePopupAnchor() {
        if (!startButton || !popupAnchor.Window.window) return;
        const horizontal = Plasmoid.location === PlasmaCore.Types.BottomEdge
                        || Plasmoid.location === PlasmaCore.Types.TopEdge;
        const edge = Plasmoid.location === PlasmaCore.Types.BottomEdge ? "bottom"
            : Plasmoid.location === PlasmaCore.Types.TopEdge ? "top"
            : Plasmoid.location === PlasmaCore.Types.LeftEdge ? "left"
            : Plasmoid.location === PlasmaCore.Types.RightEdge ? "right" : "";
        const pos = startButton.mapToGlobal(0, 0);
        const offset = PopupGeometry.normalOffset(edge, panelGeometry,
            {x: pos.x, y: pos.y, width: startButton.width, height: startButton.height});
        popupAnchor.x = offset.x;
        popupAnchor.y = offset.y;
        if (horizontal) {
            popupAnchor.x = PopupPosition.horizontalAnchorOffset(
                Plasmoid.configuration.displayPosition, Plasmoid.screenGeometry,
                { x: pos.x, width: startButton.width }, panelGeometry,
                rootItem.width + root.margins.left + root.margins.right);
        }
    }

    // Both taskbar Search and Start's own input enter this same surface.
    function openSearch() {
        if (!root.visible) toggleMenu();
        if (!root.visible) return;
        root.searching = true;
        root.requestActivate();
        Qt.callLater(startSearch.focusSearch);
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
        floating: PopupGeometry.gap
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

        property bool searching: false

        // Keyboard target: 0 = pinned, 1 = all apps, 2 = search results.
        // Pinned and All now share the same scrollable home.
        readonly property var pinnedPage: allAppsPage.allAppsList.headerItem?.pinnedSectionItem ?? null
        property int leftColumnState: 0
        property bool showMoreRecent: false

        onSearchingChanged: {
            if (searching) {
                modeMenu.close();
                allAppsPage.resetCategory();
                allAppsPage.closeLetterIndex(false);
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
                searching = false;
                leftColumnState = 0;
                modeMenu.close();
                sharedContextMenu.close();
                powerMenu.close();
            }
        }

        function reset() {
            startSearch.searchText = "";
            searching = false;
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
            allAppsPage.closeLetterIndex(false);
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
            readonly property int wantedWidth: root.searching ? 776 : (largeLayout ? 768 : 560)
            readonly property int wantedHeight: root.searching ? 690 : (largeLayout ? 720 : 640)
            width: Math.max(1, Math.min(wantedWidth, screen.width > 0
                ? screen.width - (main.verticalPanel ? main.panelExtent : 0) - 2 * margin : wantedWidth))
            height: Math.max(1, Math.min(wantedHeight, screen.height > 0
                ? screen.height - (main.verticalPanel ? 0 : main.panelExtent) - 2 * margin : wantedHeight))
            focus: true
            onWidthChanged: if (root.visible) main.updatePopupAnchor()

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
                    if (typeof cmd !== "string" || !cmd.length)
                        return false;
                    connectSource(cmd);
                    return true;
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

            // KDE provides real freedesktop membership. WindowsCategories
            // maps it to Windows-style buckets instead of exposing KDE labels.
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
                id: categoryPopularity
                shownItems: Kicker.RecentUsageModel.OnlyApps
                ordering: Kicker.RecentUsageModel.Popular
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

                searchMode: root.searching
                onSearchRequested: root.searching = true
                onSearchTextChanged: {
                    if (startSearch.searchText.length > 0) root.searching = true;
                    sharedContextMenu?.close();
                    // Explicitly push the query to Milou ResultsView.
                    if (startSearch.searchText.length === 0)
                        searchPage.resultsView.singleRunner = "";
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
                    if (sharedContextMenu.opened) {
                        sharedContextMenu.close();
                    } else if (powerMenu.opened) {
                        powerMenu.close();
                    } else if (startSearch.searchText !== "") {
                        startSearch.searchText = "";
                        startSearch.focusSearch();
                    } else if (root.searching) {
                        root.closeMenu();
                    } else if (allAppsPage.letterIndexOpen) {
                        allAppsPage.closeLetterIndex(true);
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
                anchors.bottomMargin: root.searching ? 12 : 0

                AllAppsPage {
                    id: allAppsPage
                    anchors.fill: parent
                    visible: root.leftColumnState !== 2
                    scrollbarEdgeOffset: Math.max(0, rootItem.margin - 4)
                    showAllSection: Plasmoid.configuration.showAllSection
                    flatModel: sortedAppsModel
                    categoryModel: nativeCategoryModel
                    categoryUsageModel: categoryPopularity
                    categoryMode: Plasmoid.configuration.allAppsViewMode === 2
                    gridMode: Plasmoid.configuration.allAppsViewMode === 1
                    alphabeticalGrouping: Plasmoid.configuration.allAppsSortMode === 0
                        || Plasmoid.configuration.allAppsSortMode === 1
                    onAppContextMenuRequested: function(entry, x, y) {
                        const actions = Tools.buildAppActions(i18n, globalFavorites,
                            entry.favoriteId || "", entry.url || "", entry.actionList || null);
                        if (!actions.length) return;
                        const pos = allAppsPage.mapToItem(sharedContextMenu, x, y);
                        sharedContextMenu.open(actions, pos.x, pos.y, {
                            model: sortedAppsModel, index: entry.index
                        });
                    }
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
                                    text: i18n("Recommended")
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
                                readonly property int recentColumns: 2
                                Layout.preferredHeight: (root.showMoreRecent
                                    ? Math.ceil(count / recentColumns) : Math.min(2, Math.ceil(count / recentColumns))) * cellHeight
                                cellWidth: Math.max(1, Math.floor(width / recentColumns))
                                cellHeight: 48
                                visible: rootItem.showRecentSection && count > 0
                                model: rootItem.showRecentSection ? recentUsage : null
                                clip: true
                                // The outer list is the only vertical scroller.
                                interactive: false
                                boundsBehavior: Flickable.StopAtBounds
                                currentIndex: -1
                                delegate: ListItemDelegate { iconSize: 32; showDescription: true }
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
                                    onClicked: modeMenu.openAt(viewSelector)

                                }
                            }
                        }
                    }
                }

                Loader {
                    id: searchHome
                    anchors.fill: parent
                    active: root.visible && root.searching && startSearch.searchText.length === 0
                    visible: active
                    sourceComponent: SearchHome {
                        suggestedModel: Plasmoid.configuration.showSearchSuggestions
                            && (Plasmoid.configuration.showRecentApps || Plasmoid.configuration.showRecentDocs) ? recentUsage : null
                        topAppsModel: Plasmoid.configuration.showSearchTopApps
                            && Plasmoid.configuration.showRecentApps ? categoryPopularity : null
                        showQuickSearches: Plasmoid.configuration.showSearchQuickSearches
                        onSearchRequested: query => {
                            searchPage.resultsView.singleRunner = "krunner_systemsettings";
                            startSearch.searchText = query;
                            startSearch.focusSearch();
                        }
                        onApplicationActivated: root.closeMenu()
                    }
                }

                SearchPage {
                    id: searchPage
                    anchors.fill: parent
                    visible: root.searching && startSearch.searchText.length > 0
                    scrollbarEdgeOffset: Math.max(0, rootItem.margin - 4)
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
                visible: !root.searching
                height: visible ? 56 : 0
                color: "transparent"

                // Extend into the native frame inset without covering its border.
                Rectangle {
                    objectName: "wmStartFooterSurface"
                    x: 1 - root.margins.left
                    width: Math.max(0, footer.width + root.margins.left + root.margins.right - 2)
                    height: Math.max(0, footer.height + root.margins.bottom - 1)
                    radius: Math.max(0, root.margins.bottom - 1)
                    topLeftRadius: 0
                    topRightRadius: 0
                    color: FooterColors.footerTint(FooterColors.isDark(Kirigami.Theme.backgroundColor))
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: FooterColors.divider(FooterColors.isDark(Kirigami.Theme.backgroundColor))
                    }
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
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
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
                                    source: {
                                        // The imported green account glyph is not Windows' default Start avatar.
                                        return Qt.resolvedUrl("default-account.svg");
                                    }
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
                        Layout.fillWidth: false
                        Layout.preferredWidth: visible ? Math.min(implicitWidth, Math.floor(rootItem.width * 0.58)) : 0
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

            // Owned by the stable dialog, never by a disposable ListView header.
            ViewModeMenu {
                id: modeMenu
                parent: rootItem
                modes: [i18n("List"), i18n("Grid"), i18n("Category")]
                currentMode: Plasmoid.configuration.allAppsViewMode
                onModeChosen: index => {
                    if (index === Plasmoid.configuration.allAppsViewMode) return;
                    root.leftColumnState = 1;
                    allAppsPage.resetCategory();
                    Plasmoid.configuration.allAppsViewMode = index;
                    Qt.callLater(allAppsPage.focusFirstApp);
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
                if (searchHome.active) {
                    if (searchHome.item) searchHome.item.focusFirst();
                    return;
                }
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
                if (searchHome.active) {
                    if (searchHome.item) searchHome.item.focusFirst();
                    return;
                }
                if (root.leftColumnState === 0 && !hasPinnedApps())
                    root.leftColumnState = 1;
                if (root.leftColumnState === 0) {
                    root.pinnedPage.tryActivate(Math.max(0, root.pinnedPage.favoritesList.currentIndex));
                } else if (root.leftColumnState === 1 && allAppsPage.allAppsList.count > 0) {
                    allAppsPage.tryActivate(Math.max(0, allAppsPage.activeView.currentIndex));
                } else if (root.leftColumnState === 2 && searchPage.resultsView.count > 0) {
                    searchPage.tryActivate(Math.max(0, searchPage.resultsView.currentIndex), 0);
                } else if (!root.searching) {
                    accountButton.forceActiveFocus();
                }
            }

            function activateCurrentItem() {
                if (searchHome.active) return;
                if (root.leftColumnState === 0) {
                    root.pinnedPage?.activateCurrent();
                } else if (root.leftColumnState === 1) {
                    allAppsPage.activateCurrent();
                } else if (root.leftColumnState === 2) {
                    searchPage.activateCurrent();
                }
            }

            // Reuse the existing alphabetical snapshot. A second hidden
            // Repeater used to allocate one visual Item for every app.
            function lookupAppByUrls(urls) {
                return allAppsPage.lookupAppByUrls(urls);
            }

            // ── Single global keyboard handler ─────────────────────────────
            //
            // Registered once on rootItem. Any printable character typed
            // anywhere in the menu appends to the search field and switches
            // to the search page. Escape/Backspace route to search or close.
            // Navigation keys (Tab, arrows, Enter) are left for children to
            // handle, and only reach here if no child consumed them.
            Keys.onPressed: event => {
                if (sharedContextMenu.opened) {
                    event.accepted = true;
                    if (event.key === Qt.Key_Escape) sharedContextMenu.close();
                    return;
                }
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
                    } else if (root.searching && startSearch.searchText.length > 0) {
                        startSearch.searchText = "";
                        startSearch.focusSearch();
                    } else if (root.searching) {
                        root.closeMenu();
                    } else if (allAppsPage.letterIndexOpen) {
                        allAppsPage.closeLetterIndex(true);
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
