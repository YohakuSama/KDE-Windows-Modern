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
const accountMenuMaximumWidth = 278;
const shutdownMenuTextWidthPadding = 64;
const shutdownMenuAnchorGap = 8;

// Dialog background.svg has 8px outer margins per side; 8 + 25 = 33px matches
// TaskbarSearchPageThemeResources.xbf StartCP3SearchBoxMargin [33, 17, 33, 10]
// and leaves exact 576 = 6x96 (Small) / 768 = 8x96 (Large) content columns.
const frameOuterInset = 8;
const contentSideMargin = 25;

// StartResources.xbf & TileStyles.xbf verified metrics.
const gridCellWidth = 96;
const gridCellHeight = 84;
const gridAppIconSize = 32;
const listAppIconSize = 24;
const listRowHeight = 40;
const sectionHeadingHeight = 40;
const categoryCardExtent = 156;
const categoryClusterSlotSize = 34;

// StartResources.xbf @79831/@79871: OpenKeySpline = "0,0 0,1", CloseKeySpline = "1,0 1,1".
const openSpline = [0, 0, 0, 1, 1, 1];
const closeSpline = [1, 0, 1, 1, 1, 1];

// Shared interior scroll-rail reserve when the scrollbar stays inside the content column.
const contentScrollGutter = 18;
