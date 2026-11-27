// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/js/trayMetrics.js" as Metrics
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/js/controlMetrics.js" as ControlMetrics

TestCase {
    name: "WindowsTrayMetrics"
    function test_opticalPlacementAtAllScales() {
        // A 22px fallback canvas with 16px of visible ink versus a
        // normalized original asset: both must paint approximately 15.3px.
        const fallback = {x: 3/22, y: 4/22, width: 16/22, height: 14/22};
        const imported = {x: 0.5/24, y: 0.5/24, width: 23/24, height: 23/24};
        const a = Metrics.opticalPlacement(fallback, 16, 16);
        const b = Metrics.opticalPlacement(imported, 16, 16);
        compare(b.factor, 1);
        verify(a.factor > 1.3 && a.factor < 1.4);
        for (const scale of [1, 1.25, 1.5, 1.75, 2]) {
            fuzzyCompare(a.width * fallback.width * scale, b.width * imported.width * scale, 0.0001);
            fuzzyCompare((a.x + a.width * (fallback.x + fallback.width/2)) * scale, 8 * scale, 0.0001);
            fuzzyCompare((a.y + a.height * (fallback.y + fallback.height/2)) * scale, 8 * scale, 0.0001);
        }
        const asymmetric = {x: 0.1, y: 0.2, width: 0.7, height: 0.5};
        const c = Metrics.opticalPlacement(asymmetric, 16, 16);
        fuzzyCompare(c.x + c.width * 0.45, 8, 0.0001);
        fuzzyCompare(c.y + c.height * 0.45, 8, 0.0001);
        compare(Metrics.opticalPlacement({x:0,y:0,width:0.01,height:0.01},16,16).factor, 1.5);
        compare(Metrics.opticalPlacement({x:0,y:0,width:0,height:0},16,16).factor, 1);
    }
    function test_wifiStateReference() {
        for (const name of ["network-wireless-0-symbolic", "network-wireless-20-symbolic",
                            "network-wireless-connected-00-symbolic", "network-wireless-connected-80-symbolic"])
            compare(Metrics.networkReferenceName(name), "network-wireless-symbolic");
        for (const name of ["network-wireless-0-locked-symbolic", "network-wireless-60-locked-symbolic"])
            compare(Metrics.networkReferenceName(name), "network-wireless-100-locked-symbolic");
        for (const name of ["network-wireless-0-limited-symbolic", "network-wireless-60-limited-symbolic"])
            compare(Metrics.networkReferenceName(name), "network-wireless-100-limited-symbolic");
        compare(Metrics.networkReferenceName("network-unavailable-symbolic"), "network-unavailable-symbolic");
        compare(Metrics.networkReferenceName("network-wired-symbolic"), "network-wired-symbolic");
        compare(Metrics.networkReferenceName("network-wireless-hotspot-symbolic"), "network-wireless-hotspot-symbolic");
    }
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
        compare(Metrics.coreCellLength(16, 16, 1), 24);
        compare(Metrics.coreCellLength(16, 16, 6), 32);
        compare(Metrics.coreCellLength(32, 32, 2), 40);
        compare(Metrics.coreCellLength(18, 18, 1), 26);
        compare(Metrics.coreCellLength(18, 18, 6), 32);
        compare(Metrics.coreCellLength(20, 20, 1), 28);
        compare(Metrics.coreCellLength(20, 20, 6), 32);
        compare(Metrics.paddedCoreContentLength(16), 24);
        compare(Metrics.paddedCoreContentLength(46), 54);
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
    function test_groupSymmetricPaddingAndCenter() {
        const cell = Metrics.coreCellLength(16, 16, 2);
        const leading = Metrics.systemEdgeInset(true, false, cell, 16);
        compare(leading, 6);
        compare(Metrics.systemEdgeInset(true, true, cell, 16), 0);
        compare(Metrics.systemEdgeInset(false, false, cell, 16), 0);
        for (const batteryContent of [16, 20, 46, 60]) {
            const lastCell = Math.max(cell, Metrics.paddedCoreContentLength(batteryContent));
            const trailing = Metrics.systemEdgeInset(true, false, lastCell, batteryContent);
            const runWidth = leading + cell * 2 + lastCell + trailing;
            const firstCenter = leading + cell / 2;
            const lastCenter = leading + cell * 2 + lastCell / 2;
            const rect = Metrics.groupHoverRect({x: 0, y: 3, width: runWidth, height: 42}, 48, false);
            compare(firstCenter - 8 - rect.x, 8);
            compare(rect.x + rect.width - lastCenter - batteryContent / 2, 8);
            for (const scale of [1, 1.5, 2]) {
                compare(rect.height * scale, 40 * scale);
                compare((rect.y + rect.height / 2) * scale, 24 * scale);
                compare((leading + cell + cell / 2 - firstCenter) * scale, 24 * scale);
            }
        }
        const short = Metrics.groupHoverRect({x: 0, y: 0, width: 72, height: 30}, 48, false);
        compare(short.height, 30);
        const vertical = Metrics.groupHoverRect({x: 3, y: 0, width: 42, height: 72}, 48, true);
        compare(vertical.width, 40);
        compare(vertical.x + vertical.width / 2, 24);
    }
    function test_quickSettingsDetailPageMetrics() {
        compare(Metrics.detailActionButtonHeight, 30);
        compare(Metrics.detailRowOuterInset, 8);
        compare(Metrics.detailContentInset, 12);
        compare(Metrics.detailRowSpacing, 12);
        compare(Metrics.detailRowIconExtent, 24);
    }
    function test_quickTileRadiusUsesControlCornerRadius() {
        for (const scale of [0.75, 1, 1.25, 1.5, 2])
            compare(Metrics.quickTileRadius(scale),
                Math.max(3, Math.round(ControlMetrics.controlCornerRadius * scale)));
    }
    function test_sharedFlyoutGeometry() {
        for (const scale of [0.75, 1, 1.25, 1.5, 2]) {
            const width = Metrics.flyoutWidth(900, scale, false, 0);
            compare(width, Math.round(376 * scale));
            compare(Metrics.flyoutWidth(900, scale, false, 0, false), Math.round(360 * scale));
            compare(Metrics.flyoutWidth(900, scale, true, 0), Math.round(216 * scale));
            const height = Metrics.quickSettingsHeight(700, Math.round(376 * scale));
            compare(height, Math.min(700, Math.round(376 * scale)));
        }
        compare(Metrics.flyoutWidth(280, 1, false, 0), 280);
        compare(Metrics.quickSettingsHeight(310, 420), 310);
        compare(Metrics.quickSettingsHeight(700, 376, 400), 400);
        compare(Metrics.quickSettingsHeight(350, 376, 400), 350);
        compare(Metrics.quickSettingsHeight(700, 430, 400), 430);
        compare(Metrics.flyoutWidth(900, 1, false, 12), 364);
        compare(Metrics.splitSecondaryWidth(120, 1), 48);
        compare(Metrics.splitSecondaryWidth(72, 1), 36);
        compare(Metrics.splitSecondaryWidth(180, 1.5), 72);
    }
    function test_mediaAllocation() {
        verify(Metrics.mediaFits(528, 286, 12, 178));
        verify(!Metrics.mediaFits(470, 286, 12, 178));
        verify(Metrics.mediaFits(476, 286, 12, 178));
        compare(Metrics.quickSettingsHeight(528 - 12 - 178, 286), 286);
    }
    function test_overflowUsesOneGeometryPlan() {
        for (const scale of [0.35, 0.75, 1, 1.25, 1.5, 2]) {
            const width = Math.round(216 * scale);
            for (const count of [0, 1, 5, 6, 15, 16, 40]) {
                const g = Metrics.overflowGeometry(width, 720, scale, count);
                compare(g.rows, Math.ceil(count / 5));
                compare(g.height, g.contentHeight + g.inset * 2);
                verify(Math.abs(g.cellWidth * 5 + g.railWidth + g.inset * 2 - width) < 0.001);
                compare(g.scrolls, count > 15);
                verify(g.contentHeight <= Math.max(1, Math.min(Math.max(1, g.rows), 3) * g.cellHeight));
                verify(g.cellWidth > 0 && g.cellHeight > 0);
            }
        }
        const short = Metrics.overflowGeometry(216, 65, 1, 12);
        verify(short.scrolls);
        verify(short.height <= 65);
        verify(short.maximumRows < 3);
        const tiny = Metrics.overflowGeometry(10, 5, 1, 1);
        verify(tiny.height <= 5 && tiny.cellWidth > 0);
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
