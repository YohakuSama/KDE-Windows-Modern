#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""CLI coordinator and compatibility facade for Windows Modern accent helpers.

Color/wallpaper algorithms live in `accent-algorithms.py`, scheme and Kvantum
renderer bindings/reload receipts live in `accent-renderers.py`, and user-owned
file transactions live in `theme-files.py`. Existing named exports and CLI
flags remain stable here for scripts, diagnostics and tests.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import sys
import xml.etree.ElementTree as ET


def _load_adjacent(module_name, filename, fallback_relative=None):
    here = Path(__file__).absolute().parent
    path = here / filename
    if not path.exists() and fallback_relative is not None:
        path = (here.parent / fallback_relative).absolute()
    key = f"{module_name}:{path.as_posix()}"
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


_theme_files = _load_adjacent(
    "windows_modern_theme_files", "theme-files.py", "transactions/theme-files.py")
_algorithms = _load_adjacent("windows_modern_accent_algorithms", "accent-algorithms.py")
_renderers = _load_adjacent("windows_modern_accent_renderers", "accent-renderers.py")

# Transaction interfaces (core/transactions/theme-files.py)
owned_file = _theme_files.owned_file
atomic_write = _theme_files.atomic_write
restore_pending = _theme_files.restore_pending
write_pending = _theme_files.write_pending

# Color and wallpaper analysis interfaces (core/palette/accent-algorithms.py)
COLOR = _algorithms.COLOR
PRESET_SHADE_ROLES = _algorithms.PRESET_SHADE_ROLES
PRESET_SWATCH_GRID = _algorithms.PRESET_SWATCH_GRID
PRESET_SWATCH_ORDER = _algorithms.PRESET_SWATCH_ORDER
PRESET_SHADES = _algorithms.PRESET_SHADES
rgb = _algorithms.rgb
custom_hsl_coordinates = _algorithms.custom_hsl_coordinates
CUSTOM_LAB_MIN_SATURATION = _algorithms.CUSTOM_LAB_MIN_SATURATION
uses_custom_lab = _algorithms.uses_custom_lab
_mix_lab_shade = _algorithms._mix_lab_shade
derive_custom_lab_palette = _algorithms.derive_custom_lab_palette
derive_custom_palette = _algorithms.derive_custom_palette
derive_manual_palette = _algorithms.derive_manual_palette
compare_manual_palette_reports = _algorithms.compare_manual_palette_reports
derive_wallpaper_alpha = _algorithms.derive_wallpaper_alpha
WALLPAPER_ANALYSIS_LIMIT = _algorithms.WALLPAPER_ANALYSIS_LIMIT
_prepare_wallpaper_bitmap = _algorithms._prepare_wallpaper_bitmap
prepare_opaque_wallpaper_bitmap = _algorithms.prepare_opaque_wallpaper_bitmap
prepare_premultiplied_wallpaper_bitmap = _algorithms.prepare_premultiplied_wallpaper_bitmap
WALLPAPER_DECODE_PIXEL_LIMIT = _algorithms.WALLPAPER_DECODE_PIXEL_LIMIT
WALLPAPER_IMAGE_FORMATS = _algorithms.WALLPAPER_IMAGE_FORMATS
WALLPAPER_ANALYSIS_REVISION = _algorithms.WALLPAPER_ANALYSIS_REVISION
_native_icc_module = _algorithms._native_icc_module
icc_reference_identity = _algorithms.icc_reference_identity
WallpaperFileChangedError = _algorithms.WallpaperFileChangedError
wallpaper_file_identity = _algorithms.wallpaper_file_identity
decode_wallpaper_bitmap = _algorithms.decode_wallpaper_bitmap
derive_weighted_wallpaper_seed = _algorithms.derive_weighted_wallpaper_seed
derive_weighted_wallpaper_bitmaps = _algorithms.derive_weighted_wallpaper_bitmaps
normalize_weighted_wallpaper_seed = _algorithms.normalize_weighted_wallpaper_seed
derive_automatic_palette = _algorithms.derive_automatic_palette
analyze_wallpapers = _algorithms.analyze_wallpapers
contrast_ink = _algorithms.contrast_ink

# Renderer binding and reload receipt interfaces (core/palette/accent-renderers.py)
ROLES = _renderers.ROLES
ROLE = _renderers.ROLE
make_bindings = _renderers.make_bindings
accent_values = _renderers.accent_values
render_scheme = _renderers.render_scheme
patch = _renderers.patch
plan_kvantum = _renderers.plan_kvantum
publish_kvantum_reload = _renderers.publish_kvantum_reload


def synchronize(directory, mode, selection):
    if os.geteuid() == 0:
        raise ValueError("Run accent synchronization as the desktop user")
    return bool(write_pending(plan_kvantum(directory, mode, selection)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, nargs="?")
    parser.add_argument("mode", choices=("dark", "light"), nargs="?")
    parser.add_argument("selection", nargs="?")
    operation = parser.add_mutually_exclusive_group()
    operation.add_argument("--analyze-wallpaper", metavar="IMAGE", type=Path, nargs="+",
                           help="read-only candidate palette from one or more explicit local images")
    operation.add_argument("--compare-manual-palette", metavar="REPORT", type=Path, nargs="+",
                           help="compare target-build manual palette batch reports without writing settings")
    operation.add_argument("--publish-kvantum-reload", type=Path, metavar="DIRECTORY",
                           help="publish committed local Kvantum asset hashes under the appearance lock")
    args = parser.parse_args()
    if args.compare_manual_palette is not None:
        if any(value is not None for value in (args.directory, args.mode, args.selection)):
            parser.error("--compare-manual-palette is a separate operation")
        try:
            result = compare_manual_palette_reports(args.compare_manual_palette)
        except (OSError, ValueError, TypeError, KeyError, AttributeError) as error:
            parser.exit(1, f"Manual palette comparison: {error}\n")
        print(json.dumps(result, indent=2))
        return
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
