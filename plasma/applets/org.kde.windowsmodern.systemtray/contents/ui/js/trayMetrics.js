// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Microsoft Windows 11 app-icon construction specifies 16px tray and
// 24px taskbar app icon resources at 100%, 24px/36px at 150%.
// Imported symbolic status glyphs already have normalized optical bounds
// (23/24 of the source em). Do NOT compensate for their old transparent
// margins a second time. Qt alone applies display DPI.
// The standard 48px panel stays at 16px in both sizing modes.
const defaultTraySize = 16;
function iconSize(thickness, scaleToFit) {
    const limit = Math.max(1, Math.floor(thickness));
    const requested = scaleToFit ? Math.max(defaultTraySize, Math.min(32, Math.round(limit / 3))) : defaultTraySize;
    return Math.min(limit, requested);
}

function coreIconSize(thickness, scaleToFit) {
    return iconSize(thickness, scaleToFit);
}

// Fallback host for native compact applets, used only if the direct status
// glyph component cannot load. It does not determine the rendered glyph size.
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
