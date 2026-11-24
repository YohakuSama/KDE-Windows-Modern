.pragma library

function btStatus(btManager) {
    var connectedDevices = [];
    for (var i = 0; i < btManager.devices.length; ++i) {
        var device = btManager.devices[i];
        if (device.connected) {
            connectedDevices.push(device);
        }
    }

    if (btManager.bluetoothBlocked) {
        return { active: false, message: qsTr("Disabled"), icon: "network-bluetooth-inactive-symbolic" };
    } else if (!btManager.bluetoothOperational) {
        if (!btManager.adapters.length) {
            return { active: false, message: qsTr("Unavailable"), icon: "network-bluetooth-inactive-symbolic" };
        }
        return { active: false, message: qsTr("Offline"), icon: "network-bluetooth-inactive-symbolic" };
    } else if (connectedDevices.length >= 1) {
        return { active: true, message: connectedDevices[0].name, icon: "network-bluetooth-activated-symbolic" };
    }
    return { active: true, message: qsTr("Not Connected"), icon: "network-bluetooth-symbolic" };
}

function toggleBluetooth(btManager) {
    var enable = !btManager.bluetoothOperational;
    btManager.bluetoothBlocked = !enable;
    for (var i = 0; i < btManager.adapters.length; ++i) {
        btManager.adapters[i].powered = enable;
    }
}

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

function batteryIconName(percent, charging) {
    var icon;
    if (percent < 10) {
        icon = "battery-000";
    } else if (percent < 20) {
        icon = "battery-010";
    } else if (percent < 30) {
        icon = "battery-020";
    } else if (percent < 40) {
        icon = "battery-030";
    } else if (percent < 50) {
        icon = "battery-040";
    } else if (percent < 60) {
        icon = "battery-050";
    } else if (percent < 70) {
        icon = "battery-060";
    } else if (percent < 80) {
        icon = "battery-070";
    } else if (percent < 90) {
        icon = "battery-080";
    } else if (percent < 100) {
        icon = "battery-090";
    } else {
        icon = "battery-100";
    }
    return charging ? icon + "-charging-symbolic" : icon + "-symbolic";
}
