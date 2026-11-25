// SPDX-License-Identifier: GPL-3.0-or-later
// Shared explicit search role: prefer the locally imported system glyph,
// not the unrelated full-color apps/search alias selected at larger sizes.
import QtQuick
import QtCore
import org.kde.kirigami as Kirigami

Kirigami.Icon {
    id: glyph
    property string iconName: "edit-find-symbolic"
    property bool accented: false
    readonly property string resolvedSource: {
        const imported = StandardPaths.locate(StandardPaths.GenericDataLocation,
            "icons/windows-modern/actions/search.svg", StandardPaths.LocateFile);
        if (String(imported).length > 0) return String(imported);
        const compatibility = StandardPaths.locate(StandardPaths.GenericDataLocation,
            "icons/windows-modern/actions/edit-find.svg", StandardPaths.LocateFile);
        return String(compatibility).length > 0 ? String(compatibility) : iconName;
    }
    source: resolvedSource
    fallback: "edit-find"
    isMask: true
    color: accented ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
    roundToIconSize: false
    animated: false
}
