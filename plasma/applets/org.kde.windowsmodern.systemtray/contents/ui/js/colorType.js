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

// Accents from wallpaper can have poor contrast against the control
// surface. Adjust only as far as necessary toward the relevant neutral.
function accentForSurface(accent, surface, minimumRatio) {
    const minimum = minimumRatio || 3;
    const dark = isDark(surface);
    const target = dark ? 1 : 0;
    const opaque = Qt.rgba(accent.r, accent.g, accent.b, 1);
    if (contrastRatio(opaque, surface) >= minimum) return opaque;
    let low = 0;
    let high = 1;
    for (let i = 0; i < 12; ++i) {
        const weight = (low + high) / 2;
        const color = Qt.rgba(opaque.r + (target - opaque.r) * weight,
            opaque.g + (target - opaque.g) * weight,
            opaque.b + (target - opaque.b) * weight, 1);
        if (contrastRatio(color, surface) >= minimum) high = weight;
        else low = weight;
    }
    return Qt.rgba(opaque.r + (target - opaque.r) * high,
        opaque.g + (target - opaque.g) * high,
        opaque.b + (target - opaque.b) * high, 1);
}

// Sampled light reference: panel #F2F2F2, button #FBFBFB, footer #EEEEEE.
// Dark is a neutral Fluent compatibility palette, not a Windows capture.
function tileFill(dark, hovered, pressed) {
    if (dark) return pressed ? "#303030" : hovered ? "#3B3B3B" : "#333333";
    return pressed ? "#EDEDED" : hovered ? "#F6F6F6" : "#FBFBFB";
}
function tileBorder(dark) { return dark ? "#3B3B3B" : "#E5E5E5"; }
function cardFill(dark, acrylic) {
    if (dark) return acrylic ? "#F2202020" : "#202020";
    return acrylic ? "#F7F2F2F2" : "#F2F2F2";
}
function cardBorder(dark) { return dark ? "#383838" : "#DCDCDC"; }
function divider(dark) { return dark ? "#18FFFFFF" : "#12000000"; }
function footerTint(dark) { return dark ? "#15000000" : "#05000000"; }
function trackFill(dark) { return dark ? "#929292" : "#767676"; }
function rowFill(dark, selected, hovered, pressed) {
    const alpha = pressed ? 0.10 : selected || hovered ? 0.065 : 0;
    const ink = dark ? 1 : 0;
    return Qt.rgba(ink, ink, ink, alpha);
}
