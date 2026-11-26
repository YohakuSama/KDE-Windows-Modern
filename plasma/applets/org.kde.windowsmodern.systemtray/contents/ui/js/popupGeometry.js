// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Logical pixels, independent of applet scale. Match the gap between the
// visible panel and popup, not the smaller button's padded hit target.
const gap = 12;

function popupGap() { return gap; }

function normalOffset(edge, panel, anchor) {
    const valid = panel && anchor && Number.isFinite(panel.x) && Number.isFinite(panel.y)
        && Number.isFinite(panel.width) && panel.width > 0
        && Number.isFinite(panel.height) && panel.height > 0
        && Number.isFinite(anchor.x) && Number.isFinite(anchor.y)
        && Number.isFinite(anchor.width) && anchor.width > 0
        && Number.isFinite(anchor.height) && anchor.height > 0;
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
