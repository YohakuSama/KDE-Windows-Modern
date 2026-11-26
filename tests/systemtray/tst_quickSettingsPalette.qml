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
        LayoutMirroring.childrenInherit: true
    }
    SignalSpy { id: toggle; target: split; signalName: "clicked" }
    SignalSpy { id: details; target: split; signalName: "arrowClicked" }
    TestCase {
        name: "QuickSettingsFluentPalette"
        when: windowShown
        function test_lightAndDarkColors() {
            compare(ColorType.tileFill(false, false, false), "#FBFBFB");
            compare(ColorType.cardFill(false, false), "#F2F2F2");
            compare(ColorType.tileFill(true, false, false), "#313131");
            compare(ColorType.cardFill(true, false), "#242424");
            compare(ColorType.trackFill(true), "#9B9B9B");
            verify(Math.abs(ColorType.quickTileFill(true, false, false, false, Qt.color("#4CC2FF")).r - 49/255) < 1/255);
            compare(ColorType.quickTileFill(true, true, false, false, Qt.color("#4CC2FF")), Qt.color("#4CC2FF"));
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
        function test_mirroredSplitPaintAndTargets() {
            split.width = 120;
            split.LayoutMirroring.enabled = true;
            try {
                toggle.clear();
                details.clear();
                const surface = findChild(split, "wmQuickTileSurface");
                const toggleBrush = findChild(split, "wmQuickTileToggleBrush");
                const detailsBrush = findChild(split, "wmQuickTileDetailsBrush");
                const divider = findChild(split, "wmQuickTileDivider");
                const glyph = findChild(split, "wmQuickTileGlyph");
                const arrow = findChild(split, "wmQuickTileDetailsGlyph");
                verify(surface && toggleBrush && detailsBrush && divider && glyph && arrow);
                tryCompare(surface, "width", 120);
                tryCompare(toggleBrush, "x", 48);
                compare(detailsBrush.x, 1);
                compare(divider.x, 48);
                compare(toggleBrush.topLeftRadius, 0);
                compare(detailsBrush.topRightRadius, 0);
                compare(arrow.roleName, "go-previous-symbolic");
                verify(Math.abs(glyph.x + glyph.width / 2 - 84) <= 1);
                verify(Math.abs(arrow.x + arrow.width / 2 - 24) <= 1);
                mouseClick(surface, 84, surface.height / 2);
                compare(toggle.count, 1);
                mouseClick(surface, 24, surface.height / 2);
                compare(details.count, 1);
                compare(toggle.count, 1);
            } finally {
                split.LayoutMirroring.enabled = false;
                split.width = 96;
            }
        }

        function test_sourceSizedSplitGeometryAndTargets() {
            split.width = 120;
            toggle.clear();
            details.clear();
            const surface = findChild(split, "wmQuickTileSurface");
            const glyph = findChild(split, "wmQuickTileGlyph");
            const arrow = findChild(split, "wmQuickTileDetailsGlyph");
            const other = findChild(simple, "wmQuickTileSurface");
            verify(surface && glyph && arrow && other);
            tryCompare(surface, "height", 48);
            compare(other.height, surface.height);
            compare(glyph.width, 16);
            tryCompare(surface, "width", 120);
            verify(Math.abs(glyph.x + glyph.width/2 - 36) <= 1);
            verify(Math.abs(arrow.x + arrow.width/2 - 96) <= 1);
            mouseClick(surface, 36, surface.height/2);
            compare(toggle.count, 1);
            compare(details.count, 0);
            mouseClick(surface, 96, surface.height/2);
            compare(details.count, 1);
            compare(toggle.count, 1);
            split.width = 96;
        }
    }
}
