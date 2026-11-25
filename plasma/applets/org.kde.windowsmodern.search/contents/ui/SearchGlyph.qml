// SPDX-License-Identifier: GPL-3.0-or-later
// Shared Windows Modern search glyph. Use the imported full-colour artwork
// at rest and the monochrome action glyph over the active accent surface.
import QtQuick
import QtCore
import org.kde.kirigami as Kirigami

Kirigami.Icon {
    id: glyph
    property string iconName: "search"
    property bool accented: false
    readonly property string colorSource: {
        const imported = StandardPaths.locate(StandardPaths.GenericDataLocation,
            "icons/windows-modern/apps/search.svg", StandardPaths.LocateFile);
        return String(imported).length > 0 ? String(imported) : iconName;
    }
    readonly property bool hasColorSource: {
        const imported = StandardPaths.locate(StandardPaths.GenericDataLocation,
            "icons/windows-modern/apps/search.svg", StandardPaths.LocateFile);
        return String(imported).length > 0;
    }
    readonly property string accentSource: {
        const imported = StandardPaths.locate(StandardPaths.GenericDataLocation,
            "icons/windows-modern/actions/search.svg", StandardPaths.LocateFile);
        if (String(imported).length > 0) return String(imported);
        const compatibility = StandardPaths.locate(StandardPaths.GenericDataLocation,
            "icons/windows-modern/actions/edit-find.svg", StandardPaths.LocateFile);
        return String(compatibility).length > 0 ? String(compatibility) : "edit-find-symbolic";
    }
    readonly property string resolvedSource: accented ? accentSource : colorSource
    source: resolvedSource
    fallback: "edit-find"
    isMask: accented || !hasColorSource
    color: accented ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
    roundToIconSize: false
    animated: false
}
