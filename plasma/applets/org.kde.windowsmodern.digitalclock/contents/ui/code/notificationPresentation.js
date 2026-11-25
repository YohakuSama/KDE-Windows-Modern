// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Empty history must not reserve a bell cell. DND is an independent status.
// The clock and Win+N remain the entry points even when the bell is absent.
function showBell(configured, horizontal, available, count, inhibited) {
    return !!configured && !!horizontal && !!available
        && (Number(count) > 0 || !!inhibited);
}

// The imported Segoe snooze glyph matches the filled light taskbar reference.
// Keep the existing icon in dark mode and when the native asset is unavailable.
function panelBellIcon(normalIcon, inhibited, dark, filledAvailable) {
    return inhibited && !dark && filledAvailable
        ? "wm-notification-snooze-filled-symbolic" : normalIcon;
}
