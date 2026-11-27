// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Logical pixels, independent of applet scale. Match the gap between the
// visible panel and popup, not the smaller button's padded hit target.
const gap = 12;

function popupGap() { return gap; }

function availableExtent(extent, panelExtent, inset, fallback) {
    if (!Number.isFinite(extent) || extent <= 0) return fallback;
    const panel = Number.isFinite(panelExtent) ? Math.max(0, panelExtent) : 0;
    const margin = Number.isFinite(inset) ? Math.max(0, inset) : 0;
    return Math.max(1, Math.floor(extent - panel - margin));
}

function validRect(rect) {
    return rect && Number.isFinite(rect.x) && Number.isFinite(rect.y)
        && Number.isFinite(rect.width) && rect.width > 0
        && Number.isFinite(rect.height) && rect.height > 0;
}

function normalOffset(edge, panel, anchor) {
    // During a screen or panel move, the two rectangles can briefly refer
    // to different outputs. Do not turn that stale delta into a popup jump.
    const valid = validRect(panel) && validRect(anchor)
        && anchor.x < panel.x + panel.width && anchor.x + anchor.width > panel.x
        && anchor.y < panel.y + panel.height && anchor.y + anchor.height > panel.y;
    const result = {x: 0, y: 0};
    switch (edge) {
    case "bottom":
        result.y = (valid ? panel.y - anchor.y : 0) - gap; break;
    case "top":
        result.y = (valid ? panel.y + panel.height - anchor.y - anchor.height : 0) + gap; break;
    case "left":
        result.x = (valid ? panel.x + panel.width - anchor.x - anchor.width : 0) + gap; break;
    case "right":
        result.x = (valid ? panel.x - anchor.x : 0) - gap; break;
    }
    return result;
}
