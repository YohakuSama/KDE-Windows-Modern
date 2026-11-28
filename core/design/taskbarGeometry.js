// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Taskbar cells share a single logical icon canvas. Qt handles physical
// output scaling; the icon keeps its original optical padding.
const iconCanvas = 30;
const tileInset = 2;
// Windows 11 26H2 JumpViewUI/RefreshedStyles.xbf: TaskbarJumpListFrameWidth = 294 (@5862),
// JumpListControlWidth = 294 (@5871), ToolTipMargin = 12 (TaskbarConstants.xbf @5188).
const taskbarJumpListWidth = 294;
const taskbarToolTipMargin = 12;

function panelTileInset() { return tileInset; }

function iconCanvasSize(width, height) {
    return Math.max(0, Math.min(iconCanvas, Math.floor(Math.min(width, height) - 2 * tileInset)));
}
