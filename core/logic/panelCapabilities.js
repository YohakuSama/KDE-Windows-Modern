// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Capabilities are optional and local to the requesting applet's panel.
function findTray(applets, methods) {
    for (const applet of applets || []) {
        if (applet && applet.pluginName === "org.kde.windowsmodern.systemtray"
                && methods.every(method => typeof applet[method] === "function")) {
            return applet;
        }
    }
    return null;
}
