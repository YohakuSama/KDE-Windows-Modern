// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

.import "controlMetrics.js" as ControlMetrics

// Shared Digital Clock flyout card and button geometry.
// Windows 11 26H2 ActionCenter/Styling/Styles.Win11.xbf & styles.xbf:
//   NotificationCenterFlyoutWidth = 360 (@11339)
//   NotificationCenterFlyoutMargin = [12, 8, 12, 0] (@11458) -> 336 card width
//   NotificationCenterFlyoutActualWidth = 312 (@11348) -> 336 - 2*12 inner width
//   GroupHeaderMinHeight = 32 (@11619)
//   AppLogoIconSize = 16 (@12088)
// Keep colors in Win11Palette.qml and behavior in the owning components.
const flyoutDefaultWidth = 336;
const flyoutCardRadius = ControlMetrics.overlayCornerRadius;
const flyoutCardBorderWidth = 1;
const flyoutButtonExtent = 28;
const compactActionButtonExtent = 24;
const flyoutButtonRadius = ControlMetrics.controlCornerRadius;
const groupHeaderMinHeight = 32;
const appLogoIconSize = 16;
