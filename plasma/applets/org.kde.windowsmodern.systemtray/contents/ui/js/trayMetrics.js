// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Windows Modern at 100%: 48px taskbar, 28px task icons, 16px tray icons.
// DPI is applied by Qt, never by multiplying the logical size by screen DPR.
// Explicit panel-size scaling remains an opt-in; 48px always gives 16px.
function iconSize(thickness, scaleToFit) {
    const limit = Math.max(1, Math.floor(thickness));
    const requested = scaleToFit ? Math.max(16, Math.min(32, Math.round(limit / 3))) : 16;
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
    return Math.max(size + 4, size + extra - (compact ? 8 : 0));
}

function visualIndex(index, count, vertical, reversed) {
    return vertical && reversed ? Math.max(0, count - index - 1) : index;
}
