// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick

// Lives in the compact applet, not the disposable popup. A real deadline
// avoids timer drift and survives hiding the notification center.
Item {
    id: session
    visible: false
    property var settings: null
    property int durationMinutes: 30
    property double endTime: 0
    property int remainingSeconds: 0
    readonly property bool running: endTime > 0
    property double ownedInhibition: 0
    property var ownedSettings: null

    function adjust(delta) {
        if (!running)
            durationMinutes = Math.max(5, Math.min(240, durationMinutes + delta));
    }

    function start(now = Date.now()) {
        if (running) return;
        endTime = now + durationMinutes * 60000;
        remainingSeconds = durationMinutes * 60;
        // Do not replace a user's existing manual inhibition. Other KDE
        // applications and automatic rules remain independent.
        if (settings) {
            const until = settings.notificationsInhibitedUntil;
            const previous = until ? until.getTime() : NaN;
            if (!Number.isFinite(previous) || previous <= now) {
                ownedSettings = settings;
                ownedInhibition = endTime;
                settings.notificationsInhibitedUntil = new Date(endTime);
                settings.save();
            }
        }
    }

    function stop() {
        if (!running) return;
        if (ownedSettings && ownedInhibition > 0) {
            const until = ownedSettings.notificationsInhibitedUntil;
            // A manual DND change during the session takes precedence.
            // KConfig can round the saved timestamp to the nearest second.
            if (until && Math.abs(until.getTime() - ownedInhibition) < 1000) {
                ownedSettings.notificationsInhibitedUntil = undefined;
                ownedSettings.save();
            }
        }
        ownedInhibition = 0;
        ownedSettings = null;
        endTime = 0;
        remainingSeconds = 0;
    }

    function tick(now = Date.now()) {
        if (!running) return;
        remainingSeconds = Math.max(0, Math.ceil((endTime - now) / 1000));
        if (remainingSeconds === 0) stop();
    }

    readonly property string countdown: {
        const minutes = Math.floor(remainingSeconds / 60);
        const seconds = remainingSeconds % 60;
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
    }

    Timer {
        interval: 1000
        running: session.running
        repeat: true
        onTriggered: session.tick()
    }
}
