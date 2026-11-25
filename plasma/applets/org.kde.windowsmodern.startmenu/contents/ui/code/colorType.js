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
// Dark values sampled from the owner's original Windows Quick Settings reference.
function tileFill(dark, hovered, pressed) {
    if (dark) return pressed ? "#303030" : hovered ? "#3B3B3B" : "#313131";
    return pressed ? "#EDEDED" : hovered ? "#F6F6F6" : "#FBFBFB";
}
function tileBorder(dark) { return dark ? "#3B3B3B" : "#E5E5E5"; }
function cardFill(dark, acrylic) {
    if (dark) return acrylic ? "#FA252525" : "#242424";
    return acrylic ? "#F7F2F2F2" : "#F2F2F2";
}
function cardBorder(dark) { return dark ? "#383838" : "#DCDCDC"; }
function divider(dark) { return dark ? "#18FFFFFF" : "#12000000"; }
function footerTint(dark) { return dark ? "#39000000" : "#05000000"; }
function trackFill(dark) { return dark ? "#9B9B9B" : "#767676"; }
function rowFill(dark, selected, hovered, pressed) {
    const alpha = pressed ? 0.10 : selected || hovered ? 0.065 : 0;
    const ink = dark ? 1 : 0;
    return Qt.rgba(ink, ink, ink, alpha);
}

// WinUI ControlFill / ControlStroke and AccentFill state brushes.
// Composite against the actual flyout surface, rather than overlaying
// the foreground ink on a solid colored block. Keep the user's accent.
// Source: Microsoft Windows XAML theme resources and Fluent color guidance.
// The shell-specific backdrop is a reference-calibrated KDE approximation.
function blendOver(ink, base, opacity) {
    return Qt.rgba(ink.r * opacity + base.r * (1 - opacity),
        ink.g * opacity + base.g * (1 - opacity),
        ink.b * opacity + base.b * (1 - opacity), 1);
}

function quickTileSurface(dark) {
    return Qt.color(cardFill(dark, false));
}

function quickTileFill(dark, active, hovered, pressed, accent) {
    const base = quickTileSurface(dark);
    if (active)
        return blendOver(accent, base, pressed ? 0.8 : hovered ? 0.9 : 1);
    const ink = dark ? Qt.color("#FFFFFF")
        : Qt.color(pressed || hovered ? "#F9F9F9" : "#FFFFFF");
    const alpha = dark ? (pressed ? 0x08 : hovered ? 0x15 : 0x0F)
        : (pressed ? 0x4D : hovered ? 0x80 : 0xB2);
    return blendOver(ink, base, alpha / 255);
}

function quickTileStroke(dark, active) {
    return active ? "#14FFFFFF" : dark ? "#12FFFFFF" : "#0F000000";
}
