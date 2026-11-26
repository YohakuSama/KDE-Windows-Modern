/*
    Windows 11 Snap Layouts (as on a 16:9 screen). Each layout is a list of
    cells; a cell is x, y, width, height as fractions of the work area.

    SPDX-FileCopyrightText: 2026 Jeysef
    SPDX-License-Identifier: GPL-3.0-or-later
*/
.pragma library

const layouts = [
    [[0, 0, 1 / 2, 1], [1 / 2, 0, 1 / 2, 1]],
    [[0, 0, 2 / 3, 1], [2 / 3, 0, 1 / 3, 1]],
    [[0, 0, 1 / 3, 1], [1 / 3, 0, 1 / 3, 1], [2 / 3, 0, 1 / 3, 1]],
    [[0, 0, 1 / 2, 1], [1 / 2, 0, 1 / 2, 1 / 2], [1 / 2, 1 / 2, 1 / 2, 1 / 2]],
    [[0, 0, 1 / 2, 1 / 2], [1 / 2, 0, 1 / 2, 1 / 2], [0, 1 / 2, 1 / 2, 1 / 2], [1 / 2, 1 / 2, 1 / 2, 1 / 2]],
    [[0, 0, 1 / 4, 1], [1 / 4, 0, 1 / 2, 1], [3 / 4, 0, 1 / 4, 1]],
];

// A cell of a layout on a work area, in whole pixels (cells share edges).
function cellRect(area, cell) {
    const x0 = Math.round(area.x + cell[0] * area.width);
    const y0 = Math.round(area.y + cell[1] * area.height);
    const x1 = Math.round(area.x + (cell[0] + cell[2]) * area.width);
    const y1 = Math.round(area.y + (cell[1] + cell[3]) * area.height);
    return { x: x0, y: y0, width: x1 - x0, height: y1 - y0 };
}

// Both pickers use identical rounded work-area geometry and constraints.
// Nonpositive maxima mean no upper limit.
function fitsSize(rect, minimum, maximum) {
    return rect.width > 0 && rect.height > 0
        && rect.width >= minimum.width && rect.height >= minimum.height
        && (maximum.width <= 0 || rect.width <= maximum.width)
        && (maximum.height <= 0 || rect.height <= maximum.height);
}

function hasFittingCell(area, minimum, maximum) {
    return layouts.some(layout => layout.some(cell =>
        fitsSize(cellRect(area, cell), minimum, maximum)));
}

// Keep the six diagrams within the available output. At the normal size
// the reference 72 x 44 diagrams and 10px gaps stay unchanged.
function barMetrics(availableWidth, availableHeight) {
    const count = layouts.length;
    const scale = Math.max(0, Math.min(1,
        availableWidth / (count * 72 + (count - 1) * 10), availableHeight / 44));
    return {
        width: Math.max(1, Math.floor(72 * scale)),
        height: Math.max(1, Math.floor(44 * scale)),
        gap: Math.floor(10 * scale),
        cellGap: Math.floor(3 * scale)
    };
}

// The layout cell at a point relative to the first diagram's top-left
// corner, for diagrams of size w x h laid out in a row with gap between
// them; or null.
function cellAt(lx, ly, w, h, gap, cellGap = 0) {
    if (ly < 0 || ly >= h || lx < 0) {
        return null;
    }
    const layout = Math.floor(lx / (w + gap));
    const dx = lx - layout * (w + gap);
    if (layout >= layouts.length || dx >= w) {
        return null;
    }
    const cells = layouts[layout];
    for (let i = 0; i < cells.length; ++i) {
        const c = cells[i];
        const inset = cellGap / 2;
        if (dx >= c[0] * w + inset && dx < (c[0] + c[2]) * w - inset
            && ly >= c[1] * h + inset && ly < (c[1] + c[3]) * h - inset) {
            return { layout: layout, cell: i };
        }
    }
    return null;
}
