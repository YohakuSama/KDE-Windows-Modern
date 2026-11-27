// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "js/trayMetrics.js" as TrayMetrics

// The parent is the optical slot; the child may have a larger transparent
// canvas. Its painted center, not the source's outer canvas, is aligned.
Item {
    id: glyph
    property var source
    // For related states with the same canvas (e.g. volume waves), use
    // the full-state bounds to avoid changing size as the value changes.
    property var referenceSource: source
    readonly property rect bounds: typeof Plasmoid.panelGlyphBounds === "function"
        ? Plasmoid.panelGlyphBounds(String(referenceSource || "")) : Qt.rect(0, 0, 1, 1)
    readonly property var placement: TrayMetrics.opticalPlacement(bounds, width, height)

    Kirigami.Icon {
        x: glyph.placement.x
        y: glyph.placement.y
        width: glyph.placement.width
        height: glyph.placement.height
        source: glyph.source
        fallback: ""
        visible: String(glyph.source || "").length > 0
        roundToIconSize: false
        isMask: true
        color: Kirigami.Theme.textColor
    }
}
