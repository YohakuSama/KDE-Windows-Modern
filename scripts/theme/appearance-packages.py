#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Materialize one Windows Modern theme and its renderer compatibility outputs.

The historical dark source directory is the shared base, not a second
editable theme. Both Plasma renderer packages are materialized from it.
Installed KPackages and Store archives receive real files, never source symlinks.
"""
import argparse
import json
from pathlib import Path
import re
import runpy
import shutil
import subprocess
import sys
from string import Template
import xml.etree.ElementTree as ET

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
    "configuration-icons": {b"#2C2C2C": b"#eff0f1"},
    "line": {b"#2C2C2C": b"#eff0f1"},
    "plasmoidheading": {b"#2C2C2C": b"#eff0f1"},
    "solid/widgets/panel-background": {},
    "switch": {},
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
    "configuration-icons": (LIGHT_GRADIENT_ROLES, LIGHT_GRADIENT_STOPS),
    "line": (LIGHT_PLAIN_ROLES, {}),
    "solid/widgets/panel-background": (LIGHT_GRADIENT_ROLES, LIGHT_GRADIENT_STOPS),
    "switch": ({b"Text": b"#232629", b"Background": b"#eff0f1",
                b"Highlight": b"#5e81ac"}, {}),
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
    "solid/widgets/panel-background": (
        (b"color:#1C1C1C", b"color:#eff0f1", 4),
        (b"fill:#1C1C1C", b"fill:#F3F3F3", 3),
    ),
    "switch": (
        (b'opacity="0.55"', b'opacity="0.45"', 3),
        (b'opacity="0.79"', b'opacity="0.62"', 1),
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


def apply_light_widget_colors(target):
    for name, colors in LIGHT_WIDGET_COLORS.items():
        relative = Path(name + ".svg") if "/" in name else Path("widgets") / (name + ".svg")
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


# Only reviewed accent-painted widget elements. Brand artwork and neutral
# state fills are intentionally excluded. The light conversion runs first
# so both generated modes have the same native palette-role bindings.
NATIVE_ACCENT_FILLS = {
    "action-overlays": 3, "actionbutton": 2, "analog_meter": 1,
    "clock": 4, "containment-controls": 12, "glowbar": 1,
    "notes": 1, "pager": 18, "bar_meter_horizontal": 9,
    "bar_meter_vertical": 9, "busywidget": 3, "button": 30,
    "calendar": 1, "checkmarks": 3, "radiobutton": 4,
    "tabbar": 10, "lineedit": 3, "tasks": 2,
    "slider": 0, "switch": 0,
}
# All stops in these four accent paint servers share the native Highlight
# role. The analog meter and containment editor are KDE-only controls;
# their legacy teal companion paints have been retired, not replaced with
# guessed Windows accent shades. Keep the paint-server IDs and geometry.
NATIVE_ACCENT_GRADIENTS = {
    "analog_meter": {"linearGradient3857": 2},
    "containment-controls": {"linearGradient4303": 2, "linearGradient4291": 2},
    "glowbar": {"a": 3},
}
SCHEME_STYLESHEET = re.compile(
    rb'<style\b[^>]*\bid="current-color-scheme"[^>]*>[\s\S]*?</style>')
SVG_SHAPE = re.compile(rb'<(?:path|rect|circle|ellipse|g|polygon|polyline|line)\b[^>]*>')
CLASS_ATTRIBUTE = re.compile(rb'\bclass="([^"]*)"')
STYLE_ATTRIBUTE = re.compile(rb'\bstyle="([^"]*)"')
INLINE_COLOR = re.compile(rb'(?<![\w-])color\s*:\s*#[0-9a-fA-F]{6}\s*;?')


def native_accent_widget(data, accent, expected, fallback=None):
    """Replace explicit reviewed accent fills, not arbitrary matching colors."""
    literal_fill = re.compile(
        rb'(?<![\w-])(fill\s*:\s*|fill=")' + re.escape(accent)
        + rb'(?=[;"\s])', re.IGNORECASE)
    count = 0

    def shape(match):
        nonlocal count
        tag, changed = literal_fill.subn(lambda m: m[1] + b'currentColor', match[0])
        if not changed:
            return tag
        if changed != 1:
            raise ValueError("Ambiguous accent paint in SVG shape")
        count += changed

        def classes(m):
            roles = [part for part in m[1].split()
                     if not part.startswith(b'ColorScheme-')]
            return b'class="' + b' '.join(roles + [b'ColorScheme-Highlight']) + b'"'

        tag, had_class = CLASS_ATTRIBUTE.subn(classes, tag)
        if not had_class:
            tag = re.sub(rb'^<[\w-]+', lambda m: m[0] + b' class="ColorScheme-Highlight"',
                         tag, count=1)
        # An inline color declaration would override KSVG's class color.
        tag = STYLE_ATTRIBUTE.sub(
            lambda m: b'style="' + INLINE_COLOR.sub(b'', m[1]) + b'"', tag)
        tag = re.sub(rb'\scolor="#[0-9a-fA-F]{6}"', b'', tag)
        return tag

    data = SVG_SHAPE.sub(shape, data)
    if count != expected:
        raise ValueError(f"Expected {expected} native accent fills, got {count}")

    fallback = fallback or accent
    rule = b'.ColorScheme-Highlight { color:' + fallback + b'; }'

    def stylesheet(match):
        found = False

        def update(role):
            nonlocal found
            if role[2] != b'Highlight':
                return role[0]
            found = True
            body, n = CSS_COLOR.subn(lambda m: m[1] + fallback, role[3])
            if n != 1:
                raise ValueError("Invalid highlight fallback declaration")
            return role[1] + body + role[4]

        result = SVG_COLOR_ROLE.sub(update, match[0])
        if not found:
            result = result.replace(b'</style>', b'\n' + rule + b'\n</style>')
        return result

    data, stylesheets = SCHEME_STYLESHEET.subn(stylesheet, data)
    if not stylesheets:
        style = b'<style id="current-color-scheme" type="text/css">' + rule + b'</style>'
        data, n = re.subn(rb'<defs(?:\s[^>]*)?>', lambda m: m[0] + style, data, count=1)
        if not n:
            data, n = re.subn(rb'<svg\b[^>]*>', lambda m: m[0] + b'<defs>' + style + b'</defs>',
                              data, count=1)
            if n != 1:
                raise ValueError("Missing SVG root")
    ET.fromstring(data)
    return data


def native_accent_gradients(data, accent, gradients):
    # Qt SVG resolves stop-color="currentColor" through its inherited
    # color stack. A class on <stop> alone is not enough: the stop parser
    # does not push the class's color. Scope the role on a normal SVG
    # group inside <defs>, without changing paint-server IDs or links.
    stop_color = re.compile(
        rb'(?<![\w-])(stop-color\s*:\s*|stop-color=")' + re.escape(accent)
        + rb'(?=[;"\s])', re.IGNORECASE)
    for gradient, expected in gradients.items():
        identifier = re.escape(gradient.encode("ascii"))
        pattern = re.compile(rb'<linearGradient\b(?=[^>]*\bid="' + identifier
                             + rb'")[^>]*>[\s\S]*?</linearGradient>')

        def bind(match):
            paint, count = stop_color.subn(lambda m: m[1] + b'currentColor', match[0])
            if count != expected:
                raise ValueError(f"Unexpected accent stops in {gradient}: {count}")
            return b'<g class="ColorScheme-Highlight">' + paint + b'</g>'

        data, count = pattern.subn(bind, data)
        if count != 1:
            raise ValueError(f"Missing or duplicate gradient {gradient}")
    ET.fromstring(data)
    return data


def apply_native_accent_roles(root, target, mode):
    accent = load_palette(root, mode)["accent"].encode("ascii")
    # Existing source accent literals are fixed inputs, not the runtime choice.
    source_accent = b"#4CC2FF" if mode == "dark" else b"#0067C0"
    for name, count in NATIVE_ACCENT_FILLS.items():
        path = target / "widgets" / (name + ".svg")
        data = native_accent_widget(path.read_bytes(), source_accent, count, accent)
        if name in NATIVE_ACCENT_GRADIENTS:
            data = native_accent_gradients(data, source_accent, NATIVE_ACCENT_GRADIENTS[name])
        path.write_bytes(data)


def desktoptheme(root, destination, mode):
    source = root / "plasma/desktoptheme"
    target = destination / ("Windows-modern-" + mode)
    shutil.copytree(source / "Windows-modern-dark", target)
    if mode == "light":
        # Never read an old light source directory, even if an incremental
        # checkout left one on disk. Generate only from the shared source.
        apply_light_widget_colors(target)
        metadata = target / "metadata.desktop"
        data = metadata.read_bytes()
        metadata.write_bytes(data.replace(b"Windows-modern-dark", b"Windows-modern-light")
                             .replace(b"Windows Modern Dark desktop theme",
                                      b"Windows Modern Light desktop theme"))
        generators = root / "scripts/theme"
        # Use the existing material generators, including their validation
        # of the frame IDs and masks. Do not duplicate their geometry.
        for name in ("popup-frames.py", "panel-frames.py"):
            write_frames = runpy.run_path(str(generators / name))["write_frames"]
            write_frames(target, mode)
    apply_native_accent_roles(root, target, mode)
    return target


def aurorae(root, destination, mode):
    shared = root / "aurorae/windows-modern-dark-aurorae"
    target = destination / f"windows-modern-{mode}-aurorae"
    shutil.copytree(shared, target)
    if mode == "dark":
        return target

    # The caption geometry and all states share one source. Keep the
    # close-button warning colors and state opacities unchanged. The
    # maximize button also shares the same crisp-edge hint in both modes.
    for name in ("alldesktops", "close", "excludefromcapture", "help",
                 "keepabove", "keepbelow", "maximize", "minimize", "restore", "shade"):
        # Some KDE-specific buttons keep their original background
        # literal in both modes. Only the four native caption controls
        # use the mode-specific background substitution.
        colors = {b"#ffffff": b"#1E1E1E"}
        if name in ("close", "maximize", "minimize", "restore"):
            colors[b"#202020"] = b"#F9F9F9"
        path = target / (name + ".svg")
        data = path.read_bytes()
        if b"#ffffff" not in data:
            raise ValueError(f"Missing shared caption foreground: {path}")
        path.write_bytes(SVG_HEX_COLOR.sub(lambda match: colors.get(match[0], match[0]), data))

    # Reuse the window material generator rather than substituting the
    # border, shadow or active/inactive frame colors heuristically.
    render = runpy.run_path(str(root / "scripts/theme/window-frames.py"))["render"]
    (target / "decoration.svg").write_text(render(mode), encoding="utf-8")
    for name in ("metadata.desktop", "metadata.json"):
        path = target / name
        data = path.read_bytes()
        path.write_bytes(data.replace(b"Windows Modern Dark", b"Windows Modern Light")
                         .replace(b"windows-modern-dark-aurorae", b"windows-modern-light-aurorae"))

    rc = target / "windows-modern-dark-auroraerc"
    data = rc.read_bytes()
    for dark, light in (
        (b"ActiveTextColor=255,255,255,255", b"ActiveTextColor=30,30,30,255"),
        (b"InactiveTextColor=255,255,255,128", b"InactiveTextColor=30,30,30,128"),
    ):
        if data.count(dark) != 1:
            raise ValueError(f"Unexpected shared caption text color: {rc}")
        data = data.replace(dark, light)
    rc.unlink()
    (target / "windows-modern-light-auroraerc").write_bytes(data)
    return target


def light_lookfeel_dependencies(root, dependencies):
    # Store product IDs are an external compatibility contract, not a
    # second global theme source. Only mode-specific IDs are overridden.
    overrides = json.loads((root / "scripts/theme/light-store-dependencies.json").read_text(encoding="utf-8"))
    if not overrides.keys() <= set(dependencies):
        raise ValueError("Light Store dependency overrides do not match the shared metadata")
    return [overrides.get(dep, dep) for dep in dependencies]


def lookfeel(root, destination, mode):
    base = root / "plasma/look-and-feel" / PACKAGE
    if mode == "light":
        # Export the historical Store product from the common package.
        # Copy only the original Store payload, not login/boot resources.
        target = destination / LIGHT_PACKAGE
        contents = target / "contents"
        contents.mkdir(parents=True)
        for name in ("layouts", "splash"):
            shutil.copytree(base / "contents" / name, contents / name)
        defaults = (base / "contents/defaults").read_text(encoding="utf-8")
        for dark, light in (
            ("ColorScheme=WindowsModernDark", "ColorScheme=WindowsModernLight"),
            ("Theme=windows-modern\n", "Theme=windows-modern-light\n"),
            ("widgetStyle=kvantum-dark", "widgetStyle=kvantum"),
            ("windows-modern-dark-aurorae", "windows-modern-light-aurorae"),
            ("name=Windows-modern-dark", "name=Windows-modern-light"),
            ("Theme=" + PACKAGE, "Theme=" + LIGHT_PACKAGE),
        ):
            if defaults.count(dark) != 1:
                raise ValueError("Unexpected shared global defaults: " + dark)
            defaults = defaults.replace(dark, light)
        (contents / "defaults").write_text(defaults, encoding="utf-8")
        previews = contents / "previews"
        shutil.copytree(root / "scripts/store/lookfeel-light-previews", previews)
        shutil.copy2(previews / "preview.png", previews / "splash.png")
        meta = json.loads((base / "metadata.json").read_text(encoding="utf-8"))
        plugin = meta["KPlugin"]
        plugin["Id"] = LIGHT_PACKAGE
        plugin["Name"] = "Windows Modern Light"
        plugin["Description"] = plugin["Description"].replace("Windows Modern Dark", "Windows Modern Light", 1)
        meta["X-KPackage-Dependencies"] = light_lookfeel_dependencies(
            root, meta.get("X-KPackage-Dependencies", []))
        (target / "metadata.json").write_text(json.dumps(meta, ensure_ascii=False, indent=4) + "\n", encoding="utf-8")
        desktop = (base / "metadata.desktop").read_text(encoding="utf-8")
        (target / "metadata.desktop").write_text(
            desktop.replace("Windows-modern-dark", "Windows-modern-light")
                   .replace("Windows Modern Dark theme", "Windows Modern Light theme")
                   .replace(PACKAGE, LIGHT_PACKAGE), encoding="utf-8")
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
        deps = meta.get("X-KPackage-Dependencies", [])
        meta["X-KPackage-Dependencies"] = list(dict.fromkeys(
            deps + light_lookfeel_dependencies(root, deps)))
        meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=4) + "\n", encoding="utf-8")
        desktop = target / "metadata.desktop"
        desktop.write_text(desktop.read_text(encoding="utf-8")
                           .replace("Name=Windows-modern-dark\n", "Name=Windows Modern\n", 1)
                           .replace("Windows Modern Dark theme for KDE Plasma 6.",
                                    "Windows Modern for KDE Plasma 6, with light and dark appearance modes.", 1),
                           encoding="utf-8")
        scripts = target / "contents/scripts"
        scripts.mkdir()
        for name in ("switch-mode.sh", "sync-accent.py", "accent-control.py", "wallpaper-icc.py",
                     "window-frames.py", "palette.json"):
            shutil.copy2(root / "scripts/theme" / name, scripts / name)
        shutil.copy2(root / "color-schemes/WindowsModern.colors.in", scripts)
    return target


# KDE and Kvantum share fixed palette roles where their semantics agree.
# Keep renderer-specific surface and state roles distinct, even if their
# current values happen to be identical.
def load_palette(root, mode):
    """Read the common fixed-color roles; do not modify the user's accent."""
    palette = json.loads((root / "scripts/theme/palette.json").read_text(encoding="utf-8"))
    return palette[mode]


def render_color_scheme(root, mode):
    source = root / "color-schemes/WindowsModern.colors.in"
    render = runpy.run_path(str(root / "scripts/theme/sync-accent.py"))["render_scheme"]
    return render(source.read_text(encoding="utf-8"), load_palette(root, mode), mode)


def color_schemes(root, destination):
    destination.mkdir(parents=True, exist_ok=True)
    for mode in ("dark", "light"):
        name = "WindowsModern" + mode.capitalize() + ".colors"
        (destination / name).write_text(render_color_scheme(root, mode), encoding="utf-8")


def render_kvantum_config(root, mode):
    source = root / "Kvantum/Windows-modern/Windows-modern.kvconfig.in"
    return Template(source.read_text(encoding="utf-8")).substitute(load_palette(root, mode))


# The common SVG contains only geometry and mode-independent paint.
# These roles retain the previously reviewed mode-specific fills and state
# opacities, including transparent light indicator cutouts and the opaque
# dark glyph backing. Shared config roles (accent, text, window, button
# and disabled text) come from palette.json.
KVANTUM_SVG_PAINT = {
    "dark": {
        "control_surface": "#2C2C2C",
        "contrast_ink": "#FFFFFF",
        "splitter_ink": "#5A5A5A",
        "splitter_focus_ink": "#3F3F3F",
        "slider_track": "#6E6E6E",
        "muted_surface": "#3F3F3F",
        "header_hover_surface": "#2C2C2C",
        "glyph_ink": "#FFFFFF",
        "popup_surface": "#2C2C2C",
        "dock_focus_surface": "#3F3F3F",
        "frame_border": "#FFFFFF",
        "indicator_hover_surface": "#FFFFFF",
        "popup_border": "#454545",
        "dock_border": "#FFFFFF",
        "checked_backing": "#FFFFFF",
        "slider_outline": "none",
        "dial_major_opacity": ".8",
        "dial_minor_opacity": ".35",
        "frame_border_opacity": ".15",
        "dock_border_opacity": ".15",
        "selection_press_opacity": ".32",
        "selection_toggle_opacity": ".24",
        "selection_focus_opacity": ".1",
    },
    "light": {
        "control_surface": "#FFFFFF",
        "contrast_ink": "#000000",
        "splitter_ink": "#1E1E1E",
        "splitter_focus_ink": "#1E1E1E",
        "slider_track": "#8B8B8B",
        "muted_surface": "#E5E5E5",
        "header_hover_surface": "#E9E9E9",
        "glyph_ink": "#444444",
        "popup_surface": "#F9F9F9",
        "dock_focus_surface": "#FFFFFF",
        "frame_border": "#E5E5E5",
        "indicator_hover_surface": "#F9F9F9",
        "popup_border": "#DADADA",
        "dock_border": "#A0A0A0",
        "checked_backing": "none",
        "slider_outline": "#D5D5D5",
        "dial_major_opacity": "1",
        "dial_minor_opacity": "1",
        "frame_border_opacity": "1",
        "dock_border_opacity": "1",
        "selection_press_opacity": "1",
        "selection_toggle_opacity": ".9",
        "selection_focus_opacity": ".07",
    },
}


def render_kvantum_svg(root, mode):
    source = root / "Kvantum/Windows-modern/Windows-modern.svg.in"
    values = {**load_palette(root, mode), **KVANTUM_SVG_PAINT[mode]}
    svg = Template(source.read_text(encoding="utf-8")).substitute(values)
    # Preserve the atlas markup and attribute order for window-frames.py.
    # Parsing here rejects broken generated SVG before installation.
    ET.fromstring(svg)
    return svg


def kvantum(root, destination):
    target = destination / "Windows-modern"
    target.mkdir(parents=True)
    binding_builder = runpy.run_path(str(root / "scripts/theme/sync-accent.py"))["make_bindings"]
    source = root / "Kvantum/Windows-modern"
    manifest = {}
    for mode, name in (("light", "Windows-modern"), ("dark", "Windows-modernDark")):
        values = {**load_palette(root, mode), **KVANTUM_SVG_PAINT[mode]}
        files = {}
        for extension, render in ((".kvconfig", render_kvantum_config),
                                  (".svg", render_kvantum_svg)):
            filename = name + extension
            template = (source / ("Windows-modern" + extension + ".in")).read_text(encoding="utf-8")
            data = render(root, mode)
            (target / filename).write_text(data, encoding="utf-8")
            files[filename] = binding_builder(template, data, values)
        manifest[mode] = {"defaults": {role: values[role] for role in
                          ("accent", "accent_link", "highlight_text", "selected_item_text",
                           "checked_backing", "button_accent_text")},
                          "files": files}
    (target / "accent-bindings.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return target


def materialize(root, output, component="runtime"):
    output = output.resolve()
    if any(output.is_relative_to((root / source).resolve()) for source in
           ("plasma/desktoptheme", "plasma/look-and-feel", "aurorae", "Kvantum", "color-schemes")):
        raise ValueError("Stage appearance packages outside their source directories")
    output.mkdir(parents=True, exist_ok=True)
    if component in ("runtime", "themes"):
        desktop = output / "desktoptheme"
        decorations = output / "aurorae"
        desktop.mkdir()
        decorations.mkdir()
        for mode in ("dark", "light"):
            desktoptheme(root, desktop, mode)
            aurorae(root, decorations, mode)
        kvantum(root, output / "Kvantum")
        color_schemes(root, output / "color-schemes")
        if component == "runtime":
            global_theme = output / "look-and-feel"
            global_theme.mkdir()
            lookfeel(root, global_theme, "unified")
    elif component == "color-schemes":
        color_schemes(root, output)
    elif component == "desktopthemes":
        for mode in ("dark", "light"):
            desktoptheme(root, output, mode)
    elif component == "lookfeel":
        lookfeel(root, output, "unified")
    elif component.startswith("desktoptheme-"):
        desktoptheme(root, output, component.removeprefix("desktoptheme-"))
    elif component.startswith("aurorae-"):
        aurorae(root, output, component.removeprefix("aurorae-"))
    elif component.startswith("lookfeel-"):
        lookfeel(root, output, component.removeprefix("lookfeel-"))
    else:
        raise ValueError("Unknown appearance component: " + component)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--component", default="runtime",
                        choices=("runtime", "themes", "desktopthemes", "lookfeel", "color-schemes",
                                 "desktoptheme-dark", "desktoptheme-light",
                                 "aurorae-dark", "aurorae-light",
                                 "lookfeel-dark", "lookfeel-light"))
    args = parser.parse_args()
    if ((args.component == "runtime" or args.component.startswith("lookfeel"))
            and (ROOT / "core/source-map.json").is_file()):
        subprocess.run([sys.executable, "-I", str(ROOT / "scripts/materialize-modules.py"),
                        "--prepare"], check=True)
    materialize(ROOT, args.output, args.component)
