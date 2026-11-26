// SPDX-License-Identifier: GPL-3.0-or-later
// Run: node tests/shortcuts/test-snapkeys.cjs
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const area = {x: -1600, y: 40, width: 1600, height: 900};
let called = "";
const customRoot = {parent: null};
const quickRoot = {parent: null};
const output = {};
const workspace = {clientArea() { return area; }, rootTile() { return customRoot; },
    currentDesktop: {}, activeWindow: null};
function tile(x, y, width, height, parent = quickRoot) {
    return {parent, relativeGeometry: {x, y, width, height}};
}
for (const name of ["Maximize", "QuickTileTop", "QuickTileBottom", "QuickTileLeft",
    "QuickTileRight", "QuickTileTopLeft", "QuickTileTopRight", "QuickTileBottomLeft",
    "QuickTileBottomRight"])
    workspace["slotWindow" + name] = () => { called = name; };
const ctx = vm.createContext({workspace, KWin: {MaximizeArea: 0}, registerShortcut() {}});
const source = fs.readFileSync(path.join(__dirname,
    "../../plasma/kwinscripts/org.kde.windowsmodern.snapkeys/contents/code/main.js"), "utf8");
vm.runInContext(source, ctx);
const half = {x: area.x, y: area.y, width: 800, height: 900};
const top = {...half, height: 450};
const bottom = {...top, y: 490};
function run(direction, geometry, props, expected, minimized = false) {
    called = "";
    workspace.activeWindow = {normalWindow: true, maximizable: true, minimizable: true,
        minimized: false, deleted: false, fullScreen: false, maximizeMode: 0,
        tile: null, output, resizeable: true, moveable: true, frameGeometry: geometry, ...props};
    ctx[direction]();
    assert.equal(called, expected);
    assert.equal(workspace.activeWindow.minimized, minimized);
}
run("snapDown", area, {}, "", true);
run("snapDown", area, {maximizeMode: 3}, "Maximize");
run("snapUp", {...area, width: 1500}, {maximizeMode: 3}, "");
run("snapUp", half, {}, "QuickTileTopLeft");
run("snapDown", half, {tile: tile(0, 0, 0.5, 1)}, "QuickTileBottomLeft");
run("snapUp", {...half, x: -800}, {}, "QuickTileTopRight");
run("snapDown", {...half, x: -800}, {}, "QuickTileBottomRight");
run("snapDown", top, {}, "QuickTileLeft");
run("snapDown", {...top, x: -800}, {}, "QuickTileRight");
run("snapUp", bottom, {}, "QuickTileLeft");
run("snapUp", {...bottom, x: -800}, {}, "QuickTileRight");
run("snapDown", top, {tile: tile(0, 0, 0.5, 0.5)}, "QuickTileBottom");
run("snapUp", bottom, {tile: tile(0, 0.5, 0.5, 0.5)}, "QuickTileTop");
// Native tiles remain authoritative after resizing or while the frame
// is still processing the compositor's configure request.
run("snapUp", {...half, width: 560}, {tile: tile(0, 0, 0.35, 1)}, "QuickTileTopLeft");
run("snapDown", {...top, width: 560, height: 270},
    {tile: tile(0, 0, 0.35, 0.3)}, "QuickTileBottom");
run("snapUp", {...bottom, x: -1040, width: 1040, y: 310, height: 630},
    {tile: tile(0.35, 0.3, 0.65, 0.7)}, "QuickTileTop");
run("snapDown", top, {tile: tile(0, 0, 0.5, 0.5, customRoot)}, "", true);
run("snapUp", half, {resizeable: false}, "");
run("snapDown", half, {moveable: false}, "");
run("snapUp", half, {move: true}, "");
run("snapDown", half, {resize: true}, "");
run("snapDown", bottom, {}, "", true);
run("snapUp", area, {fullScreen: true}, "");
run("snapDown", area, {deleted: true}, "");
console.log("Snap shortcut tests passed.");
