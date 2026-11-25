// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/js/colorType.js" as ColorType

TestCase {
    name: "QuickSettingsAccentContrast"

    function test_fluentControlStateBrushes() {
        const darkAccent = Qt.color("#4CC2FF");
        const lightAccent = Qt.color("#0067C0");
        const darkBase = ColorType.quickTileSurface(true);
        const lightBase = ColorType.quickTileSurface(false);
        const offRest = ColorType.quickTileFill(true, false, false, false, darkAccent);
        const offHover = ColorType.quickTileFill(true, false, true, false, darkAccent);
        const offPress = ColorType.quickTileFill(true, false, true, true, darkAccent);
        verify(ColorType.luminance(offHover) > ColorType.luminance(offRest));
        verify(ColorType.luminance(offPress) < ColorType.luminance(offRest));
        compare(offRest, ColorType.blendOver(Qt.color("#FFFFFF"), darkBase, 15 / 255));
        compare(ColorType.quickTileFill(true, true, false, false, darkAccent), darkAccent);
        compare(ColorType.quickTileFill(true, true, true, false, darkAccent),
                ColorType.blendOver(darkAccent, darkBase, 0.9));
        compare(ColorType.quickTileFill(false, true, false, false, lightAccent), lightAccent);
        compare(ColorType.quickTileFill(false, true, true, true, lightAccent),
                ColorType.blendOver(lightAccent, lightBase, 0.8));
        compare(ColorType.quickTileStroke(true, false), "#12FFFFFF");
        compare(ColorType.quickTileStroke(false, false), "#0F000000");
    }

    function test_foreground_data() {
        return [
            { tag: "dark theme accent", accent: "#4CC2FF", expected: "#000000" },
            { tag: "light theme accent", accent: "#0067C0", expected: "#FFFFFF" },
            { tag: "black", accent: "#000000", expected: "#FFFFFF" },
            { tag: "white", accent: "#FFFFFF", expected: "#000000" },
            { tag: "yellow", accent: "#FFFF00", expected: "#000000" },
            { tag: "navy", accent: "#000080", expected: "#FFFFFF" }
        ]
    }

    function test_foreground(data) {
        const color = Qt.color(data.accent);
        compare(ColorType.contrastingForeground(color), data.expected);
        verify(ColorType.contrastRatio(color, Qt.color(data.expected)) >= 4.5);
    }
}
