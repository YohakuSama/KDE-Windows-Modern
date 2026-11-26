#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Analyze Windows-style colors and synchronize shared scheme and Kvantum roles."""
import argparse
from fractions import Fraction
from functools import lru_cache
from io import BytesIO
import hashlib
import json
import math
import os
from pathlib import Path
import re
import runpy
import stat
import struct
from string import Template
import tempfile
import warnings
import xml.etree.ElementTree as ET

ROLES = ("accent", "accent_link", "highlight_text", "selected_item_text",
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
    """Resample packed RGB or premultiplied RGBa bytes into B/G/R/marker."""
    if (any(type(n) is not int or n <= 0 for n in (width, height))
            or channels not in (3, 4)
            or not isinstance(pixels, bytes) or len(pixels) != width * height * channels):
        raise ValueError("Expected tightly packed RGB8 or premultiplied RGBa8")
    if transform is not None and channels != 3:
        raise ValueError("Native ICC replay requires opaque RGB8")
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
            # interpolation. Only the four contributing RGB taps are
            # transformed, not the entire full-resolution image.
            if transform is not None:
                samples = [transform(*pixels[position:position + 3]) if weight else (0, 0, 0)
                           for position, weight in zip(positions, weights)]

                def interpolate(channel):
                    return sum(sample[channel] * weight
                               for sample, weight in zip(samples, weights)) // denominator
            else:
                def interpolate(channel):
                    return sum(pixels[position + channel] * weight
                               for position, weight in zip(positions, weights)) // denominator

            alpha = interpolate(3) if channels == 4 else 255
            if alpha:
                for channel in range(3):
                    value = interpolate(channel)
                    if channels == 4:
                        # The measured WIC RGBA scaler/converter preserves
                        # alpha and truncates the unpremultiplied component.
                        value = min(255, value * 255 // alpha)
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
    Mixed-alpha interpolation edges and other formats remain unmeasured.
    """
    return _prepare_wallpaper_bitmap(pixels, width, height, 4)


# Keep full-image decoding bounded independently of the 256-pixel analysis
# limit. 40 million pixels allow conventional 8K still images.
WALLPAPER_DECODE_PIXEL_LIMIT = 40_000_000
WALLPAPER_IMAGE_FORMATS = ("BMP", "JPEG", "PNG", "WEBP")
# Bump when decoder/analysis semantics change; installed automatic state
# must not reuse a palette computed by the previous decoder.
WALLPAPER_ANALYSIS_REVISION = 4


@lru_cache(maxsize=1)
def _native_icc_module():
    return runpy.run_path(str(Path(__file__).with_name("wallpaper-icc.py")))


def icc_reference_identity():
    return _native_icc_module()["reference_identity"]()


def _icc_rgb_bitmap(image, profile_bytes):
    """Convert an opaque tagged RGB/gray image to the standard sRGB space.

    Privately imported, hash-matched RGB8 links use the measured
    fixed-point Windows replay. Other profiles use the existing Little
    CMS color-managed baseline, not an exact WCS reconstruction.
    Conversion precedes the existing analysis resampling step.
    """
    if not isinstance(profile_bytes, bytes) or not profile_bytes:
        raise ValueError("Invalid embedded wallpaper ICC profile")
    if image.mode in ("RGB", "RGBA", "P"):
        transform = _native_icc_module()["transform_for_profile"](profile_bytes)
        if transform is not None:
            if image.mode == "RGB":
                return _prepare_wallpaper_bitmap(image.tobytes(), image.width, image.height, 3, transform)
            with image.convert("RGB") as decoded:
                return _prepare_wallpaper_bitmap(decoded.tobytes(), decoded.width, decoded.height, 3, transform)
    try:
        from PIL import ImageCms
    except ImportError as error:
        raise ValueError("Pillow ImageCms is required for tagged wallpapers") from error
    try:
        profile = ImageCms.ImageCmsProfile(BytesIO(profile_bytes))
        space = profile.profile.xcolor_space.strip()
        if space == "RGB" and image.mode in ("RGB", "RGBA", "P"):
            input_mode = "RGB"
        elif space == "GRAY" and image.mode in ("1", "L", "LA"):
            input_mode = "L"
        else:
            raise ValueError("Embedded ICC color space does not match the reviewed image format")

        def convert(decoded):
            with ImageCms.profileToProfile(
                    decoded, profile, ImageCms.createProfile("sRGB"),
                    renderingIntent=ImageCms.Intent.RELATIVE_COLORIMETRIC,
                    outputMode="RGB") as managed:
                return prepare_opaque_wallpaper_bitmap(
                    managed.tobytes(), managed.width, managed.height)

        if image.mode == input_mode:
            return convert(image)
        with image.convert(input_mode) as decoded:
            return convert(decoded)
    except (ImportError, OSError, TypeError, ImageCms.PyCMSError) as error:
        raise ValueError("Wallpaper ICC conversion failed: " + str(error)) from error


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

    Preserve the untagged opaque RGB path. Convert tagged opaque RGB or
    grayscale images to sRGB before resampling, using verified local RGB8
    replay when available and the standard ICC transform otherwise.
    General WCS table generation remains unresolved. For untagged
    transparent PNG use Pillow's premultiplied RGBa path. Tagged
    transparent images remain outside the reviewed contract.
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
                image = ImageOps.exif_transpose(source) if orientation != 1 else source
                try:
                    if "A" in image.getbands() or "transparency" in image.info:
                        # A decoded RGBA image already has the required
                        # channels. Avoid a second full-size RGBA buffer.
                        rgba = image if image.mode == "RGBA" else image.convert("RGBA")
                        try:
                            if rgba.getextrema()[3] != (255, 255):
                                if source.format != "PNG" or profile is not None:
                                    raise ValueError("Transparent wallpaper outside the reviewed untagged PNG contract")
                                with rgba.convert("RGBa") as premultiplied:
                                    return prepare_premultiplied_wallpaper_bitmap(
                                        premultiplied.tobytes(), premultiplied.width,
                                        premultiplied.height)
                        finally:
                            if rgba is not image:
                                rgba.close()
                    if profile is not None:
                        return _icc_rgb_bitmap(image, profile)
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


def accent_values(mode, defaults, selection, link=None):
    # Native mode retains the previous single-accent policy. Windows
    # mode supplies an independent primary accent text shade.
    color = rgb(selection)
    link_color = rgb(link) if link is not None else color
    if color == defaults["accent"].upper():
        return {**defaults, "accent_link": link_color}
    ink = contrast_ink(color)
    return {**defaults, "accent": color, "accent_link": link_color, "highlight_text": ink,
            "button_accent_text": ink, "checked_backing": ink,
            "selected_item_text": ink if mode == "light" else defaults["selected_item_text"]}


def render_scheme(template, defaults, mode, selection=None, link=None):
    """Render KDE roles with optional independent fill and link shades."""
    values = (defaults.copy() if selection is None
              else accent_values(mode, defaults, selection, link))
    if defaults["button_active_text"].upper() == defaults["accent"].upper():
        values["button_active_text"] = values["accent"]
    channels = {}
    for role in defaults:
        color = values[role]
        if not COLOR.fullmatch(color):
            raise ValueError("Invalid RGB palette role: " + role)
        channels[role] = ",".join(str(int(color[i:i + 2], 16)) for i in (1, 3, 5))
    channels["scheme_id"] = "WindowsModern" + mode.capitalize()
    channels["scheme_name"] = "Windows Modern " + mode.capitalize()
    return Template(template).substitute(channels)


def patch(text, spec, values):
    lines = text.splitlines(keepends=True)
    if len(lines) != spec["lines"]:
        raise ValueError("Kvantum layout differs from installed accent bindings")
    seen = set()
    for index, role, prefix, suffix in spec["bindings"]:
        if index in seen or not 0 <= index < len(lines) or role not in ROLES:
            raise ValueError("Invalid Kvantum accent binding")
        seen.add(index)
        # Old manifests bound the exact GeneralColors link line to accent.
        # Interpret that binding without changing offsets or the manifest.
        if role == "accent" and prefix == "link.color=" and "accent_link" in values:
            role = "accent_link"
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


def plan_kvantum(directory, mode, selection, link=None):
    if any(p.is_symlink() for p in (directory, directory.parent)):
        raise ValueError("Refusing externally managed Kvantum directory")
    if not directory.is_dir():
        return {}
    manifest = owned_file(directory / "accent-bindings.json")
    entry = json.loads(manifest.read_text(encoding="utf-8"))[mode]
    values = accent_values(mode, entry["defaults"], selection, link)
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
    return pending


def restore_pending(pending, written):
    failures = []
    for path in reversed(written):
        old, new = pending[path]
        try:
            if owned_file(path).read_bytes() != new:
                raise ValueError(f"Theme changed during accent rollback: {path}")
            atomic_write(path, old)
        except (OSError, ValueError) as error:
            failures.append(str(error))
    if failures:
        raise ValueError("; ".join(failures))


def write_pending(pending):
    written = []
    try:
        for path, (old, new) in pending.items():
            if owned_file(path).read_bytes() != old:
                raise ValueError(f"Theme changed during accent synchronization: {path}")
            atomic_write(path, new)
            written.append(path)
    except (OSError, ValueError):
        restore_pending(pending, written)
        raise
    return written


def publish_kvantum_reload(directory):
    """Publish the complete local renderer pairs while holding the writer lock.

    A content-addressed receipt lets a live style reject intermediate or
    rolled-back SVG/config pairs. No new theme or service is installed.
    """
    if os.geteuid() == 0:
        raise ValueError("Publish the Kvantum reload receipt as the desktop user")
    if not directory.is_dir():
        return False
    if directory.is_symlink() or directory.parent.is_symlink():
        raise ValueError("Refusing externally managed Kvantum directory")
    if not (directory / "accent-bindings.json").is_file():
        return False
    owned_file(directory / "accent-bindings.json")
    files = {}
    for name in ("Windows-modern", "Windows-modernDark"):
        for suffix in (".kvconfig", ".svg"):
            filename = name + suffix
            path = owned_file(directory / filename)
            with path.open("rb") as stream:
                data = stream.read(8 * 1024 * 1024 + 1)
            if not data or len(data) > 8 * 1024 * 1024:
                raise ValueError("Invalid Kvantum reload asset length: " + filename)
            files[filename] = hashlib.sha256(data).hexdigest()
    payload = (json.dumps({"schema_version": 1, "files": files},
                          separators=(",", ":"), sort_keys=True) + "\n").encode("ascii")
    path = directory / "live-reload.json"
    if path.exists() or path.is_symlink():
        if owned_file(path).read_bytes() == payload:
            return False
        atomic_write(path, payload)
    else:
        with tempfile.NamedTemporaryFile(prefix=".wm-reload-", dir=directory) as temp:
            temp.write(payload)
            temp.flush()
            os.link(temp.name, path)
    return True


def synchronize(directory, mode, selection):
    if os.geteuid() == 0:
        raise ValueError("Run accent synchronization as the desktop user")
    return bool(write_pending(plan_kvantum(directory, mode, selection)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, nargs="?")
    parser.add_argument("mode", choices=("dark", "light"), nargs="?")
    parser.add_argument("selection", nargs="?")
    parser.add_argument("--analyze-wallpaper", metavar="IMAGE", type=Path, nargs="+",
                        help="read-only candidate palette from one or more explicit local images")
    parser.add_argument("--publish-kvantum-reload", type=Path, metavar="DIRECTORY",
                        help="publish committed local Kvantum asset hashes under the appearance lock")
    args = parser.parse_args()
    if args.publish_kvantum_reload is not None:
        if args.analyze_wallpaper is not None or any(value is not None for value in (
                args.directory, args.mode, args.selection)):
            parser.error("--publish-kvantum-reload is a separate operation")
        try:
            changed = publish_kvantum_reload(args.publish_kvantum_reload)
        except (OSError, ValueError) as error:
            parser.exit(1, f"Kvantum reload receipt: {error}\n")
        print("changed" if changed else "unchanged")
        return
    if args.analyze_wallpaper is not None:
        if any(value is not None for value in (args.directory, args.mode, args.selection)):
            parser.error("--analyze-wallpaper cannot be combined with Kvantum synchronization")
        try:
            result = analyze_wallpapers(args.analyze_wallpaper)
        except (OSError, ValueError, TypeError) as error:
            parser.exit(1, f"Wallpaper analysis: {error}\n")
        print(json.dumps(result, indent=2))
        return
    if any(value is None for value in (args.directory, args.mode, args.selection)):
        parser.error("directory, mode and selection are required for Kvantum synchronization")
    try:
        changed = synchronize(args.directory, args.mode, args.selection)
    except (OSError, ValueError, KeyError, TypeError, ET.ParseError) as error:
        parser.exit(1, f"Kvantum accent: {error}\n")
    print("changed" if changed else "unchanged")


if __name__ == "__main__":
    main()
