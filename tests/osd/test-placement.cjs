// SPDX-License-Identifier: GPL-3.0-or-later
// Run: node tests/osd/test-placement.cjs
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

let area = { x: 0, y: 0, width: 1920, height: 1032 };
let added, changed, outputChanged, removed, screensChanged, desktopGeometryChanged, writes = 0, reject = false;
let geometry = { x: 0, y: 0, width: 300, height: 80 };
const win = {
    onScreenDisplay: true,
    frameGeometryChanged: { connect(fn) { changed = fn; } },
    outputChanged: { connect(fn) { outputChanged = fn; } },
    get frameGeometry() { return geometry; },
    set frameGeometry(value) {
        ++writes;
        if (!reject) geometry = value;
        changed();
    }
};
const workspace = {
    clientArea() { return area; },
    windowAdded: { connect(fn) { added = fn; } },
    windowRemoved: { connect(fn) { removed = fn; } },
    screensChanged: { connect(fn) { screensChanged = fn; } },
    virtualScreenGeometryChanged: { connect(fn) { desktopGeometryChanged = fn; } },
    windowList() { return [win]; }
};
const source = fs.readFileSync(path.join(__dirname, "../../plasma/kwinscripts/org.kde.windowsmodern.osd/contents/code/main.js"), "utf8");
const ctx = vm.createContext({ workspace, KWin: { MaximizeArea: 0 } });
vm.runInContext(source, ctx);
const plain = value => JSON.parse(JSON.stringify(value));
assert.deepEqual(plain(geometry), { x: 810, y: 940, width: 300, height: 80 });
assert.equal(writes, 1);
changed();
assert.equal(writes, 1);
geometry = { ...geometry, width: 400 };
changed();
assert.deepEqual(plain(geometry), { x: 760, y: 940, width: 400, height: 80 });
assert.equal(writes, 2);
area = { x: -1280, y: 0, width: 1280, height: 672 };
reject = true;
changed();
assert.equal(writes, 3, "a rejected move must not recurse");
reject = false;
changed();
assert.deepEqual(plain(geometry), { x: -840, y: 580, width: 400, height: 80 });
assert.equal(writes, 4);
area = { x: 0, y: 0, width: 1600, height: 900 };
outputChanged();
assert.deepEqual(plain(geometry), { x: 600, y: 808, width: 400, height: 80 });
area = { x: 0, y: 0, width: 1280, height: 720 };
screensChanged();
assert.deepEqual(plain(geometry), { x: 440, y: 628, width: 400, height: 80 });
area = { x: -800, y: 0, width: 800, height: 600 };
desktopGeometryChanged();
assert.deepEqual(plain(geometry), { x: -600, y: 508, width: 400, height: 80 });
const beforeRemoval = writes;
added(win);
assert.equal(writes, beforeRemoval, "duplicate registration must be ignored");
removed(win);
area = { x: 0, y: 0, width: 1920, height: 1080 };
screensChanged();
assert.equal(writes, beforeRemoval, "closed OSD must not be repositioned");
added({ onScreenDisplay: false, frameGeometryChanged: { connect() { assert.fail("non-OSD watched"); } } });
for (const [screen, size, expected] of [
    [{ x: -1280, y: 100, width: 1280, height: 672 }, { width: 301, height: 90 }, { x: -790, y: 670 }],
    [{ x: 1920, y: -400, width: 800, height: 600 }, { width: 300, height: 80 }, { x: 2170, y: 108 }],
    [{ x: 20, y: 30, width: 240, height: 85 }, { width: 300, height: 80 }, { x: 20, y: 30 }],
    [{ x: 20, y: 30, width: 240, height: 70 }, { width: 300, height: 80 }, { x: 20, y: 30 }],
    [{ x: 0, y: 0, width: 0, height: 100 }, { width: 50, height: 50 }, null],
    [{ x: 0, y: 0, width: 100, height: 100 }, { width: 0, height: 50 }, null],
    [{ x: NaN, y: 0, width: 100, height: 100 }, { width: 50, height: 50 }, null]
]) assert.deepEqual(plain(ctx.position(screen, size)), expected);
console.log("OSD placement and signal re-entry tests passed.");
