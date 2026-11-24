// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Move through visible, enabled menu rows, wrapping in either direction.
function nextEnabledIndex(available, current, direction) {
    const count = available.length;
    if (count === 0) return -1;
    const step = direction < 0 ? -1 : 1;
    const start = current >= 0 && current < count ? current : (step > 0 ? -1 : 0);
    for (let offset = 1; offset <= count; ++offset) {
        const index = (start + step * offset + count * 2) % count;
        if (available[index]) return index;
    }
    return -1;
}
