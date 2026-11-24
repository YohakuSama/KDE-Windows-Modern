// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Windows Modern at 100%: 48px taskbar, 30px task icons, 20px tray icon canvas.
// DPI is applied by Qt, never by multiplying the logical size by screen DPR.
// Explicit panel-size scaling remains an opt-in; 48px always gives 20px.
function iconSize(thickness, scaleToFit) {
    const limit = Math.max(1, Math.floor(thickness));
    const requested = scaleToFit ? Math.max(20, Math.min(32, Math.round(limit * 5 / 12))) : 20;
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
    // Keep 32/24px normal cells while increasing the actual ink area.
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
