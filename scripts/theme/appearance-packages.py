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


# These existing light variants share their SVG geometry. Keep their
# original element IDs, palette and mode-specific paint/opacity exactly
# as before. This is packaging-time appearance separation, not a new
# Windows brush or dynamic-accent mapping.
LIGHT_ACCENT = {b"#4CC2FF": b"#0067C0"}
LIGHT_WIDGET_COLORS = {
    **{name: LIGHT_ACCENT for name in (
        "action-overlays", "actionbutton", "analog_meter", "clock",
        "containment-controls", "glowbar", "notes", "pager",
        "bar_meter_horizontal", "bar_meter_vertical", "busywidget", "button",
        "calendar", "checkmarks",
    )},
    "background": {b"#2C2C2C": b"#F9F9F9", b"#3F3F3F": b"#E5E5E5"},
    "branding": {b"#FFFFFF": b"#eceff4", **LIGHT_ACCENT},
    "menubaritem": {
        b"#3D3D3D": b"#eff0f1", b"#2C2C2C": b"#eff0f1",
        b"#4A4A4A": b"#93cee9", b"#60CDFF": b"#3daee9",
    },
    "radiobutton": {b"#2C2C2C": b"#eff0f1", **LIGHT_ACCENT},
    "timer": {b"#3D3D3D": b"#dcdcdc"},
    "arrows": {},
    "scrollbar": {},
    "tabbar": {b"#2C2C2C": b"#eff0f1", **LIGHT_ACCENT},
    "margins-highlight": {b"#2C2C2C": b"#eff0f1"},
    "toolbar": {b"#3D3D3D": b"#fcfcfc"},
    "viewitem": {},
    "frame": {},
    "lineedit": LIGHT_ACCENT,
    "listitem": {b"#3D3D3D": b"#fcfcfc"},
    "tasks": {b"#3D3D3D": b"#e5e5e5", b"#FFFFFF": b"#000000", **LIGHT_ACCENT},
    "translucentbackground": {b"#2C2C2C": b"#F9F9F9", b"#3F3F3F": b"#E5E5E5"},
    "solid/widgets/background": {},
    "translucent/widgets/background": {b"#2C2C2C": b"#eff0f1"},
}
SVG_HEX_COLOR = re.compile(rb"#[0-9a-fA-F]{6}(?![0-9a-fA-F])")


# Preserve the original per-role fallback styles. The same dark literal
# can represent different light roles, so these are CSS role mappings,
# not global hex replacements or newly decoded Windows brush values.
LIGHT_PLAIN_ROLES = {
    b"Text": b"#31363b", b"Background": b"#eff0f1",
    b"ViewText": b"#31363b", b"ViewBackground": b"#fcfcfc",
    b"ViewHover": b"#3daee9", b"ViewFocus": b"#3daee9",
    b"ButtonText": b"#31363b", b"ButtonBackground": b"#eff0f1",
    b"ButtonHover": b"#3daee9", b"ButtonFocus": b"#3daee9",
}
LIGHT_GRADIENT_ROLES = {
    **LIGHT_PLAIN_ROLES, b"Highlight": b"#3daee9",
    b"ViewHover": b"#93cee9", b"ButtonHover": b"#93cee9",
}
LIGHT_GRADIENT_STOPS = {
    b"Background": b"#eff0f1", b"ViewBackground": b"#fcfcfc",
    b"ButtonBackground": b"#eff0f1",
}
LIGHT_MARGIN_ROLES = {
    b"Text": b"#7B7C7E", b"Background": b"#EFF0F1",
    b"Highlight": b"#3DAEE6",
    b"ViewText": b"#7B7C7E", b"ViewBackground": b"#FCFCFC",
    b"ViewHover": b"#3DAEE6", b"ViewFocus": b"#1E92FF",
    b"ButtonText": b"#7B7C7E", b"ButtonBackground": b"#EFF0F1",
    b"ButtonHover": b"#3DAEE6", b"ButtonFocus": b"#1E92FF",
}
LIGHT_VIEW_ROLES = {
    **LIGHT_MARGIN_ROLES, b"Text": b"#242424", b"Background": b"#fefefe",
    b"ViewText": b"#777777", b"ButtonBackground": b"#fefefe",
    b"ButtonFocus": b"#3DAEE6",
}
LIGHT_EDIT_ROLES = {
    **LIGHT_PLAIN_ROLES, b"Text": b"#333333", b"Background": b"#ffffff",
    b"ViewText": b"#333333", b"ViewHover": b"#888888", b"ViewFocus": b"#3476CF",
    b"ButtonText": b"#333333", b"ButtonBackground": b"#ffffff",
    b"ButtonHover": b"#888888", b"ButtonFocus": b"#3476CF",
}
LIGHT_TASK_ROLES = {
    **LIGHT_GRADIENT_ROLES, b"Text": b"#333333", b"ViewText": b"#333333",
    b"ButtonText": b"#333333",
}
LIGHT_SURFACE_ROLES = {
    b"Text": b"#1E1E1E", b"Background": b"#F9F9F9", b"Highlight": b"#0078D4",
    b"ViewText": b"#1E1E1E", b"ViewBackground": b"#FFFFFF",
    b"ViewHover": b"#E9E9E9", b"ViewFocus": b"#0078D4",
    b"ButtonText": b"#1E1E1E", b"ButtonBackground": b"#F3F3F3",
    b"ButtonHover": b"#E9E9E9", b"ButtonFocus": b"#0078D4",
}
LIGHT_TRANSLUCENT_ROLES = {
    **LIGHT_SURFACE_ROLES, b"Highlight": b"#0067C0",
    b"ViewFocus": b"#0067C0", b"ButtonFocus": b"#0067C0",
}
LIGHT_WIDGET_ROLES = {
    **{name: (LIGHT_GRADIENT_ROLES, LIGHT_GRADIENT_STOPS) for name in (
        "bar_meter_horizontal", "bar_meter_vertical", "busywidget", "button",
        "calendar", "checkmarks", "scrollbar", "toolbar",
    )},
    "arrows": (LIGHT_PLAIN_ROLES, {}),
    "tabbar": (LIGHT_PLAIN_ROLES, {}),
    "margins-highlight": (LIGHT_MARGIN_ROLES, {}),
    "viewitem": (LIGHT_VIEW_ROLES, {}),
    "frame": (LIGHT_GRADIENT_ROLES, LIGHT_GRADIENT_STOPS),
    "lineedit": (LIGHT_EDIT_ROLES, {}),
    "listitem": (LIGHT_PLAIN_ROLES, {}),
    "tasks": (LIGHT_TASK_ROLES, {}),
    "translucentbackground": (LIGHT_TRANSLUCENT_ROLES, LIGHT_TRANSLUCENT_ROLES),
    "solid/widgets/background": (LIGHT_SURFACE_ROLES, LIGHT_GRADIENT_STOPS),
    # The original translucent background contains two identical role tables.
    "translucent/widgets/background": (LIGHT_SURFACE_ROLES, {}, 2),
}
# Preserve non-geometric paint differences without modifying XML structure.
# Require the reviewed number of occurrences so new states cannot silently
# inherit an unrelated opacity or fill change.
LIGHT_WIDGET_PAINT = {
    "frame": ((b"fill:#2C2C2C;", b"fill:currentColor;", 2),),
    "lineedit": ((b'opacity:0.04"', b'opacity:0.03"', 2),),
    "listitem": ((b'fill:#2C2C2C"', b'fill:currentColor"', 1),),
    "tasks": ((b'fill-opacity="0.06"', b'fill-opacity="0.035"', 1),),
    "translucentbackground": ((b"(translucent dark)", b"(translucent light)", 1),),
    "solid/widgets/background": (
        (b'fill="#2C2C2C"', b'fill="#F3F3F3"', 16),
        (b'color="#2C2C2C"', b'color="#eff0f1"', 2),
    ),
}
SVG_COLOR_ROLE = re.compile(rb"(\.ColorScheme-([A-Za-z]+)\s*\{)([^{}]*)(\})")
CSS_COLOR = re.compile(rb"((?<![\w-])color\s*:\s*)#[0-9a-fA-F]{6}(?![0-9a-fA-F])")
CSS_STOP_COLOR = re.compile(rb"((?<![\w-])stop-color\s*:\s*)#[0-9a-fA-F]{6}(?![0-9a-fA-F])")


def apply_light_roles(data, relative, roles, stops, copies=1):
    seen = {}

    def replace_declaration(body, pattern, color, role):
        result, count = pattern.subn(lambda match: match[1] + color, body)
        if count != 1:
            raise ValueError(f"Expected one {role.decode('ascii')} color in {relative}")
        return result

    def substitute(match):
        start, role, body, end = match.groups()
        if role not in roles:
            return match[0]
        seen[role] = seen.get(role, 0) + 1
        if seen[role] > copies:
            raise ValueError(f"Duplicate CSS role in {relative}: {role.decode('ascii')}")
        body = replace_declaration(body, CSS_COLOR, roles[role], role)
        if role in stops:
            body = replace_declaration(body, CSS_STOP_COLOR, stops[role], role)
        return start + body + end

    result = SVG_COLOR_ROLE.sub(substitute, data)
    missing = [role.decode("ascii") for role in roles if seen.get(role, 0) != copies]
    if missing:
        raise ValueError(f"Missing shared SVG CSS role in {relative}: {', '.join(sorted(missing))}")
    return result


def apply_light_widget_colors(target, overlay):
    for name, colors in LIGHT_WIDGET_COLORS.items():
        relative = Path(name + ".svg") if "/" in name else Path("widgets") / (name + ".svg")
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
        data = path.read_bytes()
        if name in LIGHT_WIDGET_ROLES:
            data = apply_light_roles(data, relative, *LIGHT_WIDGET_ROLES[name])
        result = SVG_HEX_COLOR.sub(substitute, data)
        if seen != colors.keys():
            missing = ", ".join(sorted(value.decode("ascii") for value in colors.keys() - seen))
            raise ValueError(f"Missing shared SVG color in {relative}: {missing}")
        for source, replacement, count in LIGHT_WIDGET_PAINT.get(name, ()):
            if result.count(source) != count:
                raise ValueError(f"Unexpected shared SVG paint count in {relative}: {source!r}")
            result = result.replace(source, replacement)
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
