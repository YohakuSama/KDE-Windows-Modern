// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Shared by the panel and greeter. Preserve the unknown sentinel.
function boundedBatteryPercent(percent) {
    return Number.isFinite(percent) && percent >= 0 ? Math.min(100, percent) : -1;
}

function batteryIconName(percent, pluggedIn, saver = false) {
    if (!Number.isFinite(percent) || percent < 0)
        return pluggedIn ? "battery-unknown-charging-symbolic" : "battery-unknown-symbolic";
    // Match the native KDE BatteryIcon level boundaries, including 5%.
    const level = percent <= 5 ? 0 : Math.min(100, Math.round(percent / 10) * 10);
    return "battery-" + String(level).padStart(3, "0")
        + (pluggedIn ? "-charging" : saver ? "-profile-powersave" : "") + "-symbolic";
}

// Visual state is derived from the power backend, never a fake level.
function batteryVisualState(percent, charging, saver) {
    if (!Number.isFinite(percent) || percent < 0) return "unknown";
    if (charging) return "charging";
    if (percent <= 5) return "critical";
    if (saver) return "saver";
    return "normal";
}
