// SPDX-License-Identifier: GPL-3.0-or-later
.import "popupGeometry.js" as Geometry
// One outer surface for Start, empty search and populated search.
// Size preference and available logical screen geometry are the only inputs.
// Never feed query length, search mode, or content implicit size into this.
function surfaceSize(mode, screen, panelExtent, vertical, margin) {
    const large = mode === 2 || (mode === 0 && screen.width >= 1440);
    const wantedWidth = large ? 768 : 560;
    const wantedHeight = large ? 720 : 640;
    const panel = Math.max(0, Number(panelExtent) || 0);
    const inset = 2 * Math.max(0, Number(margin) || 0);
    return {
        width: Math.max(1, Math.floor(Math.min(wantedWidth, screen.width > 0
            ? screen.width - (vertical ? panel : 0) - inset : wantedWidth))),
        height: Math.max(1, Math.floor(Math.min(wantedHeight, screen.height > 0
            ? screen.height - (vertical ? 0 : panel) - inset : wantedHeight)))
    };
}

// Explicit alignment uses the actual panel span; auto uses the button.
function horizontalAnchorOffset(mode, screen, button, panel, popupWidth) {
    if (!screen || !button || !Number.isFinite(screen.x)
            || !Number.isFinite(screen.width) || screen.width <= 0
            || !Number.isFinite(button.x) || !Number.isFinite(button.width)
            || button.width <= 0 || button.x < screen.x - 1
            || button.x + button.width > screen.x + screen.width + 1)
        return 0;
    const validPanel = panel && Number.isFinite(panel.x) && Number.isFinite(panel.width)
        && panel.width > 0 && button.x >= panel.x - 1
        && button.x + button.width <= panel.x + panel.width + 1;
    const span = validPanel ? panel : screen;
    const left = Math.max(screen.x, span.x);
    const right = Math.min(screen.x + screen.width, span.x + span.width);
    if (right <= left) return 0;
    const buttonCenter = button.x + button.width / 2;
    const hasPopupWidth = Number.isFinite(popupWidth) && popupWidth > 0;
    let center = buttonCenter;
    if (mode === 3)
        center = left + Math.min(right - left, hasPopupWidth ? popupWidth : button.width) / 2;
    else if (mode === 1 || mode === 2)
        center = (left + right) / 2;
    // Reserve the shared logical-pixel screen inset wherever the popup fits.
    // The compositor still handles final placement and vertical work areas.
    if (hasPopupWidth) {
        const half = popupWidth / 2;
        const minCenter = screen.x + Geometry.popupGap() + half;
        const maxCenter = screen.x + screen.width - Geometry.popupGap() - half;
        center = minCenter <= maxCenter
            ? Math.max(minCenter, Math.min(maxCenter, center))
            : screen.x + screen.width / 2;
    }
    return Math.round(center - buttonCenter);
}
