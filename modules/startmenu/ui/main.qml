/***************************************************************************
 *   Ported from com.jeysef.windowsmodernstartmenu
 *   License: GPL-3.0-or-later
 *   Author: Jeysef
 ***************************************************************************/

import QtQuick

import org.kde.plasma.plasmoid

import org.kde.plasma.core as PlasmaCore

import org.kde.plasma.private.kicker 0.1 as Kicker

PlasmoidItem {

    id: kicker

    anchors.fill: parent

    preferredRepresentation: compactRep
    compactRepresentation: compactRep
    fullRepresentation: compactRep

    function action_menuedit() {
        processRunner.runMenuEditor();
    }

    Component {
        id: compactRep
        CompactRepresentation {
            launcherApplet: kicker
            launcherRootModel: rootModel
            launcherFavorites: kicker.globalFavorites
        }
    }

    // The native applet owns the actions for its entire lifetime. The
    // representation may be created later or replaced by the framework.
    readonly property var startButton: compactRepresentationItem || fullRepresentationItem
    readonly property MenuRepresentation searchWindow: startButton?.dashWindow ?? null

    Plasmoid.onActivated: {
        if (kicker.startButton)
            kicker.startButton.activateStart();
    }

    PlasmaCore.Action {
        id: openSearchAction
        enabled: kicker.searchWindow !== null
        property var searchAnchor: null
        property bool taskbarBox: false
        text: i18n("Search")
        onTriggered: {
            const window = kicker.searchWindow;
            const anchor = searchAnchor;
            const box = taskbarBox;
            searchAnchor = null;
            taskbarBox = false;
            if (window)
                window.openSearch(anchor, box);
        }
    }

    PlasmaCore.Action {
        id: searchStateAction
        enabled: kicker.searchWindow?.taskbarSearchActive ?? false
        readonly property string queryText: kicker.searchWindow?.taskbarQuery ?? ""
        readonly property int queryCursor: kicker.searchWindow?.taskbarCursor ?? 0
        readonly property bool queryFocused: kicker.searchWindow?.taskbarEditorFocused ?? false
    }

    property QtObject globalFavorites: rootModel.favoritesModel
    property QtObject systemFavorites: rootModel.systemFavoritesModel

    Plasmoid.icon: Plasmoid.configuration.useCustomButtonImage
                   ? Plasmoid.configuration.customButtonImage
                   : Plasmoid.configuration.icon

    onSystemFavoritesChanged: {
        if (systemFavorites) {
            systemFavorites.favorites = Plasmoid.configuration.favoriteSystemActions;
        }
    }

    Kicker.RootModel {
        id: rootModel

        autoPopulate: false

        appNameFormat: 0
        flat: true
        sorted: true
        showAllAppsCategorized: false
        showSeparators: false
        appletInterface: kicker
        showAllApps: true
        showRecentApps: Plasmoid.configuration.showRecentApps
        showRecentDocs: Plasmoid.configuration.showRecentDocs
        showPowerSession: false

        onShowRecentAppsChanged: {
            Plasmoid.configuration.showRecentApps = showRecentApps;
        }

        onShowRecentDocsChanged: {
            Plasmoid.configuration.showRecentDocs = showRecentDocs;
        }

        Component.onCompleted: {
            favoritesModel.initForClient("org.kde.plasma.kicker.favorites.instance-" + Plasmoid.id)

            if (!Plasmoid.configuration.favoritesPortedToKAstats) {
                if (favoritesModel.count < 1) {
                    favoritesModel.portOldFavorites(Plasmoid.configuration.favoriteApps);
                }
                Plasmoid.configuration.favoritesPortedToKAstats = true;
            }
        }
    }

    Connections {
        target: globalFavorites

        function onFavoritesChanged() {
            Plasmoid.configuration.favoriteApps = target.favorites;
        }
    }

    Connections {
        target: systemFavorites

        function onFavoritesChanged() {
            if (Plasmoid.configuration && target)
                Plasmoid.configuration.favoriteSystemActions = target.favorites;
        }
    }

    Connections {
        target: Plasmoid.configuration

        function onFavoriteAppsChanged() {
            globalFavorites.favorites = Plasmoid.configuration.favoriteApps;
        }

        function onFavoriteSystemActionsChanged() {
            systemFavorites.favorites = Plasmoid.configuration.favoriteSystemActions;
        }

        function onHiddenApplicationsChanged() {
            rootModel.refresh();
        }
    }

    Kicker.RunnerModel {
        id: runnerModel

        appletInterface: kicker

        favoritesModel: globalFavorites

        // Always load the full runner set; the SearchPage filter pills
        // narrow results via Milou's singleRunner property instead of
        // rebuilding this model.
        runners: ["krunner_services",
                  "baloosearch",
                  "bookmarks",
                  "krunner_systemsettings",
                  "krunner_sessions",
                  "krunner_powerdevil",
                  "calculator",
                  "unitconverter"]
    }

    Kicker.ProcessRunner {
        id: processRunner
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Edit Applications…")
            // KDE-only menu editor: retain the command without a substitute icon.
            icon.name: ""
            visible: Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
            onTriggered: processRunner.runMenuEditor()
        }
    ]

    Component.onCompleted: {
        Plasmoid.setInternalAction("windowsModernSearch", openSearchAction);
        Plasmoid.setInternalAction("windowsModernSearchSelected", searchStateAction);
        // Never force optional footer shortcuts on. Preserve saved choices.
        if (!Plasmoid.configuration.footerShortcutsMigrated)
            Plasmoid.configuration.footerShortcutsMigrated = true;
        if (Plasmoid.hasOwnProperty("activationTogglesExpanded")) {
            Plasmoid.activationTogglesExpanded = true;
        }
    }
}
