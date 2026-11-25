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
import org.kde.plasma.workspace.dbus as DBus
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool horizontal: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    readonly property int searchMode: Math.max(0, Math.min(2,
        Number(Plasmoid.configuration.searchMode) || 0))

    function openSearch(): void {
        const applets = Plasmoid.containment ? Plasmoid.containment.applets : [];
        for (const applet of applets) {
            if (!applet || applet.pluginName !== "org.kde.windowsmodern.startmenu") continue;
            const action = applet.internalAction("windowsModernSearch");
            if (action && action.enabled) {
                action.trigger();
                return;
            }
        }
        // A different launcher or an older Start version remains usable.
        DBus.SessionBus.asyncCall({
            service: "org.kde.plasmashell",
            path: "/PlasmaShell",
            iface: "org.kde.PlasmaShell",
            member: "activateLauncherMenu",
        });
    }

    // searchMode (contents/config/main.xml), as Windows' Settings >
    // Taskbar > Search names them: 0 "Search box", 1 "Search icon only".
    readonly property bool showBox: searchMode !== 2 && !vertical

    preferredRepresentation: fullRepresentation
    Plasmoid.icon: "search"
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

    // i18nc() is put into the applet's context by Plasma, where qmllint
    // cannot see it.
    // qmllint disable unqualified
    SearchBox {
        id: searchBox
        anchors.fill: parent
        visible: root.showBox
        styleMode: root.searchMode === 1 ? 1 : 0
        iconName: "search"
        text: i18nc("@action:button taskbar search box", "Search")
        placeholder: i18nc("@info:placeholder taskbar search box", "Search")
        description: i18nc("@info:tooltip", "Open Start and search")
        onTriggered: root.openSearch()
    }

    TaskbarButton {
        anchors.fill: parent
        visible: !root.showBox
        iconName: searchBox.iconSource
        hoverIconName: searchBox.hoverIconSource
        iconIsMask: false
        text: i18nc("@action:button taskbar button", "Search")
        description: i18nc("@info:tooltip", "Open Start and search")
        onTriggered: root.openSearch()

        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            mainText: i18nc("@info:tooltip", "Search")
            textFormat: Text.PlainText
        }
    }
    // qmllint enable unqualified

    Component.onCompleted: {
        // Mode 1 used to mean icon-only. Preserve existing user choices while
        // assigning the new compact icon-and-label mode its own value.
        if (!Plasmoid.configuration.searchModesMigrated) {
            if (Plasmoid.configuration.searchMode === 1)
                Plasmoid.configuration.searchMode = 2;
            Plasmoid.configuration.searchModesMigrated = true;
        }
    }
}
