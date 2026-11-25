/***************************************************************************
 *   License: GPL-3.0-or-later
 *   Author: Jeysef
 *
 *   Centralized translucency / opacity constants for the start menu.
 *   Import as a namespace, e.g.:
 *       import "../code/theme.js" as Theme
 *   then reference values like Theme.buttonFlatBackgroundOpacity.
 ***************************************************************************/

// Flat buttons / chips ("All apps", "Back", filter pills, shutdown split)
var buttonFlatBackgroundOpacity = 0.06;
var buttonFlatHoverOpacity      = 0.08;

// Raised / hover-filled controls (legacy AToolButton hover, list items)
var buttonHoverOpacity          = 0.08;

// Borders and dividers
var buttonBorderOpacity         = 0.08;
var buttonDividerOpacity        = 0.10;
var fieldBorderOpacity          = 0.12;
var popupBorderOpacity          = 0.10;
var separatorOpacity            = 0.09;
var headerSeparatorOpacity      = 0.08;

// Icons and text that are de-emphasized
var buttonChevronOpacity        = 0.70;
var dimmedIconOpacity           = 0.60;
var dimmedTextOpacity           = 0.60;
var disabledIconOpacity         = 0.40;

// List / drag states
var listItemCurrentOpacity      = 0.50;
var draggingOpacity             = 0.85;

// Whole-menu translucency modes (must match main.xml menuTranslucency enum)
var menuTranslucencyFollowTheme = 0;
var menuTranslucencyTranslucent = 1;
var menuTranslucencyOpaque      = 2;

// Convenience constants for fully visible / fully hidden states
var opacityFull   = 1.0;
var opacityHidden = 0.0;

// Use the same neutral surfaces as the shell popup frames.
function isDark(color) {
    const rgb = [color.r, color.g, color.b].map(v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4));
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2] <= 0.179;
}
function menuSurface(bg) { return isDark(bg) ? "#2C2C2C" : "#F9F9F9"; }
function menuBorder(bg) { return isDark(bg) ? "#383838" : "#DCDCDC"; }
