import QtQuick
import org.kde.plasma.components as PlasmaComponents3
import org.kde.bluezqt as BluezQt
import org.kde.kcmutils
import "../lib" as Lib

Lib.SplitTile {
    id: tile

    NativeGlyph {
        id: menuGlyphs
        visible: false
    }

    property QtObject btManager: BluezQt.Manager

    readonly property bool available: btManager.bluetoothBlocked || btManager.adapters.length > 0
    readonly property string connectedDeviceName: active && connectedCount === 1
        ? String(btManager.connectedDevices[0]?.friendlyName || btManager.connectedDevices[0]?.name || "").replace(/[\r\n\t]/g, " ") : ""
    label: !active || connectedCount === 0 ? i18n("Bluetooth")
        : connectedCount === 1 ? (connectedDeviceName || i18n("Bluetooth"))
        : i18n("%1 devices connected", connectedCount)
    accessibleLabel: label === i18n("Bluetooth") ? label : i18n("Bluetooth") + ": " + label
    toggleAvailable: available
    // Same original Bluetooth glyph in all toggle states; active/disabled
    // appearance comes from the real radio state, not an invented artwork.
    iconSource: "network-bluetooth-symbolic"
    active: btManager.bluetoothOperational

    onClicked: {
        if (!available) return;
        const enable = !btManager.bluetoothOperational;
        btManager.bluetoothBlocked = !enable;
        for (const adapter of btManager.adapters)
            adapter.powered = enable;
    }

    readonly property int connectedCount: btManager.connectedDevices.length

    tooltipText: {
        if (!toggleAvailable)
            return i18n("Bluetooth — Unavailable");
        if (!active)
            return i18n("Bluetooth — Off");
        if (connectedCount > 0)
            return i18n("Bluetooth — %1 connected", connectedCount)
                + (connectedDeviceName ? "\n" + connectedDeviceName : "");
        return i18n("Bluetooth — On, not connected");
    }

    onRightClicked: btMenu.popup()

    onMiddleClicked: KCMLauncher.openSystemSettings("kcm_bluetooth")

    PlasmaComponents3.Menu {
        id: btMenu

        PlasmaComponents3.MenuItem {
            text: i18n("Bluetooth devices")
            icon.source: menuGlyphs.resolveRole("preferences-system-bluetooth")
            onClicked: tile.arrowClicked()
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Bluetooth settings")
            icon.source: menuGlyphs.resolveRole("configure")
            onClicked: KCMLauncher.openSystemSettings("kcm_bluetooth")
        }
    }
}
