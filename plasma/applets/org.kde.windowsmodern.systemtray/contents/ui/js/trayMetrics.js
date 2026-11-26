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

function coreCellLength(size, coreSize, spacing) {
    // Default core cells are 24px, not the previous 30px.
    return Math.max(cellLength(size, true, spacing), coreSize + 4);
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


// All quick settings routes share an outer logical width and card height.
// Native frame margins are used only by overflow/unsupported applets.
function flyoutWidth(availableWidth, scale, overflow, frameWidth) {
    return Math.max(1, Math.min(availableWidth, Math.round((overflow ? 216 : 360) * scale)) - frameWidth);
}
function quickSettingsHeight(availableHeight, nominalHeight) {
    return Math.max(1, Math.min(availableHeight, nominalHeight));
}
