// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/js/colorType.js" as ColorType
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/lib" as Lib

Item {
    width: 320
    height: 230
    Lib.Tile {
        id: simple
        width: 96
        height: 86
        buttonHeight: 48
        label: "Night light"
        iconSource: "wm-night-light-symbolic"
    }
    Lib.SplitTile {
        id: split
        x: 120
        width: 96
        height: 86
        buttonHeight: 48
        label: "Wi-Fi"
        iconSource: "network-wireless-symbolic"
    }
    SignalSpy { id: toggle; target: split; signalName: "clicked" }
    SignalSpy { id: details; target: split; signalName: "arrowClicked" }
    TestCase {
        name: "QuickSettingsFluentPalette"
        when: windowShown
        function test_lightAndDarkColors() {
            compare(ColorType.tileFill(false, false, false), "#FBFBFB");
            compare(ColorType.cardFill(false, false), "#F2F2F2");
            compare(ColorType.tileFill(true, false, false), "#333333");
            compare(ColorType.contrastingForeground(Qt.rgba(0,103/255,192/255,1)), "#FFFFFF");
            compare(ColorType.contrastingForeground(Qt.rgba(76/255,194/255,1,1)), "#000000");
            verify(ColorType.contrastRatio(Qt.rgba(0,103/255,192/255,1), Qt.rgba(1,1,1,1)) >= 4.5);
            verify(ColorType.contrastRatio(Qt.rgba(76/255,194/255,1,1), Qt.rgba(0,0,0,1)) >= 4.5);
        }
        function test_wallpaperAccentContrast() {
            for (const surface of [Qt.rgba(32/255, 32/255, 32/255, 1), Qt.rgba(242/255, 242/255, 242/255, 1)]) {
                const muted = Qt.rgba(56/255, 95/255, 99/255, 1);
                const accent = ColorType.accentForSurface(muted, surface);
                verify(ColorType.contrastRatio(accent, surface) >= 2.98);
                const ink = ColorType.contrastingForeground(accent) === "#FFFFFF"
                    ? Qt.rgba(1,1,1,1) : Qt.rgba(0,0,0,1);
                verify(ColorType.contrastRatio(ink, accent) >= 4.5);
                verify(accent.b >= accent.g && accent.g >= accent.r);
            }
        }
        function test_captionFitsTwoLinesAtSmallScale() {
            split.buttonHeight = 24;
            verify(split.captionHeight >= 20);
            split.buttonHeight = 48;
        }
        function test_equalSplitGeometryAndTargets() {
            const surface = findChild(split, "wmQuickTileSurface");
            const glyph = findChild(split, "wmQuickTileGlyph");
            const arrow = findChild(split, "wmQuickTileDetailsGlyph");
            const other = findChild(simple, "wmQuickTileSurface");
            verify(surface && glyph && arrow && other);
            tryCompare(surface, "height", 48);
            compare(other.height, surface.height);
            compare(glyph.width, 16);
            verify(Math.abs(glyph.x + glyph.width/2 - surface.width/4) <= 1);
            verify(Math.abs(arrow.x + arrow.width/2 - 3*surface.width/4) <= 1);
            mouseClick(surface, surface.width/4, surface.height/2);
            compare(toggle.count, 1);
            compare(details.count, 0);
            mouseClick(surface, 3*surface.width/4, surface.height/2);
            compare(details.count, 1);
            compare(toggle.count, 1);
        }
    }
}
