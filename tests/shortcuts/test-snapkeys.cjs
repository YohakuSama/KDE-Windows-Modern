// SPDX-License-Identifier: GPL-3.0-or-later
// Run: node tests/shortcuts/test-snapkeys.cjs
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const area = {x: -1600, y: 40, width: 1600, height: 900};
let called = "";
const workspace = {clientArea() { return area; }, activeWindow: null};
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
        tile: null, frameGeometry: geometry, ...props};
    ctx[direction]();
    assert.equal(called, expected);
    assert.equal(workspace.activeWindow.minimized, minimized);
}
run("snapDown", area, {}, "", true);
run("snapDown", area, {maximizeMode: 3}, "Maximize");
run("snapUp", {...area, width: 1500}, {maximizeMode: 3}, "");
run("snapUp", half, {}, "QuickTileTopLeft");
run("snapDown", half, {tile: {}}, "QuickTileBottomLeft");
run("snapUp", {...half, x: -800}, {}, "QuickTileTopRight");
run("snapDown", {...half, x: -800}, {}, "QuickTileBottomRight");
run("snapDown", top, {}, "QuickTileLeft");
run("snapDown", {...top, x: -800}, {}, "QuickTileRight");
run("snapUp", bottom, {}, "QuickTileLeft");
run("snapUp", {...bottom, x: -800}, {}, "QuickTileRight");
run("snapDown", top, {tile: {}}, "QuickTileBottom");
run("snapUp", bottom, {tile: {}}, "QuickTileTop");
run("snapDown", bottom, {}, "", true);
run("snapUp", area, {fullScreen: true}, "");
run("snapDown", area, {deleted: true}, "");
console.log("Snap shortcut tests passed.");
