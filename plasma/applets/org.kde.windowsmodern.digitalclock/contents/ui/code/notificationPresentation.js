// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// The clock remains the notification-center entry even without the bell.
// DND is an independent status; an unavailable service is reported in
// the flyout rather than occupying a permanent taskbar cell.
function showBell(configured, horizontal, available, count, inhibited) {
    return !!configured && !!horizontal && !!available
        && (Number(count) > 0 || !!inhibited);
}

function showClearAll(available, count) {
    return !!available && Number(count) > 0;
}
