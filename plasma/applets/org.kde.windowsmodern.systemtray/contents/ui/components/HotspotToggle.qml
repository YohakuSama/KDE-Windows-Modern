import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM
import "../lib" as Lib

Lib.Tile {
    id: tile

    PlasmaNM.Handler {
        id: handler
    }

    readonly property bool hotspotSupported: handler.hotspotSupported
    readonly property bool hotspotActive: handler.hotspotActive

    label: qsTr("Hotspot")
    iconSource: "network-wireless-hotspot"
    active: hotspotActive
    visible: hotspotSupported || hotspotActive

    onClicked: {
        if (hotspotActive)
            handler.stopHotspot();
        else if (hotspotSupported)
            handler.createHotspot();
    }

    tooltipText: hotspotActive ? qsTr("Hotspot — On") : qsTr("Hotspot — Off")
}
