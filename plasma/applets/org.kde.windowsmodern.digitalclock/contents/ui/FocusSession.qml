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
    readonly property bool canStart: !running && !!settings
    property double ownedInhibition: 0
    property double previousInhibition: 0
    property var ownedSettings: null

    function adjust(delta) {
        if (!running)
            durationMinutes = Math.max(5, Math.min(240, durationMinutes + delta));
    }

    function start(now = Date.now()) {
        // Do not pretend focus is enabled when its notification backend is absent.
        if (!canStart) return false;
        const deadline = now + durationMinutes * 60000;
        const until = settings.notificationsInhibitedUntil;
        const previous = until ? until.getTime() : NaN;
        // Keep an existing longer manual DND setting. Extend a shorter one
        // only for this session and restore it if the session ends early.
        if (!Number.isFinite(previous) || previous < deadline) {
            ownedSettings = settings;
            ownedInhibition = deadline;
            previousInhibition = Number.isFinite(previous) && previous > now ? previous : 0;
            settings.notificationsInhibitedUntil = new Date(deadline);
            settings.save();
        }
        endTime = deadline;
        remainingSeconds = durationMinutes * 60;
        return true;
    }

    function stop(now = Date.now()) {
        if (!running) return;
        if (ownedSettings && ownedInhibition > 0) {
            const until = ownedSettings.notificationsInhibitedUntil;
            // A manual DND change during the session takes precedence.
            // KConfig can round the saved timestamp to the nearest second.
            if (until && Math.abs(until.getTime() - ownedInhibition) < 1000) {
                ownedSettings.notificationsInhibitedUntil = previousInhibition > now
                    ? new Date(previousInhibition) : undefined;
                ownedSettings.save();
            }
        }
        ownedInhibition = 0;
        previousInhibition = 0;
        ownedSettings = null;
        endTime = 0;
        remainingSeconds = 0;
    }

    function tick(now = Date.now()) {
        if (!running) return;
        remainingSeconds = Math.max(0, Math.ceil((endTime - now) / 1000));
        if (remainingSeconds === 0) stop(now);
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
