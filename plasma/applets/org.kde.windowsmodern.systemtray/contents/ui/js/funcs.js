.pragma library

// Manual preference is independent of automatic/application inhibition.
function manualInhibition(settings, now) {
    if (!settings) return false;
    const until = settings.notificationsInhibitedUntil;
    return !!until && !isNaN(until.getTime()) && until.getTime() > now;
}

function checkInhibition(settings, now = Date.now()) {
    if (!settings) return false;
    return manualInhibition(settings, now)
        || !!settings.notificationsInhibitedByApplication
        || (settings.inhibitNotificationsWhenScreensMirrored && settings.screensMirrored);
}

function toggleDnd(settings, durationMs = 365 * 24 * 60 * 60 * 1000, now = Date.now()) {
    if (!settings) return;
    settings.notificationsInhibitedUntil = manualInhibition(settings, now)
        ? undefined : new Date(now + durationMs);
    settings.save();
}

function volIconName(volume, muted) {
    var percent = volume / 65536;
    if (percent <= 0.0 || muted) {
        return "audio-volume-muted-symbolic";
    } else if (percent <= 0.25) {
        return "audio-volume-low-symbolic";
    } else if (percent <= 0.75) {
        return "audio-volume-medium-symbolic";
    }
    return "audio-volume-high-symbolic";
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

function batteryFillFraction(percent) {
    return Number.isFinite(percent) ? Math.max(0, Math.min(100, percent)) / 100 : 0;
}

// Read Fcitx's real active input method title/icon, not the desktop locale.
function inputMethodLabel(id, iconName, tooltip) {
    if (!/^fcitx5?$/i.test(String(id))) return "";
    const icon = String(iconName || "");
    const name = String(tooltip || "");
    if (/english|英语|英語|英文/i.test(name) ||
        /(?:^|[-_])keyboard[-_]us(?:$|[-_])/i.test(icon)) return "英";
    // The Fcitx keyboard fallback is not evidence of a Chinese engine.
    if (/^input-keyboard(?:-symbolic)?$/i.test(icon)) return "";
    const metadata = icon + " " + name;
    if (/rime|pinyin|chewing|cangjie|wubi|zhuyin|bopomofo|shuangpin|chinese|中州韵|中州韻|中文|拼音|五笔|五筆|注音|仓颉|倉頡|双拼|雙拼/i.test(metadata)) return "中";
    return "";
}
