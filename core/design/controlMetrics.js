// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Shared WinUI geometry and cross-module surface metrics.
// Resource-backed values and project-specific targets are identified below.
// Keep host-specific layout, spacing and state geometry in owner metrics.
// WinUI 21h1_themeresources.xbf: ControlCornerRadius.
const controlCornerRadius = 4;
// Windows.UI.Logon CommonStyles.xbf: OverlayCornerRadius.
const overlayCornerRadius = 8;
// Existing Start/Search/Alt+Tab card-surface target, shared without changing its value.
// It is a project surface metric, not the equal-valued popup overlay token.
const cardSurfaceRadius = 8;
// WinUI 21h1_themeresources.xbf: MenuFlyoutThemeMinHeight.
const menuItemMinimumHeight = 32;
// TaskbarResources.xbf: SearchBoxRoundCornerRadius.
const searchBoxCornerRadius = 16;
// WinUI 21h1_themeresources.xbf: ScrollBarVerticalThumbMinHeight / ScrollBarHorizontalThumbMinWidth.
const scrollBarThumbMinimumExtent = 30;
// WinUI 21h1_themeresources.xbf: ComboBoxItemPillWidth, ComboBoxItemPillHeight and ComboBoxItemPillMinScale (16 * 0.625 = 10).
const listSelectionPillWidth = 3;
const listSelectionPillHeight = 16;
const listSelectionPillPressedHeight = 10;
// WinUI 21h1_themeresources.xbf: ControlFasterAnimationDuration / ScrollBarOpacityChangeDuration (83ms),
// ControlFastAnimationDuration / ScrollBarExpandDuration / ComboBoxItemScaleAnimationDuration (167ms),
// and ControlNormalAnimationDuration (250ms).
const controlFasterDuration = 83;
const controlFastDuration = 167;
const controlNormalDuration = 250;
// Existing Start/Search hover, focus and drag micro-interaction target.
// Project-owned timing, not claimed as a native XAML resource value.
const microInteractionDuration = 90;
