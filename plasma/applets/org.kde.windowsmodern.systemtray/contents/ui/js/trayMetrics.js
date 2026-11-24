// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Windows 11 reference sizes are logical pixels. Qt handles output scaling.
function iconSize(thickness, scaleToFit) {
    const limit = Math.max(1, Math.floor(thickness));
    return Math.min(limit, scaleToFit ? Math.max(16, Math.min(48, Math.round(limit * 2 / 3))) : 16);
}

// System-tray glyphs are smaller than taskbar app icons. Default 18px
// logical box, independent of the Start logo. Scale only if explicitly
// selected in the tray settings; cap the size even on very tall panels.
function coreIconSize(thickness, scaleToFit) {
    const limit = Math.max(1, Math.floor(thickness));
    return Math.min(limit, scaleToFit ? Math.max(18, Math.min(32, Math.round(limit * 3 / 8))) : 18);
}

// Keep the native applet at the same 32px render geometry as before;
// shrink the visual host, not the underlying applet's state or hit area.
function coreRenderSize(displaySize) {
    if (displaySize <= 16) return 16;
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
