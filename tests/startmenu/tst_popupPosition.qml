// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/code/popupPosition.js" as PopupPosition

TestCase {
    name: "StartMenuPopupPosition"

    function test_horizontalAnchorOffset_data() {
        return [
            {tag: "left bottom", mode: 0, screen: {x: 0, width: 1536}, button: {x: 0, width: 48}, expected: 0},
            {tag: "left with inset", mode: 0, screen: {x: 0, width: 1536}, button: {x: 8, width: 48}, expected: 0},
            {tag: "reported screenshot", mode: 0, screen: {x: 0, width: 1536}, button: {x: 650, width: 48}, expected: 0},
            {tag: "centered button", mode: 0, screen: {x: 0, width: 1920}, button: {x: 936, width: 48}, expected: 0},
            {tag: "centered group with many tasks", mode: 0, screen: {x: 0, width: 1920}, button: {x: 220, width: 48}, expected: 0},
            {tag: "right custom layout", mode: 0, screen: {x: 0, width: 1920}, button: {x: 1864, width: 48}, expected: 0},
            {tag: "left on negative monitor", mode: 0, screen: {x: -1920, width: 1920}, button: {x: -1912, width: 48}, expected: 0},
            {tag: "center on negative monitor", mode: 0, screen: {x: -1920, width: 1920}, button: {x: -1120, width: 48}, expected: 0},
            {tag: "center on secondary monitor", mode: 0, screen: {x: 1920, width: 1536}, button: {x: 2570, width: 48}, expected: 0},
            {tag: "fractional logical width", mode: 0, screen: {x: 0, width: 1280}, button: {x: 530.5, width: 41}, expected: 0},
            {tag: "auto left edge inset", mode: 0, screen: {x: 0, width: 1920}, button: {x: 0, width: 48}, popupWidth: 560, expected: 264},
            {tag: "auto right edge inset", mode: 0, screen: {x: 0, width: 1920}, button: {x: 1872, width: 48}, popupWidth: 560, expected: -264},
            {tag: "negative monitor inset", mode: 3, screen: {x: -1920, width: 1920}, button: {x: -1920, width: 48}, popupWidth: 560, expected: 264},
            {tag: "explicit centered", mode: 2, screen: {x: 0, width: 1920}, button: {x: 8, width: 48}, expected: 928},
            {tag: "legacy centered stays at panel", mode: 1, screen: {x: 0, width: 1920}, button: {x: 8, width: 48}, expected: 928},
            {tag: "explicit left", mode: 3, screen: {x: 0, width: 1920}, button: {x: 936, width: 48}, expected: -936},
            {tag: "invalid map to other screen", mode: 0, screen: {x: 1920, width: 1536}, button: {x: 0, width: 48}, expected: 0},
            {tag: "invalid screen width", mode: 0, screen: {x: 0, width: 0}, button: {x: 0, width: 48}, expected: 0},
            {tag: "zero button width", mode: 0, screen: {x: 0, width: 1920}, button: {x: 0, width: 0}, expected: 0},
            {tag: "small left aligned", mode: 0, screen: {x: 0, width: 480}, button: {x: 10, width: 48}, expected: 0}
            ,{tag: "short panel follow", mode: 0, screen: {x: 0, width: 1920}, panel: {x: 400, width: 800}, button: {x: 430, width: 48}, expected: 0}
            ,{tag: "short panel center", mode: 2, screen: {x: 0, width: 1920}, panel: {x: 400, width: 800}, button: {x: 430, width: 48}, expected: 346}
            ,{tag: "short panel left", mode: 3, screen: {x: 0, width: 1920}, panel: {x: 400, width: 800}, button: {x: 430, width: 48}, popupWidth: 560, expected: 226}
        ];
    }

    function test_horizontalAnchorOffset(data) {
        compare(PopupPosition.horizontalAnchorOffset(data.mode, data.screen, data.button, data.panel, data.popupWidth),
                data.expected);
    }
}
