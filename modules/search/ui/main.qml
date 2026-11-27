/*
    SPDX-FileCopyrightText: 2026 Jeysef <jeysef@users.noreply.github.com>
    SPDX-License-Identifier: GPL-3.0-or-later

    Windows 11 taskbar Search (optional; not on the default panel). By
    default the search box: a pill with a magnifier and "Search"
    (SearchBox.qml); "Search icon only" is a setting, and vertical panels
    always get the icon. Either opens the Windows Modern Start menu's
    search surface through its native Applet actions on the same panel.
    The launcher owns the search model and editor; this applet mirrors
    state and supplies the panel anchor without a second backend.

    This applet must not provide org.kde.plasma.launchermenu itself.
*/

import QtQuick
import QtQuick.Layouts
import QtQml.Models

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool horizontal: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    readonly property int searchMode: Math.max(0, Math.min(2,
        Number(Plasmoid.configuration.searchMode) || 0))

    // Keep the open action and mirrored state from the same ready provider.
    // The panel list alone does not notify when a launcher registers its
    // actions later or its representation is reconstructed.
    readonly property var startProviders: {
        const providers = [];
        const applets = Plasmoid.containment ? Plasmoid.containment.applets : [];
        for (const applet of applets) {
            if (applet && applet.pluginName === "org.kde.windowsmodern.startmenu")
                providers.push(applet);
        }
        return providers;
    }
    property var openSearchAction: null
    property var searchStateAction: null
    readonly property bool searchSelected: !!openSearchAction?.enabled && !!searchStateAction?.enabled
    readonly property string queryText: searchSelected ? (searchStateAction?.queryText ?? "") : ""
    readonly property int queryCursor: searchSelected ? (searchStateAction?.queryCursor ?? 0) : 0
    readonly property bool queryFocused: searchSelected && (searchStateAction?.queryFocused ?? false)

    function refreshSearchState(): void {
        let open = null;
        let state = null;
        for (const applet of root.startProviders) {
            if (!applet || applet.destroyed === true)
                continue;
            const action = applet.internalAction("windowsModernSearch");
            if (action && action.enabled) {
                open = action;
                state = applet.internalAction("windowsModernSearchSelected");
                break;
            }
        }
        root.openSearchAction = open;
        root.searchStateAction = state;
    }

    onStartProvidersChanged: Qt.callLater(root.refreshSearchState)

    // One event-driven observer per Start applet, normally just one.
    // Observe action replacement as well as readiness, with no polling.
    Instantiator {
        model: root.startProviders
        delegate: QtObject {
            id: watcher
            required property var modelData
            property var action: null

            function refresh(): void {
                action = modelData && modelData.destroyed !== true
                    ? modelData.internalAction("windowsModernSearch") : null;
                Qt.callLater(root.refreshSearchState);
            }

            property Connections providerEvents: Connections {
                target: watcher.modelData
                function onInternalActionsChanged() { watcher.refresh(); }
                function onDestroyedChanged() { watcher.refresh(); }
            }

            property Connections actionEvents: Connections {
                target: watcher.action
                function onEnabledChanged() { Qt.callLater(root.refreshSearchState); }
                function onDestroyed() { Qt.callLater(root.refreshSearchState); }
            }

            Component.onCompleted: refresh()
        }
    }

    function openSearch(): void {
        // Re-resolve synchronously before activation in case a deferred
        // panel/action notification has not yet been delivered.
        refreshSearchState();
        const action = root.openSearchAction;
        if (!action || !action.enabled) {
            console.warn("Windows Modern Search requires a ready Windows Modern Start applet on the same panel.");
            return;
        }
        // New Start versions accept the real source rectangle; older
        // versions still respond to the original action.
        if ("searchAnchor" in action && "taskbarBox" in action) {
            const surface = searchBox.surfaceRect;
            const p = root.mapToGlobal(root.showBox ? surface.x : 0, 0);
            action.searchAnchor = {x: p.x, width: Math.max(1, root.showBox ? surface.width : root.width)};
            action.taskbarBox = root.showBox && root.searchMode === 0;
        }
        action.trigger();
    }

    // searchMode (contents/config/main.xml), as Windows' Settings >
    // Taskbar > Search names them: 0 box, 1 icon and label, 2 icon only.
    readonly property bool showBox: searchMode !== 2 && !vertical

    preferredRepresentation: fullRepresentation
    Plasmoid.icon: searchBox.iconSource
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.onActivated: openSearch()

    // The box is as wide as SearchBox asks for at the panel's thickness.
    // The icon is a square cell, like the task buttons: as wide as a
    // horizontal panel is thick, as tall as a vertical panel is wide. On
    // the desktop both are 48 px tall.
    Layout.minimumWidth: showBox ? Math.min(searchBox.preferredWidth, Math.max(1, height))
                                 : (horizontal ? height : (vertical ? 0 : Kirigami.Units.iconSizes.huge))
    Layout.maximumWidth: showBox ? searchBox.preferredWidth
                                 : (horizontal ? Layout.minimumWidth : Number.POSITIVE_INFINITY)
    Layout.preferredWidth: showBox ? searchBox.preferredWidth : Layout.minimumWidth
    Layout.fillWidth: showBox && horizontal
    Layout.minimumHeight: vertical ? width : (horizontal ? 0 : Kirigami.Units.iconSizes.huge)
    Layout.maximumHeight: vertical ? width : Number.POSITIVE_INFINITY
    Layout.preferredHeight: Layout.minimumHeight

    // i18ndc("plasma_applet_org.kde.windowsmodern.search", ) is put into the applet's context by Plasma, where qmllint
    // cannot see it.
    // qmllint disable unqualified
    SearchBox {
        id: searchBox
        anchors.fill: parent
        visible: root.showBox
        styleMode: root.searchMode === 1 ? 1 : 0
        selected: root.searchSelected
        queryText: root.queryText
        queryCursor: root.queryCursor
        queryFocused: root.queryFocused
        iconName: "search"
        text: i18ndc("plasma_applet_org.kde.windowsmodern.search", "@action:button taskbar search box", "Search")
        placeholder: i18ndc("plasma_applet_org.kde.windowsmodern.search", "@info:placeholder taskbar search box", "Search")
        description: i18ndc("plasma_applet_org.kde.windowsmodern.search", "@info:tooltip", "Open Start and search")
        onTriggered: root.openSearch()
    }

    TaskbarButton {
        anchors.fill: parent
        visible: !root.showBox
        iconName: searchBox.iconSource
        hoverIconName: searchBox.hoverIconSource
        hoverIconIsMask: searchBox.hoverIconIsMask
        selectedIconName: searchBox.hoverIconSource
        selectedIconIsMask: searchBox.hoverIconIsMask
        iconIsMask: searchBox.iconIsMask
        selected: root.searchSelected
        text: i18ndc("plasma_applet_org.kde.windowsmodern.search", "@action:button taskbar button", "Search")
        description: i18ndc("plasma_applet_org.kde.windowsmodern.search", "@info:tooltip", "Open Start and search")
        onTriggered: root.openSearch()

        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            mainText: i18ndc("plasma_applet_org.kde.windowsmodern.search", "@info:tooltip", "Search")
            textFormat: Text.PlainText
        }
    }
    // qmllint enable unqualified

    Component.onCompleted: {
        Qt.callLater(root.refreshSearchState);
        // Mode 1 used to mean icon-only. Preserve existing user choices while
        // assigning the new compact icon-and-label mode its own value.
        if (!Plasmoid.configuration.searchModesMigrated) {
            if (Plasmoid.configuration.searchMode === 1)
                Plasmoid.configuration.searchMode = 2;
            Plasmoid.configuration.searchModesMigrated = true;
        }
    }
}
