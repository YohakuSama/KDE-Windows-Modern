// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Microsoft Windows 11 app-icon construction specifies 16px tray and
// 24px taskbar app icon resources at 100%, 24px/36px at 150%.
// The 16px value is the optical design slot, not a requirement to render
// every SVG at 16px. Imported glyphs already fill ~23/24 of their canvas;
// older fallback artwork can contain substantial transparent padding.
// Normalize only the latter, and let Qt apply display DPI exactly once.
const defaultTraySize = 16;
function iconSize(thickness, scaleToFit) {
    const limit = Math.max(1, Math.floor(thickness));
    const requested = scaleToFit ? Math.max(defaultTraySize, Math.min(32, Math.round(limit / 3))) : defaultTraySize;
    return Math.min(limit, requested);
}

function coreIconSize(thickness, scaleToFit) {
    return iconSize(thickness, scaleToFit);
}

// Match the visible size of the normalized imports (~23/24) without
// enlarging already-full artwork. The cap preserves intentional shapes and
// prevents tiny/broken glyphs from producing oversized canvases.
function opticalPlacement(bounds, slotWidth, slotHeight) {
    const extent = Math.max(bounds.width, bounds.height);
    const valid = Number.isFinite(extent) && extent > 0
        && Number.isFinite(bounds.x) && Number.isFinite(bounds.y);
    const b = valid ? bounds : {x: 0, y: 0, width: 1, height: 1};
    const factor = valid && extent < 0.90 ? Math.min(1.5, (23 / 24) / extent) : 1;
    const side = Math.max(0, Math.min(slotWidth, slotHeight)) * factor;
    return {
        width: side, height: side, factor: factor,
        x: (slotWidth - side) / 2 + (0.5 - b.x - b.width / 2) * side,
        y: (slotHeight - side) / 2 + (0.5 - b.y - b.height / 2) * side
    };
}

// Wi-Fi signal bars must not grow or move when the signal level changes.
// The importer already uses a common transform for each of these families.
function networkReferenceName(name) {
    const n = String(name || "");
    if (/^network-wireless-(?:connected-)?[0-9]+-symbolic$/.test(n))
        return "network-wireless-symbolic";
    if (/^network-wireless-[0-9]+-locked-symbolic$/.test(n))
        return "network-wireless-100-locked-symbolic";
    if (/^network-wireless-[0-9]+-limited-symbolic$/.test(n))
        return "network-wireless-100-limited-symbolic";
    return n;
}

// Native fallback host, distinct from the visible optical slot.
function coreRenderSize(displaySize) {
    if (displaySize < 16) return 16;
    if (displaySize <= 32) return 32;
    return 48;
}

// Windows 26300.9974 SystemTrayResources.xbf: SystemTrayIconContentPadding
// (4,0,4,0), referenced by ordinary image and battery content grids.
// Adapt the same padding along the primary axis on vertical panels.
const trayContentPadding = 4;
function paddedCoreContentLength(contentLength) {
    return Math.ceil(contentLength) + 2 * trayContentPadding;
}

function coreCellLength(size, coreSize, spacing) {
    return Math.max(cellLength(size, true, spacing), paddedCoreContentLength(coreSize));
}

function isQuickSettings(id) {
    return id === "org.kde.plasma.networkmanagement"
        || id === "org.kde.plasma.volume"
        || id === "org.kde.plasma.battery";
}

function cellLength(size, compact, spacing) {
    // Normal Windows notification items/chevron: 32; core group: 24.
    // Keep the existing KDE spacing choices without tying them to font size.
    const extra = spacing === 1 ? 8 : spacing === 6 ? 24 : 16;
    // Preserve 32/24px normal hit cells independently of the glyph canvas.
    // Above the default size, the minimum four-pixel cell inset still applies.
    const opticalInset = Math.max(0, Math.min(4, size - 16));
    return Math.max(size + 4, size + extra - opticalInset - (compact ? 8 : 0));
}

// A contiguous system group has equal optical outer padding. Its first
// and last cells may contain different widths (Wi-Fi vs. battery + text).
// Keep the natural internal pitch; only add padding at the outside edges.
function systemEdgeInset(systemGroup, adjacentSystemGroup, cellLength, contentLength) {
    if (!systemGroup || adjacentSystemGroup) return 0;
    const naturalInset = Math.max(0, (cellLength - contentLength) / 2);
    return Math.max(0, Math.round(10 - naturalInset));
}

// A 48px taskbar has a centered 40px hover surface. The containment
// can be shorter due to its parent frame; never extend beyond that cell.
function groupHoverRect(run, panelExtent, vertical) {
    const cross = Math.max(0, Math.min(vertical ? run.width : run.height, panelExtent - 8));
    return vertical
        ? {x: run.x + (run.width - cross) / 2, y: run.y + 2,
           width: cross, height: Math.max(0, run.height - 4)}
        : {x: run.x + 2, y: run.y + (run.height - cross) / 2,
           width: Math.max(0, run.width - 4), height: cross};
}

function visualIndex(index, count, vertical, reversed) {
    return vertical && reversed ? Math.max(0, count - index - 1) : index;
}

 // Group by physical adjacency, after the Qt layout has positioned the
 // delegates. Non-system icons always break a run (including in RTL).
function groupRects(cells, vertical) {
    const ordered = cells.filter(c => c.width > 0 && c.height > 0)
        .slice().sort((a, b) => vertical ? a.y - b.y : a.x - b.x);
    const result = [];
    let run = null;
    for (const c of ordered) {
        if (!c.systemGroup) {
            run = null;
            continue;
        }
        if (!run) {
            run = {x: c.x, y: c.y, width: c.width, height: c.height};
            result.push(run);
        } else {
            const right = Math.max(run.x + run.width, c.x + c.width);
            const bottom = Math.max(run.y + run.height, c.y + c.height);
            run.x = Math.min(run.x, c.x);
            run.y = Math.min(run.y, c.y);
            run.width = right - run.x;
            run.height = bottom - run.y;
        }
    }
    return result;
}

// Choose the run containing the clicked cell; keyboard activation uses the
// trailing system group in the actual (possibly mirrored) layout.
function anchorRun(runs, point, vertical, mirrored) {
    if (!runs || runs.length === 0) return null;
    if (point) {
        const hit = runs.find(r => point.x >= r.x && point.x <= r.x + r.width
            && point.y >= r.y && point.y <= r.y + r.height);
        if (hit) return hit;
    }
    return runs[!vertical && mirrored ? 0 : runs.length - 1];
}


// Windows 26300.9974 paginatedcontrolcenterview.xbf and controlcenterstyles.xbf.
// See docs/windows11-26h2-ui-parameters.json for literal and consumer evidence.
// Values are logical pixels; scale is the existing optional applet UI scale,
// not the screen devicePixelRatio.
const quickPanelWidth = 376;
const standardFlyoutWidth = 360;
const quickDetailMinimumHeight = 400;
const quickFooterHeight = 48;
const quickToggleHeight = 48;
const quickContentInset = 24;
const quickTileCaptionLines = 2;
const quickSliderRowHeight = 36;
const quickSliderGlyphSize = 20;
const splitSecondaryExtent = 48;
const sliderTrackHeight = 4;
const mediaCardHeight = 178;
const mediaCardGap = 12;
const mediaButtonExtent = 40;
const mediaGlyphExtent = 16;
const mediaPlayPauseMargin = 26;

// Normal and split tiles use the same geometry and caption metrics.
function quickTileScale(buttonHeight) {
    return buttonHeight > 0 ? buttonHeight / quickToggleHeight : 1;
}

function quickTileCaptionHeight(scale, lineSpacing) {
    return Math.max(Math.round(30 * scale), Math.ceil(quickTileCaptionLines * lineSpacing));
}

function quickTileSpacing(scale) {
    return Math.round(8 * scale);
}

function quickTileRadius(scale) {
    return Math.max(3, Math.round(4 * scale));
}

function quickTileGlyphSize(scale) {
    return Math.max(12, Math.round(16 * scale));
}

function quickTileCaptionFontSize(scale) {
    return Math.max(10, Math.round(12 * scale));
}

function splitSecondaryWidth(width, scale) {
    // Clamp for a narrow cell; retain both targets with one shared border.
    return Math.max(0, Math.min(width / 2, Math.round(splitSecondaryExtent * scale)));
}

// The KDE card contains the paginated view without the outer Windows host
// frame. Overflow and other applet routes retain their existing widths.
function flyoutWidth(availableWidth, scale, overflow, frameWidth, paginated = true) {
    const base = overflow ? 216 : paginated ? quickPanelWidth : standardFlyoutWidth;
    return Math.max(1, Math.min(availableWidth, Math.round(base * scale)) - frameWidth);
}
// Overflow content and its native popup must use the same pitch. Decide
// rail visibility before deriving the rail-reduced cell width, so a
// scrollbar cannot create a width/height/visibility feedback loop.
function overflowGeometry(width, availableHeight, scale, count) {
    const w = Math.max(1, Math.floor(width));
    const budget = Math.max(1, Math.floor(availableHeight));
    const inset = Math.max(0, Math.min(Math.round(8 * scale),
        Math.floor((w - 1) / 2), Math.floor((budget - 1) / 2)));
    const innerWidth = w - 2 * inset;
    const innerBudget = budget - 2 * inset;
    const columns = 5;
    const rows = Math.ceil(Math.max(0, count) / columns);
    const nominalPitch = Math.max(1, Math.round(innerWidth / columns));
    const maximumRows = Math.max(1, Math.min(3, Math.floor(innerBudget / nominalPitch)));
    const scrolls = rows > maximumRows || rows * nominalPitch > innerBudget;
    const railWidth = scrolls ? Math.min(16, Math.max(0, innerWidth - columns)) : 0;
    const cellWidth = (innerWidth - railWidth) / columns;
    const cellHeight = Math.max(1, Math.round(cellWidth));
    const contentHeight = Math.min(innerBudget, Math.max(1, Math.min(Math.max(1, rows), maximumRows) * cellHeight));
    return {inset, rows, maximumRows, scrolls, railWidth, cellWidth, cellHeight,
        contentHeight, height: contentHeight + 2 * inset};
}

// Keep a real media session reachable whenever one complete tile row and
// the fixed controls fit beside its card. The grid can page later rows.
function mediaFits(availableHeight, minimumHomeHeight, mediaGap, mediaHeight) {
    return availableHeight >= minimumHomeHeight + mediaGap + mediaHeight;
}

function quickSettingsHeight(availableHeight, nominalHeight, detailMinimum = 0) {
    return Math.max(1, Math.min(availableHeight, Math.max(nominalHeight, detailMinimum)));
}
