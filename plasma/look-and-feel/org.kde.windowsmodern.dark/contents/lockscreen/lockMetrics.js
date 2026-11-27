// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Windows 26300.9974 RequestCredentialUserControl.xbf: CredentialControlsWidth.
// See docs/windows11-26h2-ui-parameters.json for the resource and template evidence.
const passwordWidth = 296;
// CommonStyles.xbf: LogonDefaultFontSize and TextFieldCornerRadius.
const credentialFontSize = 14;
const fieldCornerRadius = 4;
// Host-specific heights remain distinct pending native template evidence.
const passwordHeight = 30;

function avatarSize(width, height) {
    return Math.max(1, Math.floor(Math.min(160, width * 0.55, height * 0.24)));
}

function formTop(height, contentHeight) {
    return Math.max(8, Math.floor(Math.min(height * 0.215, height - contentHeight - 64)));
}
