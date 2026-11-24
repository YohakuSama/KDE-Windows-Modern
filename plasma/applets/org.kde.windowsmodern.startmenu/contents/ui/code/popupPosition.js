// SPDX-License-Identifier: GPL-3.0-or-later
// Pure logical-pixel geometry; no dependency on a live Plasma session.

function position(mode, edge, screen, button, popup, gap) {
    const minX = screen.x + gap;
    const minY = screen.y + gap;
    const maxX = Math.max(minX, screen.x + screen.width - popup.width - gap);
    const maxY = Math.max(minY, screen.y + screen.height - popup.height - gap);
    const centeredX = screen.x + (screen.width - popup.width) / 2;
    const centeredY = screen.y + (screen.height - popup.height) / 2;
    const buttonX = button.x + (button.width - popup.width) / 2;
    const buttonY = button.y + (button.height - popup.height) / 2;
    const bottomY = edge === "bottom" ? button.y - popup.height - gap : maxY;
    let x = buttonX;
    let y = bottomY;

    if (mode === 1) {
        x = centeredX;
        y = centeredY;
    } else if (mode === 2) {
        x = centeredX;
    } else if (mode === 3) {
        x = minX;
    } else if (edge === "top") {
        y = button.y + button.height + gap;
    } else if (edge === "left") {
        x = button.x + button.width + gap;
        y = buttonY;
    } else if (edge === "right") {
        x = button.x - popup.width - gap;
        y = buttonY;
    } else if (edge === "floating") {
        y = button.y - popup.height - gap;
    }

    return {
        x: Math.round(Math.max(minX, Math.min(x, maxX))),
        y: Math.round(Math.max(minY, Math.min(y, maxY)))
    };
}
