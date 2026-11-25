/*
    SPDX-FileCopyrightText: 2020 Konrad Materka <materka@gmail.com>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

//This object contains state of the SystemTray, mainly related to the 'expanded' state
QtObject {
    id: systemTrayState
    //true if System Tray is 'expanded'. It may be when:
    // - there is an active applet or
    // - 'Status and Notification' with hidden items is shown
    property bool expanded: false
    property bool popupVisible: false
    // Overflow and Quick Settings are distinct homes of the same native popup.
    // Keep the originating home when navigating to a child applet page.
    property bool overflowMode: false
    property bool quickSettingsRoute: false
    readonly property bool overflowOpen: expanded && overflowMode && !activeApplet
    readonly property bool quickSettingsOpen: expanded && !overflowMode && !activeApplet

    function toggleHome(overflow, wasOpen) {
        const close = wasOpen === undefined
            ? (overflow ? overflowOpen : quickSettingsOpen) : wasOpen;
        if (close) {
            expanded = false;
            return;
        }
        // Close the old native surface before changing the home and its
        // visual parent. The newly mapped popup then uses the new anchor.
        // This also handles a pending native deactivation before its sync.
        if (expanded)
            expanded = false;
        overflowMode = overflow;
        quickSettingsRoute = !overflow;
        setActiveApplet(null);
        expanded = true;
    }
    //set when there is an applet selected
    property Item activeApplet
    property bool changingApplet: false

    //allow expanded change only when activated at least once
    //this is to suppress expanded state change during Plasma startup
    property bool acceptExpandedChange: false

    // These properties allow us to keep track of where the expanded applet
    // was and is on the panel, allowing PlasmoidPopupContainer.qml to animate
    // depending on their locations.
    property int oldVisualIndex: -1
    property int newVisualIndex: -1

    function setActiveApplet(applet, visualIndex, origin) {

        // Applets which prefer to always show their full
        // representation will always be expanded, there's
        // no need to activate them.
        if (changingApplet || applet === activeApplet) return;
        if (applet && applet.preferredRepresentation == applet.fullRepresentation) return;
        if (applet && applet.preferredRepresentation) return;

        if (visualIndex === undefined) {
            oldVisualIndex = -1
            newVisualIndex = -1
        } else {
            oldVisualIndex = (activeApplet && activeApplet.status === PlasmaCore.Types.PassiveStatus) ? 9999 : newVisualIndex
            newVisualIndex = visualIndex
        }

        changingApplet = true;
        if (origin !== undefined) {
            overflowMode = origin === "overflow";
            quickSettingsRoute = origin === "quick";
        }
        const oldApplet = activeApplet;
        try {
            // The outgoing native view closes before the new page is shown.
            // Its expandedChanged handler must not close the new home.
            if (oldApplet)
                oldApplet.expanded = false;
            if (applet)
                applet.expanded = true;
            activeApplet = applet;
            if (applet)
                expanded = true;
        } finally {
            changingApplet = false;
        }
    }

    onExpandedChanged: {
        if (expanded) {
            Plasmoid.status = PlasmaCore.Types.RequiresAttentionStatus
        } else {
            Plasmoid.status = PlasmaCore.Types.PassiveStatus;
            if (activeApplet) {
                // if not expanded we don't have an active applet anymore
                setActiveApplet(null)
            }
            overflowMode = false
            quickSettingsRoute = false
        }
        acceptExpandedChange = false
        root.expanded = expanded
    }

    //listen on SystemTray AppletInterface signals
    readonly property Connections plasmoidConnections: Connections {
        target: Plasmoid
        //emitted when activation is requested, for example by using a global keyboard shortcut
        function onActivated() {
            systemTrayState.acceptExpandedChange = true
        }
    }

    readonly property Connections rootConnections: Connections {
        target: root
        function onExpandedChanged() {
            if (systemTrayState.acceptExpandedChange) {
                systemTrayState.expanded = root.expanded
            } else {
                root.expanded = systemTrayState.expanded
            }
        }
    }

    readonly property Connections activeAppletConnections: Connections {
        target: systemTrayState.activeApplet

        function onExpandedChanged() {
            if (!systemTrayState.changingApplet && systemTrayState.activeApplet
                    && !systemTrayState.activeApplet.expanded) {
                systemTrayState.expanded = false
            }
        }
    }
}
