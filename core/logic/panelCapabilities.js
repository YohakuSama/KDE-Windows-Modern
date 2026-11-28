// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

function hasMethods(candidate, methods) {
    return !!candidate && candidate.destroyed !== true
        && (methods || []).every(method => typeof candidate[method] === "function");
}

// Capabilities are optional and local to the requesting applet's panel.
// Prefer the panel containment's shared host action so Start and Digital
// Clock keep popup coordination and split blur without a System Tray.
function findPanelCapability(containment, applets, methods) {
    if (containment && containment.destroyed !== true
            && typeof containment.internalAction === "function") {
        const host = containment.internalAction("windowsModernPanelPopups");
        if (hasMethods(host, methods)) {
            return host;
        }
    }
    const list = applets || (containment ? containment.applets : []) || [];
    for (const applet of list) {
        if (applet && (applet.pluginName === "org.kde.windowsmodern.systemtray"
                || applet.pluginName === "org.kde.plasma.icontasks"
                || applet.pluginName === "org.kde.windowsmodern.icontasks")
                && hasMethods(applet, methods)) {
            return applet;
        }
    }
    return null;
}

function findTray(applets, methods) {
    return findPanelCapability(null, applets, methods);
}
