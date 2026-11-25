// SPDX-License-Identifier: GPL-3.0-or-later
// System controls may use only semantically mapped original Windows artwork.
// No icon-theme lookup: missing resources must not produce Breeze/unknown.
import QtQuick
import QtCore
import org.kde.kirigami as Kirigami

Kirigami.Icon {
    id: glyph
    property string roleName: ""
    property color foreground: Kirigami.Theme.textColor
    readonly property string nativeSource: {
        if (!/^[A-Za-z0-9_.+-]+$/.test(roleName)) return "";
        const names = roleName.endsWith("-symbolic") ? [roleName, roleName.slice(0, -9)]
            : [roleName + "-symbolic", roleName];
        for (const name of names) {
            for (const context of ["actions", "status", "devices", "apps"]) {
                const file = StandardPaths.locate(StandardPaths.GenericDataLocation,
                    "windows-modern/native-assets/icons/" + context + "/" + name + ".svg",
                    StandardPaths.LocateFile);
                if (String(file).length > 0) return String(file);
            }
        }
        return "";
    }
    source: nativeSource
    fallback: ""
    visible: nativeSource.length > 0
    isMask: true
    color: foreground
    animated: false
    roundToIconSize: false
}
