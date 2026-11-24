// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Windows 11 reference sizes are logical pixels. Qt handles output scaling.
function iconSize(thickness, scaleToFit) {
    const limit = Math.max(1, Math.floor(thickness));
    return Math.min(limit, scaleToFit ? Math.max(16, Math.min(48, Math.round(limit * 2 / 3))) : 16);
}

// Size the visible core icon box independently from KDE's native render
// size. The shipped status SVGs contain whitespace: e.g. a 16px-wide
// battery drawing in a 24px viewBox. A 28px display box gives that
// drawing about 19px of ink, rather than the 11px from a 16px box.
function coreIconSize(thickness, scaleToFit) {
    const limit = Math.max(1, Math.floor(thickness));
    return Math.min(limit, Math.max(28, iconSize(thickness, scaleToFit)));
}

// Render at a standard KDE icon size at or above the display size, then
// scale the native compact representation as a whole. Otherwise a 28px
// item may be rounded down to 22px again by Kirigami.Icon. Keep the real
// native applet, including its changing icon, badge, and tooltip state.
function coreRenderSize(displaySize) {
    if (displaySize <= 16) return 16;
    if (displaySize <= 22) return 22;
    if (displaySize <= 32) return 32;
    return 48;
}

function coreCellLength(size, coreSize, spacing) {
    // Default cells are 30px with a 28px display box; stay compact.
    return Math.max(cellLength(size, true, spacing), coreSize + 2);
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
