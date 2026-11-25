/*
    On-screen displays (volume, brightness, keyboard layout...) bottom-centre,
    just above the taskbar, as on Windows 11. KWin places them two-thirds of
    the way down the screen; this moves each one when it appears and keeps
    it anchored there when its size changes.

    SPDX-FileCopyrightText: 2026 Jeysef
    SPDX-License-Identifier: GPL-3.0-or-later
*/

const GAP = 12; // logical pixels between the OSD and the taskbar (or screen edge)

function position(area, g) {
    if (![area.x, area.y, area.width, area.height, g.width, g.height].every(Number.isFinite)
        || area.width <= 0 || area.height <= 0 || g.width <= 0 || g.height <= 0) {
        return null;
    }
    // Preserve the native OSD size. On a work area smaller than the OSD,
    // anchor at the visible top/left rather than moving its start off-screen.
    return {
        x: Math.round(area.x + Math.max(0, (area.width - g.width) / 2)),
        y: Math.round(area.y + Math.max(0, area.height - g.height - GAP))
    };
}

function place(win) {
    const g = win.frameGeometry;
    const target = position(workspace.clientArea(KWin.MaximizeArea, win), g);
    if (target && (g.x !== target.x || g.y !== target.y)) {
        win.frameGeometry = { x: target.x, y: target.y, width: g.width, height: g.height };
    }
}

const watchers = new Map();

function watch(win) {
    if (!win || !win.onScreenDisplay || watchers.has(win)) return;
    let placing = false;
    const reposition = () => {
        // Geometry assignment can synchronously emit frameGeometryChanged.
        // Prevent recursion if the compositor constrains the requested move.
        if (placing) return;
        placing = true;
        try {
            place(win);
        } finally {
            placing = false;
        }
    };
    watchers.set(win, reposition);
    win.frameGeometryChanged.connect(reposition);
    win.outputChanged.connect(reposition);
    reposition();
}

function repositionVisibleOsds() {
    for (const reposition of watchers.values()) reposition();
}

workspace.windowAdded.connect(watch);
workspace.windowRemoved.connect(win => watchers.delete(win));
workspace.screensChanged.connect(repositionVisibleOsds);
workspace.virtualScreenGeometryChanged.connect(repositionVisibleOsds);
workspace.windowList().forEach(watch);
