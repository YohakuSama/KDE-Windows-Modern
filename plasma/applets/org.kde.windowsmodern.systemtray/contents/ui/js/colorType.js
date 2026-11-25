.pragma library

function luminance(color) {
    const rgb = [color.r, color.g, color.b].map(value =>
        value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4));
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2];
}

function isDark(color) { return luminance(color) <= 0.179; }

function contrastRatio(a, b) {
    const l1 = luminance(a);
    const l2 = luminance(b);
    return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
}

function contrastingForeground(color) {
    // Pick the better of black/white. The crossover gives at least
    // 4.58:1 contrast for an opaque accent, including custom accents.
    return isDark(color) ? "#FFFFFF" : "#000000";
}

// Sampled light reference: panel #F2F2F2, button #FBFBFB, footer #EEEEEE.
// Dark is a neutral Fluent compatibility palette, not a Windows capture.
function tileFill(dark, hovered, pressed) {
    if (dark) return pressed ? "#303030" : hovered ? "#3B3B3B" : "#333333";
    return pressed ? "#EDEDED" : hovered ? "#F6F6F6" : "#FBFBFB";
}
function tileBorder(dark) { return dark ? "#424242" : "#E7E7E7"; }
function cardFill(dark, acrylic) {
    if (dark) return acrylic ? "#DB202020" : "#202020";
    return acrylic ? "#E6F2F2F2" : "#F2F2F2";
}
function cardBorder(dark) { return dark ? "#3C3C3C" : "#DCDCDC"; }
function divider(dark) { return dark ? "#24FFFFFF" : "#15000000"; }
function footerTint(dark) { return dark ? "#18000000" : "#04000000"; }
