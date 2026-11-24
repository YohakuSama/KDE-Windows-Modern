// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/js/quickSettingsOrder.js" as Order

TestCase {
    name: "WindowsQuickSettingsScroll"
    function test_fullThumbTravel() {
        for (const fraction of [0, 0.25, 0.5, 0.75, 1]) {
            fuzzyCompare(Order.thumbOffset(12 + 76 * fraction, 12, 100, 24, 200), 200 * fraction, 0.01);
        }
        compare(Order.thumbOffset(-20, 12, 100, 24, 200), 0);
        compare(Order.thumbOffset(200, 12, 100, 24, 200), 200);
        compare(Order.thumbOffset(12, 12, 24, 24, 0), 0);
    }
    function test_wheel() {
        compare(Order.wheelDistance(0, 120, 80), 80);
        compare(Order.wheelDistance(15, 120, 80), 80);
        compare(Order.wheelDistance(7, 15, 80), 7);
        compare(Order.wheelDistance(0, -240, 80), -160);
    }
}
