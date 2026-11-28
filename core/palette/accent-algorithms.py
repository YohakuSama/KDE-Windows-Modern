# SPDX-License-Identifier: GPL-3.0-or-later
"""Windows 11 accent ramp arithmetic and bounded local wallpaper color analysis.

This module owns preset lookup, custom CIELAB/HSL shade derivation, contrast ink
selection, manual batch report comparison, and bounded still-image decoding,
ICC pre-conversion, WIC candidate resampling, and weighted-RGB seed extraction.
It has no dependency on KDE configuration, Kvantum, or file transactions.
"""
from fractions import Fraction
from functools import lru_cache
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import stat
import struct
import sys
import warnings

COLOR = re.compile(r"#[0-9a-fA-F]{6}")


def _load_adjacent(module_name, filename):
    path = Path(__file__).absolute().with_name(filename)
    key = f"{module_name}:{path.absolute().as_posix()}"
    cached = sys.modules.get(key)
    if cached is not None:
        return cached
    spec = importlib.util.spec_from_file_location(key, path)
    if spec is None or spec.loader is None:
        raise ImportError(f"Unable to load adjacent module: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[key] = module
    try:
        spec.loader.exec_module(module)
    except Exception:
        sys.modules.pop(key, None)
        raise
    return module


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


def _mix_lab_shade(base, endpoint, percent):
    """Mix rounded RGB endpoints and restore saturation with exact arithmetic.

    The candidate's nominal decimal weights specify half-up rounding.
    Keep this byte-domain stage separate from the floating-point LAB
    conversion and the legacy HSL branch's truncation.
    """
    mixed = tuple((x * (100 - percent) + y * percent + 50) // 100
                  for x, y in zip(base, endpoint))
    _, base_saturation = custom_hsl_coordinates(base)
    lightness, saturation = custom_hsl_coordinates(mixed)
    if saturation >= base_saturation:
        return mixed

    # Scaling the chroma around the same lightness retains the mixed
    # RGB hue. For an achromatic mix use hue zero, as colorsys did.
    lo, hi = min(mixed), max(mixed)
    span = hi - lo
    positions = (tuple(Fraction(c - lo, span) for c in mixed)
                 if span else (Fraction(1), Fraction(0), Fraction(0)))
    chroma = (1 - abs(2 * lightness - 1)) * base_saturation
    floor = lightness - chroma / 2
    return tuple(int(255 * (floor + chroma * p) + Fraction(1, 2))
                 for p in positions)


# Candidate for the central custom-color branch, not the preset lookup
# or the wallpaper extractor. Mathematical description:
# https://gist.github.com/cnbluefire/7ffa04c493c57b8a67f6a8baa2c726f7
# Use standard sRGB/D65 CIELAB conversions and exact byte-domain HSL arithmetic.
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
    colors = {
        "Accent": base,
        "AccentLight1": _mix_lab_shade(base, light, 16),
        "AccentLight2": _mix_lab_shade(base, light, 58),
        "AccentLight3": _mix_lab_shade(base, light, 82),
        "AccentDark1": _mix_lab_shade(base, dark, 22),
        "AccentDark2": _mix_lab_shade(base, dark, 50),
        "AccentDark3": _mix_lab_shade(base, dark, 82),
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


def compare_manual_palette_reports(paths):
    """Compare original manual inputs with verified target-build observations.

    Merge partial batches, keep skipped colors unobserved, and retain
    the operator-confirmed input separately from the measured output.
    Never publish palettes or change desktop configuration here.
    """
    roles = (*PRESET_SHADE_ROLES[:3], "Accent", *PRESET_SHADE_ROLES[3:])
    requested, observed, identities = {}, {}, []

    def color_list(values):
        if (not isinstance(values, list)
                or any(not isinstance(value, str) or not COLOR.fullmatch(value)
                       for value in values)):
            raise ValueError("Invalid manual palette color list")
        colors = [value.upper() for value in values]
        if len(set(colors)) != len(colors):
            raise ValueError("Duplicate manual palette color")
        return colors

    for path in paths:
        with Path(path).open("rb") as stream:
            raw = stream.read(8 * 1024 * 1024 + 1)
        if len(raw) > 8 * 1024 * 1024:
            raise ValueError("Oversized manual palette report")
        report = json.loads(raw.decode("utf-8-sig"))
        if (type(report["schema_version"]) is not int or report["schema_version"] != 1
                or report["windows_build"] != "26300.9974"
                or report["probe_set"] != "ManualPaletteBatch"
                or type(report["completed"]) is not bool):
            raise ValueError("Unexpected manual palette report identity")
        targets = color_list(report["requested_colors"])
        skipped = set(color_list(report["skipped_colors"]))
        if not targets or not skipped.issubset(targets) or not isinstance(report["samples"], list):
            raise ValueError("Invalid manual palette batch coverage")
        requested.update(dict.fromkeys(targets))
        seen = set()
        for sample in report["samples"]:
            selection = color_list([sample["requested_color"]])[0]
            kind = "preset" if selection in PRESET_SHADES else "custom"
            capture = sample["capture"]
            if (selection not in targets or selection in seen or selection in skipped
                    or sample["input_kind"] != kind
                    or sample["input_confirmed_by_operator"] is not True
                    or capture["schema_version"] != 5
                    or capture["windows_build"] != report["windows_build"]
                    or capture["accent_mode_argument"] != "Manual"
                    or capture["accent_mode_registry"] != "Manual"
                    or capture["accent_mode_registry_conflict"] is not False
                    or color_list([capture["manual_color_argument"]])[0] != selection):
                raise ValueError("Inconsistent manual palette sample identity")
            appearance = capture["appearance"]
            registry = appearance["registry"]
            modes = (registry["control_panel_auto_colorization_raw"],
                     registry["themes_history_auto_color_raw"])
            if not any(type(value) is int and value == 0 for value in modes) or any(
                    value is not None and (type(value) is not int or value != 0)
                    for value in modes):
                raise ValueError("Manual palette registry mode is not verified")
            palette_hex = registry["accent_palette_hex"]
            if (registry["accent_palette_length_bytes"] != 32
                    or not isinstance(palette_hex, str)
                    or not re.fullmatch(r"[0-9a-fA-F]{64}", palette_hex)):
                raise ValueError("Invalid manual palette registry data")
            ramp = {}
            for index, role in enumerate(roles):
                value = appearance["colors_argb"][role]
                if (not isinstance(value, str) or not re.fullmatch(r"#FF[0-9a-fA-F]{6}", value)
                        or value[3:].upper() != palette_hex[index * 8:index * 8 + 6].upper()):
                    raise ValueError("Manual palette UISettings/registry disagreement")
                ramp[role] = "#" + value[3:].upper()
            base_argb = "#FF" + ramp["Accent"][1:]
            if (capture["accent_observed_from_ui_settings"].upper() != base_argb
                    or capture["manual_color_observed_from_ui_settings"].upper() != base_argb
                    or capture["manual_color_matches_observed"] is not (ramp["Accent"] == selection)
                    or (kind == "preset" and ramp["Accent"] != selection)):
                raise ValueError("Inconsistent observed manual accent")
            if selection in observed and observed[selection] != ramp:
                raise ValueError("Conflicting manual palette observations for " + selection)
            observed[selection] = ramp
            seen.add(selection)
        if report["completed"] and seen != set(targets):
            raise ValueError("Incomplete manual palette report marked complete")
        identities.append(hashlib.sha256(raw).hexdigest())

    rows = {}
    for selection, ramp in observed.items():
        candidate = derive_manual_palette(selection)
        differences = {role: {"observed": ramp[role], "candidate": candidate[role]}
                       for role in roles if candidate[role] != ramp[role]}
        rows[selection] = {
            "input_kind": "preset" if selection in PRESET_SHADES else "custom",
            "input_confirmed_by_operator": True,
            "observed": ramp, "candidate": candidate, "differences": differences,
        }
    return {
        "windows_build": "26300.9974", "report_sha256": identities,
        "requested_count": len(requested), "observed_count": len(rows),
        "matched_count": sum(not row["differences"] for row in rows.values()),
        "mismatched_count": sum(bool(row["differences"]) for row in rows.values()),
        "remaining_requested_colors": [color for color in requested if color not in rows],
        "presets_not_observed_in_these_reports": sorted(set(PRESET_SHADES) - rows.keys()),
        "samples": rows,
    }


def derive_wallpaper_alpha(range_sum, pixel_count):
    """Candidate colorization strength for already-preprocessed analysis pixels.

    range_sum is the sum of max(R,G,B)-min(R,G,B) across valid bitmap pixels.
    pixel_count includes every analysis position, including skipped pixels.
    Sum both statistics across images before division. This stage does
    not decode/resize images or represent native fallback results.
    Do not use this value as the alpha of a Plasma, Qt or KWin surface.
    """
    if (type(range_sum) is not int or type(pixel_count) is not int
            or pixel_count <= 0 or not 0 <= range_sum <= 255 * pixel_count):
        raise ValueError("Invalid wallpaper analysis statistics")
    return min(175, 125 + range_sum // pixel_count)


# The weighted-RGB branch was recovered from shell32 10.0.26100.9974.
# These functions consume already prepared analysis buffers. Source-file
# decoding and full WIC bilinear parity remain separate work.
WALLPAPER_ANALYSIS_LIMIT = 256


def _f32(value):
    return struct.unpack("<f", struct.pack("<f", value))[0]


def _wallpaper_axis_samples(source, target):
    # Pixel-center mapping: (i + 0.5) * source / target - 0.5.
    # Integer coordinates retain the fractional weight without float drift.
    denominator = 2 * target
    for i in range(target):
        low, fraction = divmod((2 * i + 1) * source - target, denominator)
        yield (max(0, min(source - 1, low)),
               max(0, min(source - 1, low + 1)),
               denominator - fraction, fraction)


def _prepare_wallpaper_bitmap(pixels, width, height, channels, transform=None):
    """Resample packed RGB, premultiplied RGBa or ICC-tagged RGB/Gray.

    With an ICC transform, convert contributing straight RGB or Gray
    samples before premultiplying and interpolating. Without a transform,
    four-channel input must already be premultiplied. Gray and GrayAlpha
    input always requires a single-channel ICC transform.
    """
    if (any(type(n) is not int or n <= 0 for n in (width, height))
            or channels not in (1, 2, 3, 4)
            or (channels in (1, 2) and transform is None)
            or not isinstance(pixels, bytes) or len(pixels) != width * height * channels):
        raise ValueError("Expected tightly packed RGB8, RGBa8 or ICC-tagged Gray8/GrayAlpha8")
    has_alpha = channels in (2, 4)
    color_channels = channels - int(has_alpha)
    w, h = min(width, WALLPAPER_ANALYSIS_LIMIT), min(height, WALLPAPER_ANALYSIS_LIMIT)
    xs = [(left * channels, right * channels, a, b)
          for left, right, a, b in _wallpaper_axis_samples(width, w)]
    denominator = 4 * w * h
    output = bytearray(w * h * 4)
    offset = 0
    for top, bottom, c, d in _wallpaper_axis_samples(height, h):
        top *= width * channels
        bottom *= width * channels
        for left, right, a, b in xs:
            weights = a * c, b * c, a * d, b * d
            positions = top + left, top + right, bottom + left, bottom + right

            # Color conversion is pointwise and precedes bilinear
            # interpolation. Only the four contributing source taps are
            # transformed, not the entire full-resolution image.
            if transform is not None:
                if has_alpha:
                    samples = []
                    for position, weight in zip(positions, weights):
                        marker = pixels[position + color_channels]
                        if weight and marker:
                            converted = transform(*pixels[position:position + color_channels])
                            samples.append(tuple((value * marker + 127) // 255
                                                 for value in converted) + (marker,))
                        else:
                            # Hidden color is converted in the measured RGB cache,
                            # but a zero-alpha tap contributes no premultiplied
                            # color. Avoid needless ICC work on invisible taps.
                            samples.append((0, 0, 0, marker))
                else:
                    samples = [transform(*pixels[position:position + channels]) if weight else (0, 0, 0)
                               for position, weight in zip(positions, weights)]

                def interpolate(channel):
                    return sum(sample[channel] * weight
                               for sample, weight in zip(samples, weights)) // denominator
            else:
                def interpolate(channel):
                    return sum(pixels[position + channel] * weight
                               for position, weight in zip(positions, weights)) // denominator

            # Transformed samples always have RGB output, even for LA.
            alpha = interpolate(3) if has_alpha else 255
            if alpha:
                # DecodeAlphaProfile matches a truncated fixed-point
                # reciprocal, not exact integer division. Q16 matches
                # all measured gradients and mixed-alpha RGB edges.
                reciprocal = (255 << 16) // alpha if has_alpha else 0
                for channel in range(3):
                    value = interpolate(channel)
                    if has_alpha:
                        value = min(255, (value * reciprocal) >> 16)
                    output[offset + 2 - channel] = value
            output[offset + 3] = alpha
            offset += 4
    return w, h, bytes(output)


def prepare_opaque_wallpaper_bitmap(pixels, width, height):
    """Prepare a candidate top-down BGRX analysis bitmap from packed RGB8.

    Pixel-center bilinear interpolation with truncation matches the
    three measured WIC BMP buffers byte for byte. This is not a claim
    of universal WIC decoder, format-conversion or rounding parity.
    """
    return _prepare_wallpaper_bitmap(pixels, width, height, 3)


def prepare_premultiplied_wallpaper_bitmap(pixels, width, height):
    """Prepare a candidate BGR/alpha bitmap from packed premultiplied RGBa8.

    DecodeBoundary on Windows build 26300.9974 shows (R,G,B,A) values
    (225,48,48,128) becoming (225,47,47,128), alpha 1 becoming
    (255,0,0,1), and alpha zero becoming (0,0,0,0). Interpolate
    premultiplied channels and alpha before undoing premultiplication.
    DecodeAlphaProfile additionally measures gradients and mixed-alpha
    edges. The Q16 reciprocal candidate reproduces all six source and
    six transcoded buffers. Other formats and geometries are not proven.
    """
    return _prepare_wallpaper_bitmap(pixels, width, height, 4)


# Keep full-image decoding bounded independently of the 256-pixel analysis
# limit. 40 million pixels allow conventional 8K still images.
WALLPAPER_DECODE_PIXEL_LIMIT = 40_000_000
WALLPAPER_IMAGE_FORMATS = ("BMP", "JPEG", "PNG", "WEBP")
# Bump when decoder/analysis semantics change; installed automatic state
# must not reuse a palette computed by the previous decoder.
WALLPAPER_ANALYSIS_REVISION = 11


@lru_cache(maxsize=1)
def _native_icc_module():
    return vars(_load_adjacent("windows_modern_wallpaper_icc", "wallpaper-icc.py"))


def icc_reference_identity():
    return _native_icc_module()["reference_identity"]()


def _icc_wallpaper_transform(image, profile_bytes):
    """Select the reviewed ICC executor without changing the source color space."""
    if not isinstance(profile_bytes, bytes) or not profile_bytes:
        raise ValueError("Invalid embedded wallpaper ICC profile")
    gray = profile_bytes[16:20] == b"GRAY"
    if gray:
        if image.mode not in ("L", "LA"):
            raise ValueError("Gray ICC requires a reviewed Gray8 image mode")
    elif image.mode not in ("RGB", "RGBA", "P"):
        raise ValueError("Embedded ICC requires a reviewed RGB8 image mode")
    transform = _native_icc_module()["transform_for_profile"](profile_bytes)
    if transform is None:
        kind = "Gray8" if gray else "RGB8"
        raise ValueError(f"Wallpaper ICC requires a reviewed {kind} ICC transform")
    return transform, gray


def _icc_wallpaper_bitmap(image, transform, gray):
    """Convert contributing straight RGB or Gray taps before opaque resampling."""
    mode = "L" if gray else "RGB"
    channels = 1 if gray else 3
    if image.mode == mode:
        return _prepare_wallpaper_bitmap(image.tobytes(), image.width, image.height, channels, transform)
    with image.convert(mode) as decoded:
        return _prepare_wallpaper_bitmap(decoded.tobytes(), decoded.width, decoded.height, channels, transform)


class WallpaperFileChangedError(ValueError):
    """An image changed after its initial file identity was captured."""


def wallpaper_file_identity(path):
    """Identity of the current local file, shared by analysis and caching."""
    info = path.stat()
    if not stat.S_ISREG(info.st_mode):
        raise ValueError("Expected a local wallpaper image file")
    return {"device": info.st_dev, "inode": info.st_ino, "size": info.st_size,
            "mtime_ns": info.st_mtime_ns, "ctime_ns": info.st_ctime_ns}


def decode_wallpaper_bitmap(path):
    """Decode a local still image into the candidate WIC analysis buffer.

    Preserve the untagged opaque RGB path. Tagged RGB images use the
    reviewed fixed-point RGB8 executor before resampling. For untagged
    transparent PNG use Pillow's premultiplied RGBa path. Tagged RGB PNG
    uses the same transform before premultiplication. Unsupported ICC
    profiles and unreviewed tagged image modes are explicit decoder errors.
    Gray8 and GrayAlpha8 PNG use the same fixed-point executor with its
    gray grid. The combined gray/alpha ordering is a candidate derived
    from the measured RGB-alpha path and independent gray ramp, not yet
    an end-to-end native gray-alpha measurement.
    Do not re-encode or alter the source.
    """
    try:
        from PIL import Image, ImageOps
    except ImportError as error:
        raise ValueError("Pillow is required for wallpaper analysis") from error

    path = Path(path)
    if not path.is_file():
        raise ValueError("Expected a local wallpaper image file")
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(path, formats=WALLPAPER_IMAGE_FORMATS) as source:
                if source.width * source.height > WALLPAPER_DECODE_PIXEL_LIMIT:
                    raise ValueError("Wallpaper exceeds the analysis decode limit")
                if getattr(source, "n_frames", 1) != 1:
                    raise ValueError("Animated wallpapers are not supported")
                if source.mode not in ("1", "L", "LA", "P", "RGB", "RGBA"):
                    raise ValueError("Wallpaper pixel format is outside the reviewed RGB contract")
                orientation = source.getexif().get(274, 1)
                if orientation not in range(1, 9):
                    raise ValueError("Invalid wallpaper orientation")
                profile = source.info.get("icc_profile")
                # Pillow retains the key with None when JPEG ICC fragments
                # are missing or a PNG iCCP stream cannot be decompressed.
                if "icc_profile" in source.info and not profile:
                    raise ValueError("Unreadable embedded wallpaper ICC profile")
                image = ImageOps.exif_transpose(source) if orientation != 1 else source
                try:
                    transform, gray = (None, False) if profile is None else _icc_wallpaper_transform(image, profile)
                    if "A" in image.getbands() or "transparency" in image.info:
                        # Preserve gray samples for a Gray ICC profile.
                        # Pillow's LA conversion also expands a Gray8 PNG
                        # transparency key. Never convert a Gray ICC to RGB.
                        alpha_mode = "LA" if gray else "RGBA"
                        alpha_image = image if image.mode == alpha_mode else image.convert(alpha_mode)
                        try:
                            if alpha_image.getextrema()[-1] != (255, 255):
                                if source.format != "PNG":
                                    raise ValueError("Transparent wallpaper outside the reviewed PNG contract")
                                if transform is not None:
                                    return _prepare_wallpaper_bitmap(
                                        alpha_image.tobytes(), alpha_image.width, alpha_image.height,
                                        2 if gray else 4, transform)
                                with alpha_image.convert("RGBa") as premultiplied:
                                    return prepare_premultiplied_wallpaper_bitmap(
                                        premultiplied.tobytes(), premultiplied.width,
                                        premultiplied.height)
                        finally:
                            if alpha_image is not image:
                                alpha_image.close()
                    if transform is not None:
                        return _icc_wallpaper_bitmap(image, transform, gray)
                    if image.mode == "RGB":
                        return prepare_opaque_wallpaper_bitmap(
                            image.tobytes(), image.width, image.height)
                    with image.convert("RGB") as decoded:
                        return prepare_opaque_wallpaper_bitmap(
                            decoded.tobytes(), decoded.width, decoded.height)
                finally:
                    if image is not source:
                        image.close()
    except (Image.DecompressionBombError, Image.DecompressionBombWarning) as error:
        raise ValueError("Wallpaper exceeds the decoder safety limit") from error


def _wallpaper_analysis_count(width, height):
    if any(type(n) is not int or not 1 <= n <= WALLPAPER_ANALYSIS_LIMIT
           for n in (width, height)):
        raise ValueError("Invalid wallpaper analysis dimensions")
    return width * height


def _opaque_wallpaper_pixels(pixels):
    for pixel in pixels:
        if (not isinstance(pixel, (tuple, list)) or len(pixel) != 3
                or any(type(v) is not int or not 0 <= v <= 255 for v in pixel)):
            raise ValueError("Expected opaque RGB byte triplets")
        yield pixel, True


def _weighted_wallpaper_statistics(pixels, count):
    # shell32 0x124870..0x124885: unsigned reciprocal multiply and shift.
    # (count * 0x10624dd3) >> 36 equals count // 250 for analysis sizes.
    stride = max(1, count // 250)
    range_sum = 0
    totals = [0.0, 0.0, 0.0]
    sums = [[0.0, 0.0, 0.0] for _ in range(3)]
    for i, (pixel, valid) in enumerate(pixels):
        # A zero fourth bitmap byte skips the pixel, not its position.
        if not valid:
            continue
        range_sum += max(pixel) - min(pixel)
        if i % stride:
            continue
        r, g, b = channels = tuple(_f32(v / 255) for v in pixel)
        peak = max(channels)
        # Ties go to red, then green, then blue. Each sampled pixel
        # contributes its full weighted RGB to the winning channel group.
        group = channels.index(peak)
        distance = max(_f32(0.01), _f32(_f32(_f32(peak - g)
                                             + _f32(peak - r)) + _f32(peak - b)))
        weight = _f32(_f32(_f32(_f32(r + g) + b) * distance)
                      + _f32(distance + distance))
        totals[group] += weight
        for channel, value in enumerate(channels):
            sums[group][channel] += _f32(weight * value)
    return totals, sums, range_sum, count


def _reduce_weighted_wallpaper_statistics(statistics):
    totals = [0.0, 0.0, 0.0]
    sums = [[0.0, 0.0, 0.0] for _ in range(3)]
    range_sum = count = 0
    for weights, channels, span, size in statistics:
        range_sum += span
        count += size
        # Native reduction merges per-image group accumulators before
        # choosing a winner. Sampling starts at zero for each image.
        for group in range(3):
            totals[group] += weights[group]
            for channel in range(3):
                sums[group][channel] += channels[group][channel]
    if count == 0:
        raise ValueError("No wallpaper analysis buffers")
    winner = max(range(3), key=totals.__getitem__)
    if totals[winner] == 0:
        # No sampled group: native keeps its fallback color. The caller
        # must not normalize a fabricated seed or confuse this with a
        # failed decode. Do not apply the normal Alpha formula here.
        return None
    seed = bytes(int(min(255, total / totals[winner] * 255))
                 for total in sums[winner])
    return "#" + seed.hex().upper(), derive_wallpaper_alpha(range_sum, count)


def derive_weighted_wallpaper_seed(pixels, width, height):
    """Return (raw weighted RGB, alpha) from an opaque RGB analysis buffer."""
    count = _wallpaper_analysis_count(width, height)
    if len(pixels) != count:
        raise ValueError("Invalid wallpaper analysis dimensions")
    return _reduce_weighted_wallpaper_statistics((
        _weighted_wallpaper_statistics(_opaque_wallpaper_pixels(pixels), count),))


def _bitmap_wallpaper_statistics(width, height, bitmap):
    count = _wallpaper_analysis_count(width, height)
    if not isinstance(bitmap, bytes) or len(bitmap) != count * 4:
        raise ValueError("Expected a tightly packed 32-bit analysis bitmap")
    # Top-down rows, B/G/R/fourth byte. The final byte is a validity
    # check in the native loop. Measured untagged PNG buffers preserve
    # resized alpha, but nonzero values are not additional weights.
    pixels = (((r, g, b), marker != 0)
              for b, g, r, marker in struct.iter_unpack("4B", bitmap))
    return _weighted_wallpaper_statistics(pixels, count)


def derive_weighted_wallpaper_bitmaps(bitmaps):
    """Reduce one or more prepared bitmaps, yielding a seed/alpha or None.

    Each entry is (width, height, bytes), with tightly packed top-down
    B/G/R/fourth-byte pixels. Input dimensions are already capped at 256.
    RGB is consumed as stored, without unpremultiplication or weighting
    by the fourth byte. Every position contributes to the denominator;
    positions with a zero fourth byte do not contribute to the sums.
    None means no sampled group. Invalid or empty input raises ValueError.
    A decoder failure must remain an error, not a no-candidate result.
    """
    return _reduce_weighted_wallpaper_statistics(
        _bitmap_wallpaper_statistics(width, height, bitmap)
        for width, height, bitmap in bitmaps)


def _wallpaper_brightness(channels):
    # Native brightness is weighted RMS in encoded RGB, not CIELAB L*.
    r, g, b = (_f32(v / 255) for v in channels)
    green = _f32(_f32(g * g) * _f32(0.7152))
    red = _f32(_f32(r * r) * _f32(0.2126))
    blue = _f32(_f32(b * b) * _f32(0.0722))
    return _f32(math.sqrt(_f32(_f32(green + red) + blue)))


def _bound_wallpaper_brightness(channels, low, high):
    current = _wallpaper_brightness(channels)
    target = max(low, min(high, current))
    if target == current:
        return channels
    if current == 0:
        return (int(_f32(target * 255)),) * 3
    scale = _f32(target / current)
    return tuple(int(_f32(min(1, _f32(scale * _f32(v / 255))) * 255))
                 for v in channels)


def _wallpaper_luminance(channels):
    # Contrast uses a different, linear-light brightness measurement.
    def linear(v):
        value = _f32(v / 255)
        if value <= _f32(0.03928):
            return _f32(value / _f32(12.92))
        return _f32(_f32(_f32(value + _f32(0.055)) / _f32(1.055)) ** _f32(2.4))

    r, g, b = map(linear, channels)
    return _f32(_f32(_f32(g * _f32(0.7152)) + _f32(r * _f32(0.2126)))
                + _f32(b * _f32(0.0722)))


def _wallpaper_hls(channels):
    # The native normalizer calls SHLWAPI's integer HLS (0..240) API.
    # Keep its quantization separate from the later CIELAB palette stage.
    high, low = max(channels), min(channels)
    span, total = high - low, high + low
    light = (total * 240 + 255) // 510
    if span == 0:
        return 160, light, 0
    denominator = total if light <= 120 else 510 - total
    saturation = (span * 240 + denominator // 2) // denominator
    rd, gd, bd = (((high - v) * 40 + span // 2) // span for v in channels)
    if channels[0] == high:
        hue = bd - gd
    elif channels[1] == high:
        hue = 80 + rd - bd
    else:
        hue = 160 + gd - rd
    return hue % 240, light, saturation


def _wallpaper_rgb(hue, light, saturation):
    if saturation == 0:
        return (light * 255 // 240,) * 3
    upper = ((light * (240 + saturation) + 120) // 240 if light <= 120
             else light + saturation - (light * saturation + 120) // 240)
    lower = 2 * light - upper

    def channel(angle):
        angle %= 240
        if angle < 40:
            level = lower + ((upper - lower) * angle + 20) // 40
        elif angle < 120:
            level = upper
        elif angle < 160:
            level = lower + ((upper - lower) * (160 - angle) + 20) // 40
        else:
            level = lower
        return (level * 255 + 120) // 240

    return tuple(channel(hue + offset) for offset in (80, 0, -80))


def normalize_weighted_wallpaper_seed(seed):
    """Candidate native RGB normalization, before derive_automatic_palette.

    Input is the weighted seed, never the final Windows UI Accent. The
    target-build math is known; exact SHLWAPI and decoder/resampler parity
    for arbitrary image inputs still requires independent verification.
    """
    channels = tuple(bytes.fromhex(rgb(seed)[1:]))
    channels = _bound_wallpaper_brightness(
        channels, _f32(_f32(0.6) - _f32(0.05)), _f32(_f32(0.6) + _f32(0.05)))
    pivot = int(_f32(_wallpaper_brightness(channels) * 255))
    boosted = tuple(int(max(0, min(255, _f32(_f32((v - pivot) * _f32(1.4)) + pivot))))
                    for v in channels)
    # The valid contrast target against white is the darker solution.
    target = _f32(_f32(_f32(1.05) / _f32(3.2)) - _f32(0.05))
    hue, light, saturation = _wallpaper_hls(boosted)
    if target > _wallpaper_luminance(boosted):
        upper, lower, last = 240.0, float(light), 1.0
    else:
        upper, lower, last = float(light), 0.0, 0.0
    while abs(_f32(last - target)) > _f32(0.0001):
        middle = _f32(_f32(upper + lower) * 0.5)
        last = _wallpaper_luminance(_wallpaper_rgb(hue, int(middle), saturation))
        if last > target:
            upper = middle
        else:
            lower = middle
        if abs(_f32(upper - lower)) < _f32(0.024):
            break
    middle = int(_f32(_f32(upper + lower) * 0.5))
    adjusted = _wallpaper_rgb(hue, middle, saturation)
    candidate = _bound_wallpaper_brightness(adjusted, _f32(0.3), _f32(0.45))
    return "#" + bytes(candidate).hex().upper()


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


def analyze_wallpapers(paths):
    """Return the candidate automatic ramp for explicitly supplied files.

    Accumulate all prepared images before selecting a color. The caller
    chooses which actual display images to include; this function does
    not discover KDE containments, guess package variants, or write any
    configuration. The two mode accents are WinUI reference roles, not
    values already transformed by KDE's color applicator.
    """
    paths = tuple(Path(path) for path in paths)
    # Fingerprint the complete input set before decoding the first image.
    # Otherwise a later screen's file could change before its first read.
    identities = {path: wallpaper_file_identity(path) for path in dict.fromkeys(paths)}
    reference = icc_reference_identity()

    def validate():
        try:
            current_reference = icc_reference_identity()
        except (OSError, ValueError) as error:
            raise WallpaperFileChangedError("ICC reference changed during analysis") from error
        if current_reference != reference:
            raise WallpaperFileChangedError("ICC reference changed during analysis")
        for path, identity in identities.items():
            try:
                current = wallpaper_file_identity(path)
            except (OSError, ValueError) as error:
                raise WallpaperFileChangedError("Wallpaper disappeared during color analysis") from error
            if current != identity:
                raise WallpaperFileChangedError("Wallpaper changed during color analysis")

    def statistics():
        # Reuse bounded statistics, but merge each occurrence in screen order.
        cache = {}
        for path in paths:
            if path not in cache:
                cache[path] = _bitmap_wallpaper_statistics(*decode_wallpaper_bitmap(path))
            yield cache[path]

    try:
        result = _reduce_weighted_wallpaper_statistics(statistics())
    except (OSError, ValueError):
        # A concurrent replacement can itself cause a decoder failure.
        # Distinguish that retryable race from a stable unsupported image.
        validate()
        raise
    validate()
    if result is None:
        raise ValueError("No valid wallpaper color group")
    seed, alpha = result
    candidate = normalize_weighted_wallpaper_seed(seed)
    palette = derive_automatic_palette(candidate)
    return {
        "schema_version": 1,
        "weighted_seed": seed,
        "colorization_argb": f"0x{alpha:02X}{candidate[1:]}",
        "colorization_alpha": alpha,
        "palette": palette,
        "mode_accents": {
            "dark": palette["AccentLight2"],
            "light": palette["AccentDark1"],
        },
    }


def contrast_ink(color):
    channels = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4
              for x in channels]
    luminance = sum(x * w for x, w in zip(linear, (.2126, .7152, .0722)))
    return "#000000" if luminance > .179 else "#FFFFFF"
