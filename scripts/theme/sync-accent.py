#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Synchronize template-owned Kvantum accent paints, not window materials."""
import argparse
import colorsys
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


# Candidate for the central custom-color branch, not the preset lookup
# or the wallpaper extractor. Mathematical description:
# https://gist.github.com/cnbluefire/7ffa04c493c57b8a67f6a8baa2c726f7
# Use standard sRGB/D65 CIELAB conversions and Python's HLS routines.
# Keep the original input distinct from the normalized output Accent.
def derive_custom_lab_palette(selection):
    source = tuple(bytes.fromhex(rgb(selection)[1:]))
    hue, lightness, saturation = colorsys.rgb_to_hls(*(x / 255 for x in source))
    if not 0.25 <= lightness <= 0.75 or saturation < 0.15:
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
