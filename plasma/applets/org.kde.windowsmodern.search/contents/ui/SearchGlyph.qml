// SPDX-License-Identifier: GPL-3.0-or-later
// Prefer the original Windows 11 shell Search state images. When they are
// unavailable, use only the verified Segoe Fluent E721 glyph from this theme.
import QtQuick
import QtCore
import org.kde.kirigami as Kirigami

Kirigami.Icon {
    id: glyph
    property string iconName: "search"
    property bool accented: false
    property color foreground: Kirigami.Theme.textColor

    readonly property bool darkTheme: Kirigami.ColorUtils.brightnessForColor(foreground)
        === Kirigami.ColorUtils.Light
    readonly property string colorSource: {
        const fileName = darkTheme ? "search-on-dark.png" : "search-on-light.png";
        return String(StandardPaths.locate(StandardPaths.GenericDataLocation,
            "windows-modern/native-assets/shell/search/" + fileName,
            StandardPaths.LocateFile));
    }
    readonly property string accentSource: {
        const fileName = darkTheme ? "search-off-dark.png" : "search-off-light.png";
        const native = String(StandardPaths.locate(StandardPaths.GenericDataLocation,
            "windows-modern/native-assets/shell/search/" + fileName,
            StandardPaths.LocateFile));
        if (native.length > 0) return native;
        return String(StandardPaths.locate(StandardPaths.GenericDataLocation,
            "windows-modern/native-assets/icons/actions/search.svg",
            StandardPaths.LocateFile));
    }
    readonly property bool hasColorSource: colorSource.length > 0
    readonly property bool accentIsMask: !accentSource.endsWith(".png")
    readonly property string resolvedSource: accented ? accentSource
        : hasColorSource ? colorSource : accentSource
    readonly property bool resolvedIsMask: accented ? accentIsMask : !hasColorSource

    source: resolvedSource
    fallback: ""
    visible: resolvedSource.length > 0
    isMask: resolvedIsMask
    color: foreground
    roundToIconSize: false
    animated: false
}
