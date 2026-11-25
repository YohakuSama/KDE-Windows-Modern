// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/code/popupPosition.js" as PopupPosition

TestCase {
    name: "StartMenuPopupPosition"

    function test_screenGeometryDuringPanelCreation() {
        compare(PopupPosition.screenGeometryOrEmpty(undefined), Qt.rect(0, 0, 0, 0));
        compare(PopupPosition.screenGeometryOrEmpty(null), Qt.rect(0, 0, 0, 0));
        compare(PopupPosition.screenGeometryOrEmpty({x: 0, y: 0, width: -1, height: 720}), Qt.rect(0, 0, 0, 0));
        compare(PopupPosition.screenGeometryOrEmpty(Qt.rect(-1920, 0, 1920, 1080)), Qt.rect(-1920, 0, 1920, 1080));
    }

    function test_horizontalAnchorOffset_data() {
        return [
            {tag: "left bottom", mode: 0, screen: {x: 0, width: 1536}, button: {x: 0, width: 48}, expected: 0},
            {tag: "left with inset", mode: 0, screen: {x: 0, width: 1536}, button: {x: 8, width: 48}, expected: 0},
            {tag: "reported screenshot", mode: 0, screen: {x: 0, width: 1536}, button: {x: 650, width: 48}, expected: 94},
            {tag: "centered button", mode: 0, screen: {x: 0, width: 1920}, button: {x: 936, width: 48}, expected: 0},
            {tag: "centered group with many tasks", mode: 0, screen: {x: 0, width: 1920}, button: {x: 220, width: 48}, expected: 716},
            {tag: "right custom layout", mode: 0, screen: {x: 0, width: 1920}, button: {x: 1864, width: 48}, expected: 0},
            {tag: "left on negative monitor", mode: 0, screen: {x: -1920, width: 1920}, button: {x: -1912, width: 48}, expected: 0},
            {tag: "center on negative monitor", mode: 0, screen: {x: -1920, width: 1920}, button: {x: -1120, width: 48}, expected: 136},
            {tag: "center on secondary monitor", mode: 0, screen: {x: 1920, width: 1536}, button: {x: 2570, width: 48}, expected: 94},
            {tag: "fractional logical width", mode: 0, screen: {x: 0, width: 1280}, button: {x: 530.5, width: 41}, expected: 89},
            {tag: "explicit centered", mode: 2, screen: {x: 0, width: 1920}, button: {x: 8, width: 48}, expected: 928},
            {tag: "legacy centered stays at panel", mode: 1, screen: {x: 0, width: 1920}, button: {x: 8, width: 48}, expected: 928},
            {tag: "explicit left", mode: 3, screen: {x: 0, width: 1920}, button: {x: 936, width: 48}, expected: -936},
            {tag: "invalid map to other screen", mode: 0, screen: {x: 1920, width: 1536}, button: {x: 0, width: 48}, expected: 0},
            {tag: "invalid screen width", mode: 0, screen: {x: 0, width: 0}, button: {x: 0, width: 48}, expected: 0},
            {tag: "zero button width", mode: 0, screen: {x: 0, width: 1920}, button: {x: 0, width: 0}, expected: 0},
            {tag: "small left aligned", mode: 0, screen: {x: 0, width: 480}, button: {x: 10, width: 48}, expected: 0}
        ];
    }

    function test_horizontalAnchorOffset(data) {
        compare(PopupPosition.horizontalAnchorOffset(data.mode, data.screen, data.button),
                data.expected);
    }
}
