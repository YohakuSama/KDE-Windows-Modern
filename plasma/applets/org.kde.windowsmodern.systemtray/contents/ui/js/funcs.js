.pragma library
.import "../components/batteryState.js" as BatteryState

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

// Preserve the unknown sentinel; never show more than 100% or a nonfinite level.
function boundedBatteryPercent(percent) {
    return BatteryState.boundedBatteryPercent(percent);
}

// Display names are opaque PowerDevil identifiers, not connector names.
// With several controlled outputs choose only an unambiguous type match.
function brightnessDisplayIndex(internalFlags, panelInternal) {
    if (internalFlags.length === 1) return 0;
    if (typeof panelInternal !== "boolean" || internalFlags.some(flag => typeof flag !== "boolean"))
        return -1;
    let match = -1;
    for (let i = 0; i < internalFlags.length; ++i) {
        if (internalFlags[i] !== panelInternal) continue;
        if (match !== -1) return -1;
        match = i;
    }
    return match;
}

function isInternalConnectorName(name) {
    return /^(?:edp|lvds|dsi)(?:-?\d+)?$/i.test(String(name || ""));
}

function batteryIconName(percent, pluggedIn, saver = false) {
    return BatteryState.batteryIconName(percent, pluggedIn, saver);
}

function batteryVisualState(percent, charging, saver) {
    return BatteryState.batteryVisualState(percent, charging, saver);
}

function batteryFillFraction(percent) {
    return Number.isFinite(percent) ? Math.max(0, Math.min(100, percent)) / 100 : 0;
}

// Fcitx's Rime engine publishes distinct named icons for Han, ASCII
// and disabled states (rimeengine.cpp: subModeIconImpl). Test these
// BEFORE matching the engine name, since both modes have a Rime tooltip.
// When Fcitx supplies a text-icon pixmap instead of a named icon, that
// pixmap owns the actual submode and must not be covered by a guessed label.
function inputMethodLabel(id, iconName, tooltip) {
    if (!/^fcitx5?$/i.test(String(id))) return "";
    const icon = String(iconName || "").split("/").pop().toLowerCase()
        .replace(/\.(svg|png|xpm)$/, "").replace(/_+/g, "-");
    const name = String(tooltip || "");
    if (/^(?:fcitx-)?rime-disable(?:d)?(?:-symbolic)?$/.test(icon)) return "";
    if (/^(?:fcitx-)?rime-latin(?:-upper)?(?:-symbolic)?$/.test(icon)) return "英";
    if (/english|英语|英語|英文/i.test(name) ||
        /(?:^|-)keyboard-us(?:$|-)/i.test(icon)) return "英";
    if (!icon || /^input-keyboard(?:-symbolic)?$/.test(icon)) return "";
    if (/^(?:fcitx-)?rime(?:-symbolic)?$/.test(icon)) return "中";
    if (/(?:^|-)(?:pinyin|chewing|cangjie|wubi|zhuyin|bopomofo|shuangpin|chinese)(?:$|-)/i.test(icon)) return "中";
    return "";
}
