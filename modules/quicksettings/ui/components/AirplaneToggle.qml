import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM
import "../lib" as Lib

Lib.Tile {
    id: tile

    PlasmaNM.Handler {
        id: handler
    }

    PlasmaNM.AvailableDevices {
        id: devices
    }

    readonly property bool available: devices.modemDeviceAvailable || devices.wirelessDeviceAvailable
        || PlasmaNM.Configuration.airplaneModeEnabled

    label: i18n("Airplane mode")
    iconSource: "network-flightmode-on-symbolic"
    active: PlasmaNM.Configuration.airplaneModeEnabled

    onClicked: {
        if (!available)
            return;
        var enable = !PlasmaNM.Configuration.airplaneModeEnabled;
        handler.enableAirplaneMode(enable);
        PlasmaNM.Configuration.airplaneModeEnabled = enable;
    }

    tooltipText: active ? i18n("Airplane Mode — On") : i18n("Airplane Mode — Off")
}
