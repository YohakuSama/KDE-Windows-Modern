// SPDX-License-Identifier: GPL-3.0-or-later
// Logical-pixel horizontal anchor selection. Plasma owns popup geometry.

function horizontalAnchorOffset(mode, screen, button) {
    // Global coordinates are used only to select the horizontal anchor.
    // The native Dialog owns the actual popup position and screen bounds.
    if (!screen || !button || !Number.isFinite(screen.x)
            || !Number.isFinite(screen.width) || screen.width <= 0
            || !Number.isFinite(button.x) || !Number.isFinite(button.width)
            || button.width <= 0 || button.width > screen.width
            || button.x < screen.x - 1
            || button.x + button.width > screen.x + screen.width + 1)
        return 0;

    const left = button.x - screen.x;
    const right = screen.x + screen.width - button.x - button.width;
    const buttonCenter = button.x + button.width / 2;

    // Preserve the stored explicit alignment values. The legacy free-
    // floating Center (1) now means centered at the panel, like mode 2.
    if (mode === 3)
        return Math.round(screen.x + button.width / 2 - buttonCenter);
    if (mode === 1 || mode === 2)
        return Math.round(screen.x + screen.width / 2 - buttonCenter);

    // A left/right-aligned Start sits near that edge. Keep the real
    // anchor there so Plasma clamps the popup into the work area.
    // Otherwise the task group is inset: anchor at the output's center
    // even when many task icons move the Start button away from it.
    const edgeBand = 2 * button.width;
    if (left <= edgeBand || right <= edgeBand)
        return 0;
    return Math.round(screen.x + screen.width / 2 - buttonCenter);
}
