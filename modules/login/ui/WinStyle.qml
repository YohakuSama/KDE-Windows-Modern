pragma Singleton

/*
 * SPDX-FileCopyrightText: 2026 Jeysef
 *
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick
import "lockMetrics.js" as LockMetrics

QtObject {
    readonly property color foregroundColor: "#FFFFFF"
    readonly property color secondaryForegroundColor: "#E0E0E0"
    readonly property color mutedForegroundColor: "#A0A0A0"
    readonly property color accentColor: "#4CC2FF"
    readonly property color dimOverlayColor: "#000000"
    readonly property real dimOverlayOpacity: LockMetrics.credentialDimOpacity
    readonly property color panelBackground: "#40000000"
    readonly property color menuBackground: "#2C2C2C"
    readonly property color menuBorder: "#3F3F3F"
    readonly property color hoverBackground: "#33FFFFFF"

    readonly property string fontFamily: Application.font.family

    readonly property int avatarSize: LockMetrics.accountAvatarMaximum
    readonly property int textFieldHeight: 42
    readonly property int textFieldRadius: LockMetrics.fieldCornerRadius
    readonly property int fieldFocusBarInset: LockMetrics.fieldFocusBarInset
    readonly property int fieldFocusBarHeight: LockMetrics.fieldFocusBarHeight
    readonly property int fieldFocusBarRadius: LockMetrics.fieldFocusBarRadius
    readonly property color textFieldBorderColor: "#66FFFFFF"
    readonly property int textFieldMaxWidth: LockMetrics.passwordWidth
    readonly property int loginButtonSize: 38
    readonly property int loginButtonWidth: LockMetrics.loginButtonWidth
    readonly property int loginButtonRadius: LockMetrics.loginButtonRadius
    readonly property int loginButtonBorderWidth: LockMetrics.loginButtonBorderWidth
    readonly property int loginButtonFocusBorderWidth: LockMetrics.loginButtonFocusBorderWidth
    readonly property int userSwitcherAvatarSize: 40
    readonly property int userSwitcherItemHeight: 52
    readonly property int powerMenuWidth: LockMetrics.loginPowerMenuWidth

    readonly property real clockLineSpacingFactor: LockMetrics.clockLineSpacingFactor
    readonly property int clockTimePixelSize: LockMetrics.clockTimePixelSize
    readonly property int clockDatePixelSize: LockMetrics.clockDatePixelSize
    readonly property int usernamePixelSize: 28
    readonly property int bodyPixelSize: LockMetrics.credentialFontSize
    readonly property int userSwitcherNamePixelSize: LockMetrics.credentialFontSize
}
