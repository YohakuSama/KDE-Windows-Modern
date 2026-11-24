import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents3
import org.kde.bluezqt as BluezQt
import org.kde.kcmutils
import "../lib" as Lib
import "../js/funcs.js" as Funcs

Lib.SplitTile {
    id: tile

    property QtObject btManager: BluezQt.Manager

    readonly property bool available: btManager.adapters.length > 0
    label: qsTr("Bluetooth")
    toggleAvailable: available
    // Same original Bluetooth glyph in all toggle states; active/disabled
    // appearance comes from the real radio state, not an invented artwork.
    iconSource: "network-bluetooth-symbolic"
    active: Funcs.btStatus(btManager).active

    onClicked: if (available) Funcs.toggleBluetooth(btManager)

    readonly property int connectedCount: {
        var c = 0;
        for (var i = 0; i < btManager.devices.length; i++) {
            if (btManager.devices[i].connected)
                c++;
        }
        return c;
    }

    tooltipText: {
        if (!toggleAvailable)
            return qsTr("Bluetooth — Unavailable");
        if (!Funcs.btStatus(btManager).active)
            return qsTr("Bluetooth — Off");
        if (connectedCount > 0)
            return qsTr("Bluetooth — %1 connected").arg(connectedCount);
        return qsTr("Bluetooth — On, not connected");
    }

    onRightClicked: btMenu.popup()

    onMiddleClicked: KCMLauncher.openSystemSettings("kcm_bluetooth")

    PlasmaComponents3.Menu {
        id: btMenu

        PlasmaComponents3.MenuItem {
            text: qsTr("Add new device…")
            icon.name: "list-add"
            onClicked: btExec.exec("bluedevil-wizard")
        }
        PlasmaComponents3.MenuItem {
            text: qsTr("Send file…")
            icon.name: "document-send"
            onClicked: btExec.exec("bluedevil-sendfile")
        }
        PlasmaComponents3.MenuItem {
            text: qsTr("Bluetooth settings")
            icon.name: "configure"
            onClicked: KCMLauncher.openSystemSettings("kcm_bluetooth")
        }
    }

    Plasma5Support.DataSource {
        id: btExec
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            disconnectSource(sourceName);
        }
        function exec(cmd) {
            connectSource(cmd);
        }
    }
}
