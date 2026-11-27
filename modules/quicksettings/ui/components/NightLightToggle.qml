import QtQuick
import org.kde.plasma.private.brightnesscontrolplugin
import org.kde.plasma.workspace.dbus as DBus
import "../lib" as Lib

Lib.Tile {
    id: tile

    readonly property bool available: nightLight.available

    label: i18n("Night Light")
    // The glyph itself stays legible when the feature is off.
    iconSource: "wm-night-light-symbolic"
    active: nightLight.running && !nightLight.inhibited

    onClicked: if (tile.available) NightLightInhibitor.toggleInhibition()

    tooltipText: {
        if (!nightLight.available)
            return i18n("Night Light — Unavailable");
        if (active)
            return i18n("Night Light — On");
        return i18n("Night Light — Off");
    }

    DBus.Properties {
        id: nightLight
        busType: DBus.BusType.Session
        service: "org.kde.KWin.NightLight"
        path: "/org/kde/KWin/NightLight"
        iface: "org.kde.KWin.NightLight"

        readonly property bool available: Boolean(properties.available)
        readonly property bool running: Boolean(properties.running)
        readonly property bool enabled: Boolean(properties.enabled)
        readonly property bool inhibited: NightLightInhibitor.inhibited
    }
}
