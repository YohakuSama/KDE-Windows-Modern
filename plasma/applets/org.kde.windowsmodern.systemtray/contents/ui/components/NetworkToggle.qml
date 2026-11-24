import QtQuick
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.networkmanagement as PlasmaNM
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
    readonly property bool wifiOn: wifiAvailable && enabledConnections.wirelessEnabled

    // Keep the detail arrow available on Ethernet-only systems, but do not
    // present a nonfunctional Wi-Fi toggle or a wired icon as Wi-Fi.
    label: wifiAvailable ? qsTr("Wi-Fi") : qsTr("Network")
    toggleAvailable: wifiAvailable
    iconSource: {
        const base = activeConnectionIcon.connectionIcon || "";
        if (!wifiAvailable)
            return base || "network-wired-symbolic";
        if (!wifiOn)
            return "network-wireless-disconnected-symbolic";
        return base.indexOf("network-wireless") === 0
            ? base : "network-wireless-0-symbolic";
    }
    active: wifiOn

    onClicked: {
        if (wifiAvailable) {
            handler.enableWireless(!wifiOn);
        }
    }

    tooltipText: !wifiAvailable ? qsTr("Network — Wi-Fi unavailable")
        : wifiOn ? qsTr("Wi-Fi — On") : qsTr("Wi-Fi — Off")

    onRightClicked: networkMenu.popup()

    onMiddleClicked: Qt.openUrlExternally("systemsettings://kcm_networkmanagement")

    PlasmaComponents3.Menu {
        id: networkMenu

        PlasmaComponents3.MenuItem {
            text: qsTr("Open Wi-Fi settings")
            icon.name: "configure"
            onClicked: Qt.openUrlExternally("systemsettings://kcm_networkmanagement")
        }
        PlasmaComponents3.MenuItem {
            text: qsTr("Create hotspot…")
            icon.name: "network-wireless-hotspot"
            onClicked: handler.createHotspot()
        }
        PlasmaComponents3.MenuItem {
            text: qsTr("Connect to hidden network…")
            icon.name: "network-wireless-secure"
            onClicked: handler.addAndActivateConnection("")
        }
        PlasmaComponents3.MenuItem {
            text: qsTr("Known networks…")
            icon.name: "preferences-system-network"
            onClicked: Qt.openUrlExternally("systemsettings://kcm_networkmanagement")
        }
    }
}
