/*
    Win+Up / Win+Down as on Windows 11.

    KWin's own Meta+Up / Meta+Down snap a window to the top or bottom half.
    On Windows the keys depend on where the window is:

                     Win+Up               Win+Down
      normal         maximize             minimize
      maximized      -                    restore
      left half      top-left quarter     bottom-left quarter
      right half     top-right quarter    bottom-right quarter
      top quarter    maximize             back to the half
      bottom quarter back to the half     minimize

    Where the window is comes from its geometry against the work area (KWin's
    scripting API does not expose the quick-tile mode), with some tolerance
    for decorations and tile gaps. For windows already snapped, KWin's own
    "quick tile top/bottom" combine exactly like Windows (left + bottom =
    bottom-left, top-left + bottom = left), so those are used. KWin's "quick
    tile left" on a window already on the left would move it elsewhere.
    Windows placed by Snap Layouts may have no native tile; use explicit
    corner and side actions for those windows.

    SPDX-FileCopyrightText: 2026 Jeysef
    SPDX-License-Identifier: GPL-3.0-or-later
*/

const TOLERANCE = 16;
// KWin::MaximizeFull = MaximizeVertical (1) | MaximizeHorizontal (2).
// The JavaScript KWin object exports Workspace enums, not MaximizeMode.
const MAXIMIZE_FULL = 3;

function near(a, b) {
    return Math.abs(a - b) <= TOLERANCE;
}

function fits(g, x, y, w, h) {
    return near(g.x, x) && near(g.y, y) && near(g.width, w) && near(g.height, h);
}

function placement(win) {
    if (Number(win.maximizeMode) === MAXIMIZE_FULL) return "maximized";
    const a = workspace.clientArea(KWin.MaximizeArea, win);
    const g = win.frameGeometry;
    if (!a || !g || a.width <= 0 || a.height <= 0) return "normal";
    const hw = a.width / 2;
    const hh = a.height / 2;
    if (fits(g, a.x, a.y, hw, a.height)) return "left";
    if (fits(g, a.x + hw, a.y, hw, a.height)) return "right";
    if (fits(g, a.x, a.y, hw, hh)) return "topLeft";
    if (fits(g, a.x + hw, a.y, hw, hh)) return "topRight";
    if (fits(g, a.x, a.y + hh, hw, hh)) return "bottomLeft";
    if (fits(g, a.x + hw, a.y + hh, hw, hh)) return "bottomRight";
    return "normal";
}

function activeNormalWindow() {
    const win = workspace.activeWindow;
    return win && win.normalWindow && !win.minimized && !win.fullScreen && !win.deleted ? win : null;
}

function snapUp() {
    const win = activeNormalWindow();
    if (!win) return;
    switch (placement(win)) {
    case "left": workspace.slotWindowQuickTileTopLeft(); break;
    case "right": workspace.slotWindowQuickTileTopRight(); break;
    case "bottomLeft":
        if (win.tile) workspace.slotWindowQuickTileTop();
        else workspace.slotWindowQuickTileLeft();
        break;
    case "bottomRight":
        if (win.tile) workspace.slotWindowQuickTileTop();
        else workspace.slotWindowQuickTileRight();
        break;
    case "maximized": break;
    default: // normal, top quarters
        if (win.maximizable) workspace.slotWindowMaximize();
    }
}

function snapDown() {
    const win = activeNormalWindow();
    if (!win) return;
    switch (placement(win)) {
    case "maximized": workspace.slotWindowMaximize(); break; // toggles back
    case "left": workspace.slotWindowQuickTileBottomLeft(); break;
    case "right": workspace.slotWindowQuickTileBottomRight(); break;
    case "topLeft":
        if (win.tile) workspace.slotWindowQuickTileBottom();
        else workspace.slotWindowQuickTileLeft();
        break;
    case "topRight":
        if (win.tile) workspace.slotWindowQuickTileBottom();
        else workspace.slotWindowQuickTileRight();
        break;
    default: // normal, bottom quarters
        if (win.minimizable) win.minimized = true;
    }
}

// Default keys are empty: KWin's quick-tile actions own Meta+Up/Down until
// scripts/windows-shortcuts.py moves the keys here.
registerShortcut("Windows Modern: Maximize or Snap Up", "Windows Modern: Maximize or snap up (Win+Up)", "", snapUp);
registerShortcut("Windows Modern: Restore, Minimize or Snap Down", "Windows Modern: Restore, minimize or snap down (Win+Down)", "", snapDown);
