/*
    FlyoutRouter — maps child applet plugin names to themed flyout pages.

    Known applets get themed Win11 pages instead of their default Plasma
    fullRepresentationItem. Unknown applets fall through to the default
    PlasmoidPopupsContainer behavior with container chrome.
*/
pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: router

    readonly property var mapping: ({
        "org.kde.plasma.networkmanagement":  "network",
        "org.kde.plasma.bluetooth":          "bluetooth",
        "org.kde.plasma.volume":             "volume",
        "org.kde.plasma.battery":            "battery",
        "org.kde.plasma.brightness":         "brightness",
        "org.kde.plasma.clipboard":          "clipboard",
        "org.kde.plasma.mediacontroller":    "mediacontroller"
    })

    function flyoutNameForApplet(applet) {
        if (!applet)
            return "";
        const plugin = applet.plasmoid?.pluginName || applet.Plasmoid?.pluginName || "";
        // Device notifier exposes its original model on the full view.
        // If an older/different Plasma build does not expose it, preserve
        // the complete native page instead of offering an empty substitute.
        if (plugin === "org.kde.plasma.devicenotifier")
            return applet.fullRepresentationItem?.model ? "devices" : "";
        return mapping[plugin] || "";
    }

    function isThemedApplet(applet) {
        return flyoutNameForApplet(applet) !== ""
    }
}
