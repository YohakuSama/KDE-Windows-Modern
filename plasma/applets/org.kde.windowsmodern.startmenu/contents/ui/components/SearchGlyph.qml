// SPDX-License-Identifier: GPL-3.0-or-later
// The icon theme provides the canonical imported Segoe Fluent E721 symbol.
// A verified local colour asset may occupy search-active.svg, never a drawn imitation.
import QtQuick
import QtCore
import org.kde.kirigami as Kirigami

Kirigami.Icon {
    id: glyph
    property string iconName: "search"
    property bool accented: false
    property color foreground: Kirigami.Theme.textColor
    readonly property string verifiedColorSource: String(StandardPaths.locate(StandardPaths.GenericDataLocation,
        "windows-modern/native-assets/icons/actions/search-active.svg", StandardPaths.LocateFile))
    readonly property string accentSource: {
        const imported = StandardPaths.locate(StandardPaths.GenericDataLocation,
            "windows-modern/native-assets/icons/actions/search.svg", StandardPaths.LocateFile);
        return String(imported);
    }
    readonly property bool hasColorSource: verifiedColorSource.length > 0
    readonly property string colorSource: hasColorSource ? verifiedColorSource : accentSource
    readonly property string resolvedSource: accented ? accentSource : colorSource
    source: resolvedSource
    fallback: ""
    visible: resolvedSource.length > 0
    isMask: accented || !hasColorSource
    color: foreground
    roundToIconSize: false
    animated: false
}
