// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root
    implicitWidth: 0
    implicitHeight: 0
    Layout.minimumWidth: 0
    Layout.maximumWidth: 0
    Layout.preferredWidth: 0
    Layout.minimumHeight: 0
    Layout.maximumHeight: 0
    Layout.preferredHeight: 0

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.globalShortcut: Plasmoid.containment && Plasmoid.containment.screen === 0
        ? "Meta+R" : ""

    property int appletRevision: 0
    readonly property var commandRunner: {
        const revision = appletRevision;
        const applets = Plasmoid.containment ? Plasmoid.containment.applets : [];
        for (const applet of applets) {
            if (applet && applet.pluginName === "org.kde.windowsmodern.systemtray"
                    && typeof applet.runCommand === "function")
                return applet;
        }
        return null;
    }

    Connections {
        target: Plasmoid.containment
        ignoreUnknownSignals: true
        function onAppletAdded() { root.appletRevision++; }
        function onAppletRemoved() { root.appletRevision++; }
    }

    RunDialog {
        id: runDialog
        commandRunner: root.commandRunner
    }

    Plasmoid.onActivated: runDialog.open()
}
