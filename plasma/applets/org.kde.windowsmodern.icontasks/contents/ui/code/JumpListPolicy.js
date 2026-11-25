// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library

// Keep ordinary task menus about the application. Native KDE management
// actions stay available in the expanded menu (Shift+right-click).
function launcherActions(hasUrl, isStartup, immutable, isPinned, activityCount) {
    const allowed = !!hasUrl && !isStartup && !immutable;
    const perActivity = allowed && activityCount >= 2;
    return {
        pin: allowed && !perActivity && !isPinned,
        unpin: allowed && !perActivity && !!isPinned,
        perActivity: perActivity
    };
}

function expandedFromModifiers(modifiers, shiftMask) {
    return (modifiers & shiftMask) !== 0;
}
