import QtQuick
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.kcmutils
import "../lib" as Lib

Lib.SplitTile {
    id: tile

    PlasmaNM.Handler {
        id: handler
    }
    PlasmaNM.EnabledConnections {
        id: enabledConnections
    }
    PlasmaNM.AvailableDevices {
        id: availableDevices
    }
    PlasmaNM.ConnectionIcon {
        id: activeConnectionIcon
    }
    PlasmaNM.NetworkStatus {
        id: netStatus
    }

    readonly property bool wifiAvailable: availableDevices.wirelessDeviceAvailable
    readonly property bool wifiAdministrativelyEnabled: wifiAvailable
        && enabledConnections.wirelessHwEnabled && !PlasmaNM.Configuration.airplaneModeEnabled
    readonly property bool wifiOn: wifiAvailable && enabledConnections.wirelessHwEnabled
        && enabledConnections.wirelessEnabled

    // Keep the detail arrow available on Ethernet-only systems, but do not
    // present a nonfunctional Wi-Fi toggle or a wired icon as Wi-Fi.
    label: wifiAvailable ? i18n("Wi-Fi") : i18n("Network")
    toggleAvailable: wifiAdministrativelyEnabled
    // The toggle depicts the Wi-Fi radio, not the current signal strength.
    // The native connection list and panel icon still report real strength.
    iconSource: wifiAvailable ? "network-wireless-symbolic"
        : (activeConnectionIcon.connectionIcon
            ? (activeConnectionIcon.connectionIcon.endsWith("-symbolic")
                ? activeConnectionIcon.connectionIcon : activeConnectionIcon.connectionIcon + "-symbolic")
            : "network-unavailable-symbolic")
    active: wifiOn

    onClicked: {
        if (wifiAdministrativelyEnabled) {
            handler.enableWireless(!wifiOn);
        }
    }

    tooltipText: !wifiAvailable ? i18n("Network — Wi-Fi unavailable")
        : !wifiAdministrativelyEnabled ? i18n("Wi-Fi — Disabled by hardware or airplane mode")
        : wifiOn ? i18n("Wi-Fi — On") : i18n("Wi-Fi — Off")

    onRightClicked: networkMenu.popup()

    onMiddleClicked: KCMLauncher.openSystemSettings("kcm_networkmanagement")

    PlasmaComponents3.Menu {
        id: networkMenu

        PlasmaComponents3.MenuItem {
            text: i18n("Open Wi-Fi settings")
            icon.name: "configure"
            onClicked: KCMLauncher.openSystemSettings("kcm_networkmanagement")
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Create hotspot…")
            icon.name: "network-wireless-hotspot"
            enabled: handler.hotspotSupported && !handler.hotspotActive
            onClicked: handler.createHotspot()
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Connect to hidden network…")
            icon.name: "network-wireless-secure"
            onClicked: KCMLauncher.openSystemSettings("kcm_networkmanagement")
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Known networks…")
            icon.name: "preferences-system-network"
            onClicked: KCMLauncher.openSystemSettings("kcm_networkmanagement")
        }
    }
}
