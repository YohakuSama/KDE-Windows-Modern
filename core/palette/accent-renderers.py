# SPDX-License-Identifier: GPL-3.0-or-later
"""Renderer role mapping, KDE color-scheme output, and Kvantum accent bindings.

This module maps accent selections onto shared KDE `.colors` templates and
optional user-local Kvantum `.kvconfig`/`.svg` bindings, and publishes the
content-addressed Kvantum `live-reload.json` receipt. It does not discover
wallpapers, read KDE session settings, or hold the outer writer lock.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
from string import Template
import sys
import tempfile
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

owned_file = _theme_files.owned_file
atomic_write = _theme_files.atomic_write
COLOR = _algorithms.COLOR
rgb = _algorithms.rgb
contrast_ink = _algorithms.contrast_ink

ROLES = ("accent", "accent_link", "highlight_text", "selected_item_text",
         "checked_backing", "button_accent_text")
ROLE = re.compile(r"\$\{(" + "|".join(ROLES) + r")\}")


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


def plan_kvantum(directory, mode, selection, link=None):
    if any(p.is_symlink() for p in (directory, directory.parent)):
        raise ValueError("Refusing externally managed Kvantum directory")
    if not directory.exists():
        return {}
    if not directory.is_dir():
        raise ValueError(f"Not a user-owned Kvantum directory: {directory}")
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


def publish_kvantum_reload(directory):
    """Publish the complete local renderer pairs while holding the writer lock.

    A content-addressed receipt lets a live style reject intermediate or
    rolled-back SVG/config pairs. No new theme or service is installed.
    """
    if os.geteuid() == 0:
        raise ValueError("Publish the Kvantum reload receipt as the desktop user")
    if directory.is_symlink() or directory.parent.is_symlink():
        raise ValueError("Refusing externally managed Kvantum directory")
    if not directory.is_dir():
        return False
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
