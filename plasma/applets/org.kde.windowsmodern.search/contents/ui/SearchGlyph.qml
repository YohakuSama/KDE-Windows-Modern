// SPDX-License-Identifier: GPL-3.0-or-later
// Preserve the original Windows shell Search images and their state colors.
import QtQuick
import QtCore
import org.kde.kirigami as Kirigami

Kirigami.Icon {
    id: glyph
    property string iconName: "search"
    property bool accented: false
    property bool forceMask: false
    property color foreground: Kirigami.Theme.textColor
    readonly property bool darkSurface: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.textColor)
        === Kirigami.ColorUtils.Light
    readonly property string themeName: darkSurface ? "dark" : "light"

    function locate(relative) {
        return String(StandardPaths.locate(StandardPaths.GenericDataLocation, relative, StandardPaths.LocateFile));
    }

    readonly property string nativeOnSource: locate("windows-modern/shell-assets/search/" + themeName + "-on.png")
    readonly property string nativeOffSource: locate("windows-modern/shell-assets/search/" + themeName + "-off.png")
    readonly property string oldColorSource: locate("windows-modern/native-assets/icons/actions/search-active.svg")
    readonly property string oldMaskSource: locate("windows-modern/native-assets/icons/actions/search.svg")
    readonly property string verifiedColorSource: nativeOnSource || oldColorSource
    readonly property string accentSource: nativeOffSource || oldMaskSource
    readonly property bool hasColorSource: verifiedColorSource.length > 0
    readonly property string colorSource: verifiedColorSource || oldMaskSource
    readonly property bool offIsMask: nativeOffSource.length === 0
    readonly property bool onIsMask: !hasColorSource
    readonly property string resolvedSource: accented ? accentSource : colorSource
    source: resolvedSource
    fallback: ""
    visible: resolvedSource.length > 0
    isMask: forceMask || (accented ? offIsMask : onIsMask)
    color: foreground
    roundToIconSize: false
    animated: false
}
