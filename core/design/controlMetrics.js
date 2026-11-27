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
