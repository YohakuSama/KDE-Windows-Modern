import QtQuick
import org.kde.plasma.private.batterymonitor
import "../lib" as Lib

Lib.Tile {
    id: tile

    // Use PowerDevil's shared native manual inhibition state. Both this tile
    // and the battery detail page follow the stock battery applet.
    InhibitionControl {
        id: inhibitionControl
        isSilent: true
    }

    readonly property bool blockSleep: inhibitionControl.isManuallyInhibited

    label: blockSleep ? qsTr("Sleep Blocked") : qsTr("No Sleep")
    iconSource: blockSleep ? "system-suspend-inhibited" : "system-suspend-uninhibited"
    active: blockSleep

    onClicked: {
        if (inhibitionControl.isManuallyInhibited)
            inhibitionControl.uninhibit();
        else
            inhibitionControl.inhibit(qsTr("Automatic sleep and screen locking disabled by user"));
    }

    tooltipText: blockSleep ? qsTr("Sleep Inhibited") : qsTr("Sleep Allowed")
}
