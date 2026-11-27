// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

.import "controlMetrics.js" as ControlMetrics

// Start menu geometry in logical pixels. Color and opacity tokens remain in theme.js.
const menuGlyphSize = 16;
const menuRowHeight = ControlMetrics.menuItemMinimumHeight;
const menuRowRadius = ControlMetrics.controlCornerRadius;
const menuRowTextVerticalPadding = 8;

function menuRowExtent(textHeight) {
    return Math.max(menuRowHeight, Math.ceil(textHeight) + menuRowTextVerticalPadding);
}

const menuInset = 4;
const menuRadius = ControlMetrics.overlayCornerRadius;
const menuBorderWidth = 1;
const menuRowBackgroundInset = 1;
const menuTextInset = 10;
const menuIconGap = 10;
const menuSeparatorHeight = 9;

const popupEdgeInset = 8;
const popupAnchorGap = 4;

const contextMenuMinimumWidth = 184;
const contextMenuMaximumWidth = 400;
const contextMenuShortcutGap = 24;
const contextMenuWidthPadding = 72;
const contextMenuSeparatorInset = 6;
const contextMenuSeparatorThickness = 1;

const viewModeMenuMinimumWidth = 160;
const viewModeMenuFallbackHeight = 120;
const viewModeMenuIconGap = 8;
const viewModeMenuRightReserve = 24;

const shutdownMenuMinimumWidth = 168;
const shutdownMenuTextWidthPadding = 64;
const shutdownMenuAnchorGap = 8;
