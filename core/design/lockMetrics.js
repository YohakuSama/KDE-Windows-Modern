// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

.import "controlMetrics.js" as ControlMetrics

// Windows 26300.9974 RequestCredentialUserControl.xbf: CredentialControlsWidth.
// See docs/windows11-26h2-ui-parameters.json for the resource and template evidence.
const passwordWidth = 296;
// CommonStyles.xbf: LogonDefaultFontSize and TextFieldCornerRadius.
const credentialFontSize = 14;
const fieldCornerRadius = 4;
// Shared credential field active-focus bottom indicator geometry.
const fieldFocusBarInset = 2;
const fieldFocusBarHeight = 2;
const fieldFocusBarRadius = 1;
// Shared Sign in button surface used by the Login and LockScreen hosts.
const loginButtonWidth = 144;
const loginButtonRadius = 6;
const loginButtonBorderWidth = 1;
const loginButtonFocusBorderWidth = 2;
// CommonStyles.xbf: SubmitButtonStyle and ButtonLayoutGrid.
const fieldButtonRadius = 3;
const submitButtonMinWidth = 28;
const submitButtonMinHeight = 24;
const submitButtonFontSize = 12;
// CommonStyles.xbf: DefaultMenuFlyoutPresenterStyle -> OverlayCornerRadius.
const menuRadius = ControlMetrics.overlayCornerRadius;

// Shared clock line spacing scales with KDE's logical UI spacing.
const clockLineSpacingFactor = 0.5;

// Shared power-menu padding; widths remain host-specific pending 26H2 evidence.
const powerMenuPadding = 4;
const loginPowerMenuWidth = 150;
const lockScreenPowerMenuWidth = 160;
// Host-specific heights remain distinct pending native template evidence.
const passwordHeight = 30;

// Shared existing login and lock-screen presentation. Keep the host-specific
// viewport clamps, field heights and user-switcher geometry separate.
const accountAvatarMaximum = 160;
const clockTimePixelSize = 96;
const clockDatePixelSize = 24;
const clockTopRatio = 0.15;
const credentialDimOpacity = 0.30;
// Shared status-row button and footer inset geometry across Login and LockScreen.
const statusButtonExtent = 32;
const statusGlyphExtent = 16;
const footerMargin = 16;
const footerSpacing = 8;

function avatarSize(width, height) {
    return Math.max(1, Math.floor(Math.min(accountAvatarMaximum, width * 0.55, height * 0.24)));
}

function formTop(height, contentHeight) {
    return Math.max(8, Math.floor(Math.min(height * 0.215, height - contentHeight - 64)));
}
