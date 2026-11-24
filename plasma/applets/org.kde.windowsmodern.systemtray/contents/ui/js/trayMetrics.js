// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Windows 11 reference sizes are logical pixels. Qt handles output scaling.
function iconSize(thickness, scaleToFit) {
    const limit = Math.max(1, Math.floor(thickness));
    return Math.min(limit, scaleToFit ? Math.max(16, Math.min(48, Math.round(limit * 2 / 3))) : 16);
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
