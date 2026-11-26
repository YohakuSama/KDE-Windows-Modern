// SPDX-License-Identifier: GPL-3.0-or-later
// System controls may use only semantically mapped original Windows artwork.
// No icon-theme lookup: missing resources must not produce Breeze/unknown.
import QtQuick
import QtCore
import org.kde.kirigami as Kirigami

Kirigami.Icon {
    id: glyph
    property string roleName: ""
    // Only use a fallback when it describes the same real device category.
    property string fallbackRoleName: ""
    property color foreground: Kirigami.Theme.textColor
    readonly property string nativeSource: resolveRole(roleName) || resolveRole(fallbackRoleName)

    function resolveRole(role) {
        role = String(role || "");
        if (!role || !/^[A-Za-z0-9_.+-]+$/.test(role)) return "";
        const names = role.endsWith("-symbolic") ? [role, role.slice(0, -9)]
            : [role + "-symbolic", role];
        for (const name of names) {
            for (const context of ["actions", "status", "devices", "apps", "emblems", "categories", "places"]) {
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
