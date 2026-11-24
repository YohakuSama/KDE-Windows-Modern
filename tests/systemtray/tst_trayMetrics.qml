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
        compare(Metrics.coreCellLength(32, 32, 2), 40);
        compare(Metrics.coreRenderSize(12), 16);
        compare(Metrics.coreRenderSize(16), 32);
        compare(Metrics.coreRenderSize(24), 32);
        compare(Metrics.coreRenderSize(32), 32);
    }
    function test_systemGroup() {
        verify(Metrics.isQuickSettings("org.kde.plasma.networkmanagement"));
        verify(Metrics.isQuickSettings("org.kde.plasma.volume"));
        verify(Metrics.isQuickSettings("org.kde.plasma.battery"));
        verify(!Metrics.isQuickSettings("org.kde.plasma.bluetooth"));
        verify(!Metrics.isQuickSettings("org.kde.plasma.keyboardlayout"));
        verify(!Metrics.isQuickSettings("third.party"));
    }
    function test_order() {
        compare(Metrics.visualIndex(0, 4, false, false), 0);
        compare(Metrics.visualIndex(0, 4, false, true), 0);
        compare(Metrics.visualIndex(0, 4, true, false), 0);
        compare(Metrics.visualIndex(0, 4, true, true), 3);
        compare(Metrics.visualIndex(3, 4, true, true), 0);
    }
}
