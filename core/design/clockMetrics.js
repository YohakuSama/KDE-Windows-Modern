// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

.import "controlMetrics.js" as ControlMetrics

// Shared Digital Clock flyout card and button geometry.
// Keep colors in Win11Palette.qml and behavior in the owning components.
const flyoutCardRadius = ControlMetrics.overlayCornerRadius;
const flyoutCardBorderWidth = 1;
const flyoutButtonExtent = 28;
const compactActionButtonExtent = 24;
const flyoutButtonRadius = ControlMetrics.controlCornerRadius;
