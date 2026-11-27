// The shared Search / Task View taskbar button (TaskbarButton.qml) and the
// Search applet's search box (SearchBox.qml): activation by mouse and
// keyboard, accessible names, the glyph size (Icon Tasks' rule), the hover
// tile and the search box's geometry.

import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.search/contents/ui"
import "../../plasma/applets/org.kde.windowsmodern.search/contents/ui/controlMetrics.js" as ControlMetrics

Item {
    id: root
    width: 200
    height: 200

    TestCase {
        id: testCase
        name: "TaskbarButton"
        when: windowShown

        Component {
            id: buttonComponent
            TaskbarButton {
                width: 48
                height: 48
                iconName: "edit-find-symbolic"
                text: "Search"
                description: "Open Start and search"
            }
        }

        SignalSpy {
            id: triggeredSpy
            signalName: "triggered"
        }

        function makeButton(props) {
            const button = createTemporaryObject(buttonComponent, root, props || {});
            verify(button);
            triggeredSpy.clear();
            triggeredSpy.target = button;
            return button;
        }

        function test_themeIcon() {
            const button = makeButton();
            const icon = findChild(button, "taskbarButtonIcon");
            verify(icon);
            compare(icon.source, "edit-find-symbolic");
        }

        function test_originalIconStates() {
            const button = makeButton({
                iconName: "idle.png", iconIsMask: false,
                hoverIconName: "hover.png", hoverIconIsMask: false,
                selectedIconName: "selected.svg", selectedIconIsMask: true
            });
            mouseMove(root, root.width - 1, root.height - 1);
            compare(button.effectiveIconName, "idle.png");
            compare(button.effectiveIconIsMask, false);
            button.forceHovered = true;
            compare(button.effectiveIconName, "hover.png");
            compare(button.effectiveIconIsMask, false);
            button.selected = true;
            compare(button.effectiveIconName, "selected.svg");
            compare(button.effectiveIconIsMask, true);
        }

        function test_click() {
            const button = makeButton();
            mouseClick(button);
            compare(triggeredSpy.count, 1);
        }

        function test_keys_data() {
            return [
                { tag: "space", key: Qt.Key_Space },
                { tag: "return", key: Qt.Key_Return },
                { tag: "enter", key: Qt.Key_Enter },
            ];
        }
        function test_keys(data) {
            const button = makeButton();
            button.forceActiveFocus();
            keyClick(data.key);
            compare(triggeredSpy.count, 1);
        }

        function test_otherKeyDoesNothing() {
            const button = makeButton();
            button.forceActiveFocus();
            keyClick(Qt.Key_A);
            compare(triggeredSpy.count, 0);
        }

        function test_accessible() {
            const button = makeButton();
            compare(button.Accessible.role, Accessible.Button);
            compare(button.Accessible.name, "Search");
            compare(button.Accessible.description, "Open Start and search");
        }

        // Match the 30px task icon canvas; only shrink when the cell is
        // narrower than the canvas plus the frame's borders.
        function test_glyphSize_data() {
            return [
                { tag: "zero-sized cell", cell: 0, expected: 0 },
                { tag: "cell smaller than inset", cell: 3, expected: 0 },
                { tag: "24px panel", cell: 24, expected: 20 },
                { tag: "30px panel", cell: 30, expected: 26 },
                { tag: "36px panel", cell: 36, expected: 30 },
                { tag: "48px panel", cell: 48, expected: 30 },
                { tag: "64px panel", cell: 64, expected: 30 },
            ];
        }
        function test_glyphSize(data) {
            const button = makeButton({ width: data.cell, height: data.cell });
            compare(button.glyphSize, data.expected);
        }

        // The hover tile is tasks.svg's hover frame: inset by its 2 px
        // borders at every cell size, square, centred.
        function test_tile_data() {
            return [
                { tag: "36px", cell: 36, size: 32 },
                { tag: "48px", cell: 48, size: 44 },
                { tag: "64px", cell: 64, size: 60 },
            ];
        }
        function test_tile(data) {
            const button = makeButton({ width: data.cell, height: data.cell });
            compare(button.tileInset, 2);
            compare(button.tileSize, data.size);
        }

        // A vertical panel gives a wide, short cell until the layout squares it;
        // the glyph follows the shorter side.
        function test_glyphFollowsShorterSide() {
            const button = makeButton({ width: 120, height: 30 });
            compare(button.glyphSize, 26);
            button.width = 12;
            button.height = 48;
            compare(button.glyphSize, 8);
            button.width = 0;
            compare(button.glyphSize, 0);
            verify(!findChild(button, "taskbarButtonIcon").visible);
        }

        function test_states() {
            const button = makeButton();
            verify(!button.showHovered);
            verify(!button.showPressed);
            button.forceHovered = true;
            verify(button.showHovered);
            button.forcePressed = true;
            verify(button.showPressed);
        }

        Component {
            id: boxComponent
            SearchBox {
                property bool mirroredLayout: false
                LayoutMirroring.enabled: mirroredLayout
                LayoutMirroring.childrenInherit: true
                height: 48
                width: preferredWidth
                iconName: "edit-find-symbolic"
                text: "Search"
                placeholder: "Search"
                description: "Open Start and search"
            }
        }

        function makeBox(props) {
            const box = createTemporaryObject(boxComponent, root, props || {});
            verify(box);
            triggeredSpy.clear();
            triggeredSpy.target = box;
            return box;
        }

        // Original 220px Wave3 minimum extent and 2px side margin.
        // Retain the constrained-height KDE adaptation.
        function test_boxGeometry_data() {
            return [
                { tag: "42px inset cell", thickness: 42, boxHeight: 36, boxWidth: 220, margin: 2 },
                { tag: "48px panel", thickness: 48, boxHeight: 36, boxWidth: 220, margin: 2 },
                { tag: "36px panel", thickness: 36, boxHeight: 31, boxWidth: 189, margin: 2 },
                { tag: "64px panel", thickness: 64, boxHeight: 36, boxWidth: 220, margin: 2 },
            ];
        }
        function test_boxGeometry(data) {
            const box = makeBox({ height: data.thickness });
            compare(box.boxHeight, data.boxHeight);
            compare(box.boxWidth, data.boxWidth);
            compare(box.sideMargin, data.margin);
            compare(box.preferredWidth, data.boxWidth + 2 * data.margin);
            const pill = findChild(box, "wmSearchPill");
            const icon = findChild(box, "searchBoxIcon");
            const label = findChild(box, "wmSearchPlaceholder");
            compare(pill.radius, Math.min(pill.height / 2, ControlMetrics.searchBoxCornerRadius));
            compare(icon.width, Math.round(pill.height * 20 / 36));
            compare(label.font.pixelSize, Math.round(data.boxHeight * 16 / 36));
        }

        function test_fullSearchNeutralStates() {
            const box = makeBox({height: 42});
            const pill = findChild(box, "wmSearchPill");
            compare(pill.restFill, box.darkTheme ? Qt.rgba(1, 1, 1, 0.1435) : Qt.color("#B3FFFFFF"));
            compare(pill.hoverFill, box.darkTheme ? Qt.rgba(1, 1, 1, 0.1659) : Qt.color("#80F9F9F9"));
            compare(pill.selectedFill, Qt.color(box.darkTheme ? "#B31E1E1E" : "#FFFFFF"));
            compare(pill.pressedFill, pill.selectedFill);
            box.forceHovered = true;
            tryCompare(pill, "color", pill.hoverFill);
            box.forcePressed = true;
            tryCompare(pill, "color", pill.pressedFill);
            box.forcePressed = false;
            box.selected = true;
            tryCompare(pill, "color", pill.selectedFill);
            tryCompare(pill.border, "color", box.darkTheme ? Qt.rgba(1, 1, 1, 0.18) : Qt.color("#0F000000"));
        }

        function test_originalSearchInsetsAndAnchor() {
            const box = makeBox({height: 48, width: 250});
            const pill = findChild(box, "wmSearchPill");
            const icon = findChild(box, "searchBoxIcon");
            const label = findChild(box, "wmSearchPlaceholder");
            compare(pill.width, 220);
            compare(icon.x, 11);
            compare(label.x, 37);
            compare(pill.width - label.x - label.width, 16);
            compare(box.surfaceRect, Qt.rect(pill.x, pill.y, pill.width, pill.height));
            box.mirroredLayout = true;
            tryCompare(icon, "x", 220 - 11 - icon.width);
            tryCompare(label, "x", 16);
            box.width = 160;
            compare(box.surfaceRect.width, 156);
        }

        function test_taskbarQueryMirror() {
            const box = makeBox({height: 42, selected: true, queryFocused: true});
            const label = findChild(box, "wmSearchPlaceholder");
            const caret = findChild(box, "wmTaskbarSearchCaret");
            compare(label.text, "Search");
            verify(caret.visible);
            box.queryText = "测试";
            box.queryCursor = 2;
            compare(label.text, "测试");
            verify(caret.x >= label.x && caret.x <= label.x + label.width);
            box.selected = false;
            compare(label.text, "Search");
            verify(!caret.visible);
        }

        function test_compactSearchAndSelection() {
            const box = makeBox({styleMode: 1, width: 120});
            verify(box.boxWidth >= 100);
            verify(box.boxWidth >= box.compactContentWidth);
            const pill = findChild(box, "wmSearchPill");
            compare(findChild(box, "searchBoxIcon").width, 16);
            box.forceHovered = true;
            tryCompare(pill, "color", pill.hoverFill);
            box.selected = true;
            tryCompare(pill, "color", Qt.color("#0078D4"));
            box.width = 20;
            verify(!findChild(box, "wmSearchPlaceholder").visible);
        }

        function test_boxFitsConstrainedCell_data() {
            return [
                {tag: "tiny thickness", width: 100, height: 12},
                {tag: "narrow panel", width: 20, height: 48},
                {tag: "zero width", width: 0, height: 48},
                {tag: "zero height", width: 80, height: 0}
            ];
        }
        function test_boxFitsConstrainedCell(data) {
            const box = makeBox({width: data.width, height: data.height});
            const pill = findChild(box, "wmSearchPill");
            const icon = findChild(box, "searchBoxIcon");
            const label = findChild(box, "wmSearchPlaceholder");
            verify(pill && icon && label);
            verify(pill.width >= 0 && pill.width <= box.width);
            verify(pill.height >= 0 && pill.height <= box.height);
            verify(pill.x >= 0 && pill.x + pill.width <= box.width);
            verify(pill.y >= 0 && pill.y + pill.height <= box.height);
            verify(icon.x >= 0 && icon.x + icon.width <= pill.width);
            verify(!label.visible || label.x + label.width <= pill.width);
        }

        function test_boxMirroredOrder() {
            const box = makeBox({width: 228, height: 48});
            const icon = findChild(box, "searchBoxIcon");
            const label = findChild(box, "wmSearchPlaceholder");
            verify(label.visible);
            verify(icon.x + icon.width <= label.x);
            box.mirroredLayout = true;
            tryVerify(() => label.x + label.width <= icon.x);
        }

        function test_boxClick() {
            const box = makeBox();
            mouseClick(box);
            compare(triggeredSpy.count, 1);
        }

        function test_boxKeys_data() {
            return [
                { tag: "space", key: Qt.Key_Space },
                { tag: "return", key: Qt.Key_Return },
            ];
        }
        function test_boxKeys(data) {
            const box = makeBox();
            box.forceActiveFocus();
            keyClick(data.key);
            compare(triggeredSpy.count, 1);
        }

        function test_boxAccessible() {
            const box = makeBox();
            compare(box.Accessible.role, Accessible.Button);
            compare(box.Accessible.name, "Search");
            compare(box.Accessible.description, "Open Start and search");
        }
    }
}
