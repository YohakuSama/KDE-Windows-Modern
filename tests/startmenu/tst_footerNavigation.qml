// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/code/footerNavigation.js" as FooterNavigation

TestCase {
    name: "StartFooterNavigation"

    function test_nextEnabledIndex_data() {
        return [
            { tag: "first", available: [false, true, false, true], current: -1, direction: 1, expected: 1 },
            { tag: "skip disabled", available: [false, true, false, true], current: 1, direction: 1, expected: 3 },
            { tag: "wrap forward", available: [false, true, false, true], current: 3, direction: 1, expected: 1 },
            { tag: "wrap backward", available: [false, true, false, true], current: 1, direction: -1, expected: 3 },
            { tag: "last", available: [false, true, false, true], current: -1, direction: -1, expected: 3 },
            { tag: "all disabled", available: [false, false], current: -1, direction: 1, expected: -1 },
            { tag: "power without hibernate", available: [false, false, false, false, true, false, true, true], current: 4, direction: 1, expected: 6 },
            { tag: "power with hibernate", available: [false, false, false, false, true, true, true, true], current: 4, direction: 1, expected: 5 },
            { tag: "power wraps backwards", available: [false, false, false, false, true, true, true, true], current: 4, direction: -1, expected: 7 },
            { tag: "no rows", available: [], current: 0, direction: 1, expected: -1 },
            { tag: "one enabled", available: [false, true, false], current: 1, direction: -1, expected: 1 },
            { tag: "stale index", available: [true, false, true], current: 12, direction: 1, expected: 0 },
            { tag: "current disabled", available: [true, true, false], current: 2, direction: -1, expected: 1 }
        ]
    }

    function test_nextEnabledIndex(data) {
        compare(FooterNavigation.nextEnabledIndex(data.available, data.current, data.direction), data.expected)
    }
}
