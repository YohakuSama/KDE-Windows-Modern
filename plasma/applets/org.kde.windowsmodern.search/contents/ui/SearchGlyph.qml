// SPDX-License-Identifier: GPL-3.0-or-later
// Locally drawn Windows 11-style search glyph; no theme accent recolouring.
import QtQuick
import org.kde.kirigami as Kirigami

Kirigami.Icon {
    id: glyph
    property string iconName: "search"
    property bool accented: false
    property color foreground: Kirigami.Theme.textColor
    readonly property string colorSource: Qt.resolvedUrl("search-modern.svg").toString()
    readonly property string accentSource: Qt.resolvedUrl("search-monochrome.svg").toString()
    readonly property string resolvedSource: accented ? accentSource : colorSource
    source: resolvedSource
    fallback: "edit-find"
    isMask: accented
    color: foreground
    roundToIconSize: false
    animated: false
}
