import QtQuick
import org.kde.bluezqt as BluezQt
import org.kde.kcmutils
import "../lib" as Lib

Lib.SplitTile {
    id: tile

    property QtObject btManager: BluezQt.Manager

    readonly property bool available: btManager.bluetoothBlocked || btManager.adapters.length > 0
    label: i18n("Bluetooth")
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
            return i18n("Bluetooth — %1 connected", connectedCount);
        return i18n("Bluetooth — On, not connected");
    }

    // The chevron already opens the device list; use the existing native settings action.
    onRightClicked: KCMLauncher.openSystemSettings("kcm_bluetooth")
    onMiddleClicked: KCMLauncher.openSystemSettings("kcm_bluetooth")
}
