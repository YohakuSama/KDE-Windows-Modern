// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/js/trayMetrics.js" as Metrics

TestCase {
    name: "WindowsTrayMetrics"
    function test_defaultGlyphAndCell() {
        for (const thickness of [24, 30, 32, 48, 64, 96]) {
            compare(Metrics.iconSize(thickness, false), 16);
            compare(Metrics.cellLength(16, false, 2), 32);
            compare(Metrics.cellLength(16, true, 2), 24);
        }
        compare(Metrics.iconSize(12, false), 12);
        compare(Metrics.iconSize(48, true), 16);
        compare(Metrics.iconSize(96, true), 32);
        compare(Metrics.cellLength(16, false, 1), 24);
        compare(Metrics.cellLength(16, true, 1), 20);
        compare(Metrics.cellLength(16, false, 6), 40);
        compare(Metrics.cellLength(16, true, 6), 32);
    }
    function test_nativeCoreContainer() {
        for (const thickness of [24, 30, 32, 48, 64, 96]) {
            compare(Metrics.coreIconSize(thickness, false), 16);
            compare(Metrics.coreCellLength(16, 16, 2), 24);
            compare(Metrics.coreRenderSize(16), 32);
        }
        compare(Metrics.coreIconSize(12, false), 12);
        compare(Metrics.coreIconSize(18, false), 16);
        compare(Metrics.coreIconSize(48, true), 16);
        compare(Metrics.coreIconSize(64, true), 21);
        compare(Metrics.coreIconSize(96, true), 32);
        compare(Metrics.coreCellLength(16, 16, 1), 20);
        compare(Metrics.coreCellLength(16, 16, 6), 32);
        compare(Metrics.coreCellLength(32, 32, 2), 36);
        compare(Metrics.coreCellLength(18, 18, 1), 22);
        compare(Metrics.coreCellLength(18, 18, 6), 32);
        compare(Metrics.coreCellLength(20, 20, 1), 24);
        compare(Metrics.coreCellLength(20, 20, 6), 32);
        compare(Metrics.coreRenderSize(12), 16);
        compare(Metrics.coreRenderSize(16), 32);
        compare(Metrics.coreRenderSize(24), 32);
        compare(Metrics.coreRenderSize(32), 32);
    }
    function test_referenceScaleBudget() {
        // Resource size baseline, not a guarantee of the exact live ink.
        // At 150% a standard glyph cannot have a 30px canvas, even when
        // a normalized original asset nearly fills the source em.
        const logical = Metrics.iconSize(48, false);
        const physical = logical * 1.5;
        compare(physical, 24);
        compare(Math.ceil(logical * 1.25) * 1.5, 30);
        verify(physical < 24 * 1.5);
        for (const scale of [1, 1.25, 1.5, 1.75, 2]) {
            compare(logical * scale, 16 * scale);
            compare(Metrics.coreCellLength(logical, logical, 2) * scale, 24 * scale);
        }
    }
    function test_groupLeadingPaddingAndCenter() {
        compare(Metrics.leadingSystemInset(true, false, false), 6);
        compare(Metrics.leadingSystemInset(true, true, false), 0);
        compare(Metrics.leadingSystemInset(false, false, false), 0);
        compare(Metrics.leadingSystemInset(true, false, true), 0);
        const inset = Metrics.leadingSystemInset(true, false, false);
        const cell = Metrics.coreCellLength(16, 16, 2);
        const firstCenter = inset + cell / 2;
        const nextCenter = inset + cell + cell / 2;
        for (const scale of [1, 1.5, 2]) {
            compare((nextCenter - firstCenter) * scale, 24 * scale);
            const rect = Metrics.groupHoverRect({x: 0, y: 3, width: 114, height: 42}, 48, false);
            compare(rect.height * scale, 40 * scale);
            compare((rect.y + rect.height / 2) * scale, 24 * scale);
            compare(rect.width * scale, 110 * scale);
            compare((firstCenter - rect.x) * scale, 16 * scale);
        }
        const short = Metrics.groupHoverRect({x: 0, y: 0, width: 72, height: 30}, 48, false);
        compare(short.height, 30);
        const vertical = Metrics.groupHoverRect({x: 3, y: 0, width: 42, height: 72}, 48, true);
        compare(vertical.width, 40);
        compare(vertical.x + vertical.width / 2, 24);
    }
    function test_systemGroup() {
        verify(Metrics.isQuickSettings("org.kde.plasma.networkmanagement"));
        verify(Metrics.isQuickSettings("org.kde.plasma.volume"));
        verify(Metrics.isQuickSettings("org.kde.plasma.battery"));
        verify(!Metrics.isQuickSettings("org.kde.plasma.bluetooth"));
        verify(!Metrics.isQuickSettings("org.kde.plasma.keyboardlayout"));
        verify(!Metrics.isQuickSettings("third.party"));
    }
    function test_contiguousGroupUsesActualCellGeometry() {
        const cell = (x, y, w, h, core) => ({x: x, y: y, width: w, height: h, systemGroup: core});
        const horizontal = [cell(0,0,32,48,false), cell(32,0,24,48,true),
            cell(56,0,24,48,true), cell(80,0,56,48,true)];
        const normal = Metrics.groupRects(horizontal, false);
        compare(normal.length, 1);
        compare(normal[0].x, 32);
        compare(normal[0].width, 104);
        compare(normal[0].height, 48);
        compare(Metrics.groupRects(horizontal.slice().reverse(), false), normal);
        horizontal[2].systemGroup = false;
        const split = Metrics.groupRects(horizontal, false);
        compare(split.length, 2);
        compare(split[0].width, 24);
        compare(split[1].x, 80);
        const vertical = Metrics.groupRects([cell(0,24,48,24,true),
            cell(0,0,48,24,true), cell(0,48,48,24,false)], true);
        compare(vertical.length, 1);
        compare(vertical[0].y, 0);
        compare(vertical[0].height, 48);
        compare(Metrics.groupRects([], false).length, 0);
    }
    function test_anchorRunFollowsActualTrigger() {
        const runs = [{x: 8, y: 0, width: 24, height: 48},
            {x: 96, y: 0, width: 72, height: 48}];
        compare(Metrics.anchorRun(runs, {x: 20, y: 24}, false, false).x, 8);
        compare(Metrics.anchorRun(runs, {x: 120, y: 24}, false, false).x, 96);
        compare(Metrics.anchorRun(runs, null, false, false).x, 96);
        compare(Metrics.anchorRun(runs, null, false, true).x, 8);
        compare(Metrics.anchorRun([], null, false, false), null);
    }
    function test_order() {
        compare(Metrics.visualIndex(0, 4, false, false), 0);
        compare(Metrics.visualIndex(0, 4, false, true), 0);
        compare(Metrics.visualIndex(0, 4, true, false), 0);
        compare(Metrics.visualIndex(0, 4, true, true), 3);
        compare(Metrics.visualIndex(3, 4, true, true), 0);
    }
}
