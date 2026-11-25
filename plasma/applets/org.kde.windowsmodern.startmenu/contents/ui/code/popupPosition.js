// SPDX-License-Identifier: GPL-3.0-or-later
// Explicit alignment uses the actual panel span; auto uses the button.
function horizontalAnchorOffset(mode, screen, button, panel, popupWidth) {
    if (mode === 0) return 0;
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
    if (mode === 3)
        return Math.round(left + Math.min(right - left,
            Number.isFinite(popupWidth) && popupWidth > 0 ? popupWidth : button.width) / 2 - buttonCenter);
    if (mode === 1 || mode === 2)
        return Math.round((left + right) / 2 - buttonCenter);
    return 0;
}
