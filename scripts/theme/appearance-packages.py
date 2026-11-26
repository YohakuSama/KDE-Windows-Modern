#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Materialize one Windows Modern theme and its renderer compatibility outputs.

The historical dark source directory is the shared base, not a second
editable theme. Light directories contain only differences. Installed
KPackages and Store archives receive real files, never source symlinks.
"""
import argparse
import json
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = "org.kde.windowsmodern.dark"
LIGHT_PACKAGE = "org.kde.windowsmodern.light"


# These existing light variants differ from the shared SVGs only in color
# literals. Keep their geometry, element IDs, opacity and fallback palette
# exactly as before. This is packaging-time color separation, not a new
# Windows brush or dynamic-accent mapping.
LIGHT_ACCENT = {b"#4CC2FF": b"#0067C0"}
LIGHT_WIDGET_COLORS = {
    **{name: LIGHT_ACCENT for name in (
        "action-overlays", "actionbutton", "analog_meter", "clock",
        "containment-controls", "glowbar", "notes", "pager",
    )},
    "background": {b"#2C2C2C": b"#F9F9F9", b"#3F3F3F": b"#E5E5E5"},
    "branding": {b"#FFFFFF": b"#eceff4", **LIGHT_ACCENT},
    "menubaritem": {
        b"#3D3D3D": b"#eff0f1", b"#2C2C2C": b"#eff0f1",
        b"#4A4A4A": b"#93cee9", b"#60CDFF": b"#3daee9",
    },
    "radiobutton": {b"#2C2C2C": b"#eff0f1", **LIGHT_ACCENT},
    "timer": {b"#3D3D3D": b"#dcdcdc"},
}
SVG_HEX_COLOR = re.compile(rb"#[0-9a-fA-F]{6}(?![0-9a-fA-F])")


def apply_light_widget_colors(target, overlay):
    for name, colors in LIGHT_WIDGET_COLORS.items():
        relative = Path("widgets") / (name + ".svg")
        if (overlay / relative).exists():
            raise ValueError(f"Duplicate light widget source: {relative}")
        path = target / relative
        seen = set()

        def substitute(match):
            value = match.group()
            if value in colors:
                seen.add(value)
            return colors.get(value, value)

        # Work on bytes and replace complete tokens in one pass. Do not
        # reserialize XML, change line endings or cascade color replacements.
        result = SVG_HEX_COLOR.sub(substitute, path.read_bytes())
        if seen != colors.keys():
            missing = ", ".join(sorted(value.decode("ascii") for value in colors.keys() - seen))
            raise ValueError(f"Missing shared SVG color in {relative}: {missing}")
        path.write_bytes(result)


def desktoptheme(root, destination, mode):
    source = root / "plasma/desktoptheme"
    target = destination / ("Windows-modern-" + mode)
    shutil.copytree(source / "Windows-modern-dark", target)
    if mode == "light":
        overlay = source / "Windows-modern-light"
        shutil.copytree(overlay, target, dirs_exist_ok=True)
        apply_light_widget_colors(target, overlay)
    return target


def lookfeel(root, destination, mode):
    source = root / "plasma/look-and-feel"
    base = source / PACKAGE
    overlay = source / LIGHT_PACKAGE
    if mode == "light":
        # Legacy Store product: share layout and splash, retain its metadata,
        # defaults, and previews. Do not add the unrelated boot greeter.
        target = destination / LIGHT_PACKAGE
        shutil.copytree(overlay, target)
        for name in ("layouts", "splash"):
            shutil.copytree(base / "contents" / name, target / "contents" / name)
        return target
    target = destination / PACKAGE
    shutil.copytree(base, target)
    if mode == "unified":
        # Keep the historic package id: existing greeter paths, saved
        # configurations and upgrades continue to work. Only one global
        # theme is installed by the full installer.
        meta_path = target / "metadata.json"
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        plugin = meta["KPlugin"]
        plugin["Name"] = "Windows Modern"
        plugin["Description"] = ("Windows Modern for KDE Plasma 6, with light and dark appearance modes. "
                                 "Based on Win11OS-kde by yeyushengfan258.")
        light = json.loads((overlay / "metadata.json").read_text(encoding="utf-8"))
        meta["X-KPackage-Dependencies"] = list(dict.fromkeys(
            meta.get("X-KPackage-Dependencies", []) + light.get("X-KPackage-Dependencies", [])))
        meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=4) + "\n", encoding="utf-8")
        desktop = target / "metadata.desktop"
        desktop.write_text(desktop.read_text(encoding="utf-8")
                           .replace("Name=Windows-modern-dark\n", "Name=Windows Modern\n", 1)
                           .replace("Windows Modern Dark theme for KDE Plasma 6.",
                                    "Windows Modern for KDE Plasma 6, with light and dark appearance modes.", 1),
                           encoding="utf-8")
        scripts = target / "contents/scripts"
        scripts.mkdir()
        shutil.copy2(root / "scripts/theme/switch-mode.sh", scripts / "switch-mode.sh")
    return target


def materialize(root, output, component="runtime"):
    output = output.resolve()
    if output.is_relative_to((root / "plasma/desktoptheme").resolve()) or \
            output.is_relative_to((root / "plasma/look-and-feel").resolve()):
        raise ValueError("Stage appearance packages outside their source directories")
    output.mkdir(parents=True, exist_ok=True)
    if component == "runtime":
        desktop = output / "desktoptheme"
        global_theme = output / "look-and-feel"
        desktop.mkdir()
        global_theme.mkdir()
        for mode in ("dark", "light"):
            desktoptheme(root, desktop, mode)
        lookfeel(root, global_theme, "unified")
    elif component == "desktopthemes":
        for mode in ("dark", "light"):
            desktoptheme(root, output, mode)
    elif component == "lookfeel":
        lookfeel(root, output, "unified")
    elif component.startswith("desktoptheme-"):
        desktoptheme(root, output, component.removeprefix("desktoptheme-"))
    elif component.startswith("lookfeel-"):
        lookfeel(root, output, component.removeprefix("lookfeel-"))
    else:
        raise ValueError("Unknown appearance component: " + component)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--component", default="runtime",
                        choices=("runtime", "desktopthemes", "lookfeel",
                                 "desktoptheme-dark", "desktoptheme-light",
                                 "lookfeel-dark", "lookfeel-light"))
    args = parser.parse_args()
    materialize(ROOT, args.output, args.component)
