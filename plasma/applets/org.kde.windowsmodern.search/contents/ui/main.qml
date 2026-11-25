/*
    SPDX-FileCopyrightText: 2026 Jeysef <jeysef@users.noreply.github.com>
    SPDX-License-Identifier: GPL-3.0-or-later

    Windows 11 taskbar Search (optional; not on the default panel). By
    default the search box: a pill with a magnifier and "Search"
    (SearchBox.qml); "Search icon only" is a setting, and vertical panels
    always get the icon. Either opens the Start menu, which focuses its
    search field, so typing searches straight away. It asks Plasma for "the launcher" exactly as
    the Meta key does (org.kde.PlasmaShell.activateLauncherMenu, see
    plasma-workspace shell/shellcorona.cpp), so it works with the Windows
    Modern Start menu, Kickoff, or any applet that provides
    org.kde.plasma.launchermenu on the active screen.

    This applet must not provide org.kde.plasma.launchermenu itself, or
    Plasma would "activate the launcher" by activating this button.
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool horizontal: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    readonly property int searchMode: Math.max(0, Math.min(2,
        Number(Plasmoid.configuration.searchMode) || 0))

    // A local action communicates popup state without polling or guessing from hover.
    property var searchStateAction: null
    readonly property bool searchSelected: searchStateAction ? searchStateAction.enabled : false
    readonly property string queryText: searchSelected ? (searchStateAction?.queryText ?? "") : ""
    readonly property int queryCursor: searchStateAction?.queryCursor ?? 0
    readonly property bool queryFocused: searchSelected && (searchStateAction?.queryFocused ?? false)

    function refreshSearchState(): void {
        const applets = Plasmoid.containment ? Plasmoid.containment.applets : [];
        for (const applet of applets) {
            if (applet && applet.pluginName === "org.kde.windowsmodern.startmenu") {
                root.searchStateAction = applet.internalAction("windowsModernSearchSelected");
                return;
            }
        }
        root.searchStateAction = null;
    }

    Connections {
        target: Plasmoid.containment
        ignoreUnknownSignals: true
        function onAppletsChanged() { Qt.callLater(root.refreshSearchState); }
    }

    function openSearch(): void {
        const applets = Plasmoid.containment ? Plasmoid.containment.applets : [];
        for (const applet of applets) {
            if (!applet || applet.pluginName !== "org.kde.windowsmodern.startmenu") continue;
            const action = applet.internalAction("windowsModernSearch");
            if (action && action.enabled) {
                root.searchStateAction = applet.internalAction("windowsModernSearchSelected");
                // New Start versions accept the real source rectangle; older
                // versions still respond to the original action.
                if ("searchAnchor" in action && "taskbarBox" in action) {
                    const inset = root.showBox ? searchBox.sideMargin : 0;
                    const p = root.mapToGlobal(inset, 0);
                    action.searchAnchor = {x: p.x, width: Math.max(1, root.width - 2 * inset)};
                    action.taskbarBox = root.showBox && root.searchMode === 0;
                }
                action.trigger();
                return;
            }
        }
        console.warn("Windows Modern Search requires the Windows Modern Start applet on the same panel.");
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
