#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Synchronize template-owned Kvantum accent paints, not window materials."""
import argparse
import colorsys
from fractions import Fraction
import json
import math
import os
from pathlib import Path
import re
import stat
from string import Template
import tempfile
import xml.etree.ElementTree as ET

ROLES = ("accent", "highlight_text", "selected_item_text",
         "checked_backing", "button_accent_text")
ROLE = re.compile(r"\$\{(" + "|".join(ROLES) + r")\}")
COLOR = re.compile(r"#[0-9a-fA-F]{6}")


# Windows preset RGB measurements reported in the public analysis below.
# Blue and orange were independently matched against build 26300.9974.
# Other rows remain third-party reference values pending target validation.
# https://gist.github.com/cnbluefire/7ffa04c493c57b8a67f6a8baa2c726f7
# Order: Light3, Light2, Light1, Dark1, Dark2, Dark3. The key is Accent.
PRESET_SHADE_ROLES = ("AccentLight3", "AccentLight2", "AccentLight1",
                      "AccentDark1", "AccentDark2", "AccentDark3")
PRESET_SHADES = {
    "#0063B1": ("#9CEBFF", "#40BDFF", "#007FDC", "#0055A1", "#00337C", "#00145A"),
    "#0078D4": ("#99EBFF", "#4CC2FF", "#0091F8", "#0067C0", "#003E92", "#001A68"),
    "#0099BC": ("#7AF7FF", "#30E5FF", "#00B8DF", "#0085A6", "#005573", "#002A45"),
    "#00B294": ("#67FFEE", "#21FFE0", "#00D3B1", "#009B7E", "#00664A", "#00361B"),
    "#00B7C3": ("#69FCFF", "#29F7FF", "#00D5E1", "#009FAA", "#006770", "#00343B"),
    "#00CC6A": ("#5FFFA5", "#26FF8E", "#00E775", "#00B25A", "#007635", "#003F13"),
    "#018574": ("#77FEF7", "#1AFDE9", "#01B09C", "#017463", "#014E3A", "#002A15"),
    "#038387": ("#7CFBFC", "#21F6FA", "#04ADB2", "#037276", "#024B4E", "#01282A"),
    "#107C10": ("#95EF81", "#45E532", "#19A115", "#0E6D0E", "#084B08", "#032B03"),
    "#10893E": ("#89F1A5", "#3AE872", "#14AE4C", "#0E7835", "#08521F", "#032E0B"),
    "#2D7D9A": ("#A7E8ED", "#6FC4D5", "#3598B7", "#266C88", "#17455F", "#08213A"),
    "#486860": ("#C7E4E1", "#94B5AF", "#5B837A", "#3D5A52", "#243930", "#0D1B11"),
    "#498205": ("#C1F96C", "#99F618", "#61A907", "#3E7204", "#254B03", "#0D2801"),
    "#4A5459": ("#D6E0E1", "#9EABAE", "#616F75", "#3F484D", "#252B32", "#0D1118"),
    "#4C4A48": ("#DFDEDC", "#A6A5A1", "#686562", "#413F3D", "#272524", "#100D0D"),
    "#515C6B": ("#D7E2E4", "#A0AEB7", "#657486", "#454E5E", "#292F40", "#0F1224"),
    "#525E54": ("#D7E2D9", "#A3AFA5", "#69786B", "#465147", "#29312A", "#0F150F"),
    "#567C73": ("#C5E7E4", "#9ABEB8", "#66948A", "#496B62", "#2B443A", "#0F2015"),
    "#5D5A58": ("#E2E1DE", "#AEACAA", "#767370", "#504D4B", "#302D2C", "#141010"),
    "#647C64": ("#D3E7D2", "#A8BEA7", "#779177", "#556B55", "#324332", "#121E12"),
    "#68768A": ("#D9E6EA", "#ADBBC5", "#7C8A9C", "#586579", "#343C51", "#13172D"),
    "#69797E": ("#D8E7E8", "#ADBCBF", "#7C8E92", "#59676D", "#353F45", "#131920"),
    "#6B69D6": ("#E4D8F8", "#B5ADEB", "#817DDC", "#4F4DCE", "#2C2B9E", "#13136A"),
    "#744DA9": ("#E6CEF0", "#BA9CD4", "#8963B8", "#654199", "#402775", "#1F0E54"),
    "#767676": ("#E6E6E6", "#BBBBBA", "#8B8B8B", "#646464", "#3B3B3B", "#151515"),
    "#7A7574": ("#E7E5E4", "#BDB9B8", "#8E8988", "#696363", "#403B3A", "#1B1515"),
    "#7E735F": ("#E8E5CE", "#BFB8A3", "#948971", "#6D6251", "#473A30", "#241511"),
    "#847545": ("#E9E5B0", "#C2B986", "#9D8D52", "#74633B", "#4E3B23", "#2B150C"),
    "#8764B8": ("#E9D4F2", "#C3A8DC", "#9979C3", "#744FAC", "#4B3279", "#241251"),
    "#881798": ("#EFACF2", "#D95BE6", "#AB1DBE", "#7B148B", "#5B0C6D", "#3F0451"),
    "#8E8CD8": ("#E8E3F8", "#C5C1EC", "#9F9CDE", "#6D6BCD", "#36349B", "#1A1956"),
    "#9A0089": ("#FF97FA", "#FF35EE", "#C800B3", "#8C007C", "#6B005E", "#4C0042"),
    "#B146C2": ("#F1BBF4", "#D88DE1", "#BD5BCB", "#9E3AB0", "#6F2382", "#460D5A"),
    "#BF0077": ("#FF97EE", "#FF43C8", "#E60094", "#AD0069", "#830048", "#5C0029"),
    "#C239B3": ("#F4B2F1", "#E183D9", "#CB4FBF", "#AE30A0", "#7F1D75", "#540A4D"),
    "#C30052": ("#FF97D1", "#FF459D", "#EA0065", "#B10046", "#860029", "#5F000F"),
    "#CA5010": ("#F5C07C", "#F09346", "#E46012", "#B6440E", "#872808", "#5C0E03"),
    "#D13438": ("#F7B1A5", "#E8807A", "#D84B4C", "#BE2B2E", "#8D1A1C", "#61090A"),
    "#DA3B01": ("#FEB16C", "#FE7E34", "#F44801", "#C53201", "#931E01", "#660B00"),
    "#E3008C": ("#FF94EE", "#FF4FCB", "#FF04A4", "#CD007B", "#990053", "#69002E"),
    "#E74856": ("#FBB4B7", "#F38A91", "#EB5C68", "#E32938", "#A6161E", "#650D0F"),
    "#E81123": ("#FB9D8B", "#F46762", "#EF2733", "#D20E1E", "#9E0912", "#6F0306"),
    "#EA005E": ("#FF95CA", "#FF529F", "#FF0A6F", "#D30050", "#9E002F", "#6D0011"),
    "#EF6950": ("#FCC2A3", "#F7A083", "#F1795F", "#EC492D", "#B12210", "#670E09"),
    "#F7630C": ("#FEBD68", "#FB9A44", "#F8741D", "#E05307", "#A13105", "#691202"),
    "#FF4343": ("#FFAB9B", "#FF8279", "#FF5653", "#FF1F1F", "#C90000", "#7C0000"),
    "#FF8C00": ("#FFD155", "#FFB634", "#FF9910", "#E37700", "#A14600", "#651900"),
    "#FFB900": ("#FFE845", "#FFD52A", "#FFC20D", "#E19D00", "#9B5D00", "#5C2100"),
}


def make_bindings(template, rendered, values):
    source = template.splitlines(keepends=True)
    lines = rendered.splitlines(keepends=True)
    if len(source) != len(lines):
        raise ValueError("Kvantum template changed line structure")
    bindings = []
    for i, line in enumerate(source):
        matches = list(ROLE.finditer(line))
        if not matches:
            continue
        if len(matches) != 1:
            raise ValueError("Ambiguous accent binding")
        match = matches[0]
        role = match[1]
        prefix = Template(line[:match.start()]).substitute(values)
        suffix = Template(line[match.end():]).substitute(values)
        if lines[i] != prefix + values[role] + suffix:
            raise ValueError("Generated accent binding does not match Kvantum")
        bindings.append([i, role, prefix, suffix])
    if not bindings:
        raise ValueError("Missing Kvantum accent bindings")
    return {"lines": len(lines), "bindings": bindings}


def rgb(value):
    if COLOR.fullmatch(value):
        return value.upper()
    fields = [field.strip() for field in value.split(",")]
    if len(fields) not in (3, 4) or not all(re.fullmatch(r"\d{1,3}", x) for x in fields):
        raise ValueError("Invalid KDE selection color")
    channels = list(map(int, fields))
    if any(x > 255 for x in channels) or (len(channels) == 4 and channels[3] != 255):
        raise ValueError("Expected opaque KDE selection color")
    return "#" + "".join(f"{x:02X}" for x in channels[:3])


def custom_hsl_coordinates(channels):
    lo, hi = min(channels), max(channels)
    lightness = Fraction(lo + hi, 510)
    saturation = (Fraction(hi - lo, 255 - abs(lo + hi - 255))
                  if hi != lo else Fraction(0))
    return lightness, saturation


CUSTOM_LAB_MIN_SATURATION = Fraction(3, 20)


def uses_custom_lab(channels):
    lightness, saturation = custom_hsl_coordinates(channels)
    return (Fraction(1, 4) <= lightness <= Fraction(3, 4)
            and saturation >= CUSTOM_LAB_MIN_SATURATION)


# Candidate for the central custom-color branch, not the preset lookup
# or the wallpaper extractor. Mathematical description:
# https://gist.github.com/cnbluefire/7ffa04c493c57b8a67f6a8baa2c726f7
# Use standard sRGB/D65 CIELAB conversions and Python's HLS routines.
# Keep the original input distinct from the normalized output Accent.
def derive_custom_lab_palette(selection):
    source = tuple(bytes.fromhex(rgb(selection)[1:]))
    if not uses_custom_lab(source):
        raise ValueError("Custom accent outside the reviewed CIELAB branch")

    def linear(channel):
        c = channel / 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    def lab_component(x):
        return x ** (1 / 3) if x > 0.008856 else 7.787 * x + 16 / 116

    def inverse_lab_component(x):
        return x ** 3 if x > 6 / 29 else (x - 16 / 116) / 7.787

    def byte(value):
        return math.floor(max(0, min(255, value)) + 0.5)

    def encode(channel):
        c = (12.92 * channel if channel <= 0.0031308
             else 1.055 * channel ** (1 / 2.4) - 0.055)
        return byte(255 * c)

    r, g, b = map(linear, source)
    fx, fy, fz = map(lab_component, (
        (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047,
        0.2126 * r + 0.7152 * g + 0.0722 * b,
        (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883,
    ))
    a, b = 500 * (fx - fy), 200 * (fy - fz)

    def from_lab(light):
        y = (light + 16) / 116
        x = 0.95047 * inverse_lab_component(y + a / 500)
        z = 1.08883 * inverse_lab_component(y - b / 200)
        y = inverse_lab_component(y)
        return tuple(map(encode, (
            3.2406 * x - 1.5372 * y - 0.4986 * z,
            -0.9689 * x + 1.8758 * y + 0.0415 * z,
            0.0557 * x - 0.2040 * y + 1.0570 * z,
        )))

    base = from_lab(max(49.0, min(50.0, 116 * fy - 16)))
    dark, light = from_lab(0.0), from_lab(100.0)
    _, _, base_saturation = colorsys.rgb_to_hls(*(x / 255 for x in base))

    def shade(endpoint, weight):
        mixed = tuple(byte(x * (1 - weight) + y * weight)
                      for x, y in zip(base, endpoint))
        h, l, s = colorsys.rgb_to_hls(*(x / 255 for x in mixed))
        return tuple(byte(255 * x) for x in
                     colorsys.hls_to_rgb(h, l, max(s, base_saturation)))

    colors = {
        "Accent": base,
        "AccentLight1": shade(light, 0.16),
        "AccentLight2": shade(light, 0.58),
        "AccentLight3": shade(light, 0.82),
        "AccentDark1": shade(dark, 0.22),
        "AccentDark2": shade(dark, 0.50),
        "AccentDark3": shade(dark, 0.82),
    }
    return {role: "#" + bytes(channels).hex().upper()
            for role, channels in colors.items()}


# Candidate for the legacy HSL branch, based on the same mathematical
# research lead. Use exact rational arithmetic for 8-bit input and nominal
# decimal offsets: the measured near-gray vector exposes integer
# boundaries where float32 offsets plus truncation can differ by one.
# This is not a claim of Windows bitwise parity for all boundary colors.
def derive_custom_palette(selection):
    source = tuple(bytes.fromhex(rgb(selection)[1:]))
    if uses_custom_lab(source):
        return derive_custom_lab_palette(selection)

    lightness, saturation = custom_hsl_coordinates(source)
    lightness = max(Fraction(1, 4), min(Fraction(3, 4), lightness))
    scale = 4 * abs(Fraction(1, 2) - lightness)
    lo, hi = min(source), max(source)
    span = hi - lo
    # The relative channel positions retain the input hue. Scaling the
    # chroma at the new lightness is equivalent to an HSL hue conversion.
    positions = tuple(Fraction(c - lo, span) if span else Fraction(0)
                      for c in source)
    result = {}
    for role, offset in (
            ("AccentLight3", 17), ("AccentLight2", 10), ("AccentLight1", 5),
            ("Accent", 0), ("AccentDark1", -5), ("AccentDark2", -10),
            ("AccentDark3", -17)):
        level = lightness + scale * Fraction(offset, 100)
        chroma = (1 - abs(2 * level - 1)) * saturation
        floor = level - chroma / 2
        # The HSL branch truncates, unlike the rounded CIELAB branch.
        channels = (int(255 * (floor + chroma * p)) for p in positions)
        result[role] = "#" + bytes(channels).hex().upper()
    return result


def derive_manual_palette(selection):
    """Return the candidate seven-role ramp for an original manual RGB input.

    A preset is matched by exact normalized RGB, before custom derivation.
    Do not pass a wallpaper-derived color or a previously derived Accent.
    """
    color = rgb(selection)
    shades = PRESET_SHADES.get(color)
    if shades is not None:
        return {"Accent": color, **dict(zip(PRESET_SHADE_ROLES, shades))}
    return derive_custom_palette(color)


def derive_wallpaper_alpha(range_sum, pixel_count):
    """Candidate colorization strength for already-preprocessed analysis pixels.

    range_sum is the sum of max(R,G,B)-min(R,G,B) across opaque pixels.
    pixel_count is the number of analysis pixels, not the source image size.
    This stage does not choose a representative RGB or decode/resize images.
    Transparent pixels, native fallbacks and multi-display analysis are
    outside the reviewed opaque-image contract. Do not use this value as
    the alpha of a Plasma, Qt or KWin surface.
    """
    if (type(range_sum) is not int or type(pixel_count) is not int
            or pixel_count <= 0 or not 0 <= range_sum <= 255 * pixel_count):
        raise ValueError("Invalid wallpaper analysis statistics")
    return min(175, 125 + range_sum // pixel_count)


def derive_automatic_palette(candidate):
    """Derive shades from the shell's pre-shade wallpaper color candidate.

    Pass the low 24 RGB bits of ImageColor (or the matching DWM
    ColorizationColor), never the wallpaper pixel or final UISettings
    Accent. None and candidates below the measured saturation boundary
    select the default blue ramp. The 0.15 boundary is provisional:
    current samples bracket it but do not establish the exact cutoff.
    """
    if candidate is None:
        return derive_manual_palette("#0078D4")
    color = rgb(candidate)
    channels = tuple(bytes.fromhex(color[1:]))
    lightness, saturation = custom_hsl_coordinates(channels)
    if saturation < CUSTOM_LAB_MIN_SATURATION:
        return derive_manual_palette("#0078D4")
    if not Fraction(1, 4) <= lightness <= Fraction(3, 4):
        raise ValueError("Automatic candidate outside the reviewed CIELAB range")
    # Automatic image candidates always use CIELAB, including RGB values
    # that happen to equal a manual preset. Do not apply preset lookup.
    return derive_custom_lab_palette(color)


def contrast_ink(color):
    channels = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4
              for x in channels]
    luminance = sum(x * w for x, w in zip(linear, (.2126, .7152, .0722)))
    return "#000000" if luminance > .179 else "#FFFFFF"


def accent_values(mode, defaults, selection):
    # Retain the shipped paint for the original default. On custom
    # accents, use contrasting solid-selection text and checked glyphs.
    color = rgb(selection)
    if color == defaults["accent"].upper():
        return defaults.copy()
    ink = contrast_ink(color)
    return {**defaults, "accent": color, "highlight_text": ink,
            "button_accent_text": ink, "checked_backing": ink,
            "selected_item_text": ink if mode == "light" else defaults["selected_item_text"]}


def patch(text, spec, values):
    lines = text.splitlines(keepends=True)
    if len(lines) != spec["lines"]:
        raise ValueError("Kvantum layout differs from installed accent bindings")
    seen = set()
    for index, role, prefix, suffix in spec["bindings"]:
        if index in seen or not 0 <= index < len(lines) or role not in ROLES:
            raise ValueError("Invalid Kvantum accent binding")
        seen.add(index)
        allowed = r"(?:#[0-9a-fA-F]{6}|none)" if role == "checked_backing" else r"#[0-9a-fA-F]{6}"
        if not re.fullmatch(re.escape(prefix) + allowed + re.escape(suffix), lines[index]):
            raise ValueError(f"Unrecognized Kvantum accent field at line {index + 1}")
        if not re.fullmatch(allowed, values[role]):
            raise ValueError("Invalid replacement accent paint")
        lines[index] = prefix + values[role] + suffix
    return "".join(lines)


def owned_file(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_uid != os.getuid():
        raise ValueError(f"Not a user-owned theme file: {path}")
    return path


def atomic_write(path, data):
    mode = stat.S_IMODE(path.stat().st_mode)
    fd, name = tempfile.mkstemp(prefix=".wm-accent-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as out:
            os.fchmod(out.fileno(), mode)
            out.write(data)
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def synchronize(directory, mode, selection):
    if os.geteuid() == 0:
        raise ValueError("Run accent synchronization as the desktop user")
    if any(p.is_symlink() for p in (directory, directory.parent)):
        raise ValueError("Refusing externally managed Kvantum directory")
    if not directory.is_dir():
        return False
    manifest = owned_file(directory / "accent-bindings.json")
    entry = json.loads(manifest.read_text(encoding="utf-8"))[mode]
    values = accent_values(mode, entry["defaults"], selection)
    name = "Windows-modernDark" if mode == "dark" else "Windows-modern"
    expected = {name + ".kvconfig", name + ".svg"}
    if set(entry["files"]) != expected:
        raise ValueError("Unexpected Kvantum accent binding files")

    # Validate both outputs before touching either file; preserve all
    # unrelated lines, including local window and transparency overrides.
    pending = {}
    for filename, spec in entry["files"].items():
        path = owned_file(directory / filename)
        old = path.read_bytes()
        new = patch(old.decode("utf-8"), spec, values)
        if filename.endswith(".svg"):
            ET.fromstring(new)
        if old != new.encode("utf-8"):
            pending[path] = (old, new.encode("utf-8"))
    written = []
    try:
        for path, (old, new) in pending.items():
            if owned_file(path).read_bytes() != old:
                raise ValueError(f"Theme changed during accent synchronization: {path}")
            atomic_write(path, new)
            written.append(path)
    except (OSError, ValueError):
        for path in reversed(written):
            old, new = pending[path]
            if owned_file(path).read_bytes() == new:
                atomic_write(path, old)
        raise
    return bool(pending)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("mode", choices=("dark", "light"))
    parser.add_argument("selection")
    args = parser.parse_args()
    try:
        changed = synchronize(args.directory, args.mode, args.selection)
    except (OSError, ValueError, KeyError, TypeError, ET.ParseError) as error:
        parser.exit(1, f"Kvantum accent: {error}\n")
    print("changed" if changed else "unchanged")
