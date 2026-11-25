// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

const passwordWidth = 248;
const passwordHeight = 30;

function avatarSize(width, height) {
    return Math.max(1, Math.floor(Math.min(160, width * 0.55, height * 0.24)));
}

function formTop(height, contentHeight) {
    return Math.max(8, Math.floor(Math.min(height * 0.215, height - contentHeight - 64)));
}
