// SPDX-License-Identifier: LGPL-2.0-or-later
.pragma library

// Logical pixels. Preserve the same header location when the sign-in
// form is replaced by the welcome status. Allow short/small outputs.
function avatarSize(width, height) {
    return Math.max(1, Math.floor(Math.min(192, width * 0.75, height * 0.36)));
}
function formTop(height, contentHeight, avatar) {
    return Math.max(0, Math.min((height - avatar - 196) / 2, height - contentHeight));
}
