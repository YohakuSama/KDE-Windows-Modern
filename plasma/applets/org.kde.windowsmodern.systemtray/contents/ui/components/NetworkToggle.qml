import QtQuick
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.kcmutils
import org.kde.kitemmodels as KItemModels
import "../lib" as Lib

Lib.SplitTile {
    id: tile

    NativeGlyph {
        id: menuGlyphs
        visible: false
    }

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
    // Read structured connection roles; the localized NetworkStatus
    // tooltip also contains Ethernet and VPN names and is not an SSID API.
    KItemModels.KSortFilterProxyModel {
        id: activeConnections
        sourceModel: PlasmaNM.NetworkModel {}
        filterRoleName: "ConnectionState"
        filterRowCallback: (row, parentIndex) =>
            sourceModel.data(sourceModel.index(row, 0, parentIndex), filterRole) === PlasmaNM.Enums.Activated
    }
    Instantiator {
        id: activeWifiRows
        model: tile.wifiOn ? activeConnections : null
        delegate: QtObject {
            required property var model
            readonly property string ssid: model.Type === PlasmaNM.Enums.Wireless
                ? String(model.Ssid || model.Name || "").replace(/[\r\n\t]/g, " ") : ""
        }
        onObjectAdded: tile.connectionRevision++
        onObjectRemoved: tile.connectionRevision++
    }
    property int connectionRevision: 0
    readonly property string connectedSsid: {
        const revision = connectionRevision;
        if (!wifiOn) return "";
        for (let i = 0; i < activeWifiRows.count; ++i) {
            const row = activeWifiRows.objectAt(i);
            if (row && row.ssid.length > 0) return row.ssid;
        }
        return "";
    }

    readonly property bool wifiAvailable: availableDevices.wirelessDeviceAvailable
    readonly property bool wifiAdministrativelyEnabled: wifiAvailable
        && enabledConnections.wirelessHwEnabled && !PlasmaNM.Configuration.airplaneModeEnabled
    readonly property bool wifiOn: wifiAvailable && enabledConnections.wirelessHwEnabled
        && enabledConnections.wirelessEnabled

    // Keep the detail arrow available on Ethernet-only systems, but do not
    // present a nonfunctional Wi-Fi toggle or a wired icon as Wi-Fi.
    label: connectedSsid || (wifiAvailable ? i18n("Wi-Fi") : i18n("Network"))
    accessibleLabel: connectedSsid ? i18n("Wi-Fi") + ": " + connectedSsid : label
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
        : wifiOn ? i18n("Wi-Fi — On") + (connectedSsid ? "\n" + connectedSsid : "")
        : i18n("Wi-Fi — Off")

    onRightClicked: networkMenu.popup()

    onMiddleClicked: KCMLauncher.openSystemSettings("kcm_networkmanagement")

    PlasmaComponents3.Menu {
        id: networkMenu

        PlasmaComponents3.MenuItem {
            text: tile.wifiAvailable ? i18n("Open Wi-Fi settings") : i18n("Network settings")
            icon.source: menuGlyphs.resolveRole("configure")
            onClicked: KCMLauncher.openSystemSettings("kcm_networkmanagement")
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Create hotspot…")
            visible: tile.wifiAvailable
            icon.source: menuGlyphs.resolveRole("network-wireless-hotspot")
            enabled: handler.hotspotSupported && !handler.hotspotActive
            onClicked: handler.createHotspot()
        }
    }
}
