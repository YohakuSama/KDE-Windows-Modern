#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Import original Windows shell artwork into a private local data directory."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import tempfile
import xml.etree.ElementTree as ET

from PIL import Image
from fontTools.ttLib import TTFont, TTLibError
from fontTools.pens.svgPathPen import SVGPathPen

from native_pri_resources import embedded_resources

CORE = "SystemApps/MicrosoftWindows.Client.Core_cw5n1h2txyewy"
BATTERY_PATHS = (
    CORE + "/SystemTray/Assets/Sysbatt.ttf",
    "SystemResources/Windows.UI.ControlCenter/Assets/Sysbatt.ttf",
)
SEARCH_DIR = CORE + "/StartMenu/Assets/SearchIcons"
PRI_PATH = "SystemResources/Windows.UI.SettingsAppThreshold/Windows.UI.SettingsAppThreshold.pri"
TASKVIEW_NAMES = tuple("Files/SystemSettings/Assets/Taskview_" + theme.title() + ".svg"
                       for theme in ("light", "dark"))
CONTEXT_MENU_DIR = (
    "SystemApps/MicrosoftWindows.Client.FileExp_cw5n1h2txyewy/"
    "FileExplorerExtensions/Assets/images/contrast-standard"
)
CONTEXT_MENU_SVGS = (
    "View.svg",
    "SortBy.svg",
    "windows.refresh.svg",
    "windows.paste.svg",
    "windows.pasteshortcut.svg",
    "windows.undo.svg",
    "windows.redo.svg",
    "windows.newitem.svg",
    "newfolder.svg",
    "DisplaySettings.svg",
    "Personalize.svg",
    "expandtoclassic.svg",
    "windows.nextdesktopimage.svg",
    "windows.iconsize.large.svg",
    "windows.iconsize.medium.svg",
    "windows.iconsize.smallicon.svg",
    "windows.autoarrange.svg",
    "windows.aligngrid.svg",
    "windows.showdesktop.svg",
)
BATTERY_CODES = (set(range(0xf8d0, 0xf8ed)) | set(range(0xf849, 0xf852)))
MAX_FILE_BYTES = 128 * 1024 * 1024


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def local_file(root, relative):
    """Resolve Windows paths case-insensitively, without following external links."""
    path = root
    for part in Path(relative).parts:
        if part in ("..", ".") or Path(part).is_absolute():
            raise ValueError("Invalid resource path: " + relative)
        if not path.is_dir():
            return None
        matches = [child for child in path.iterdir() if child.name.casefold() == part.casefold()]
        if len(matches) > 1:
            raise ValueError("Ambiguous resource path: " + relative)
        if not matches:
            return None
        path = matches[0]
        if path.is_symlink() or not path.resolve().is_relative_to(root):
            raise ValueError("Resource escapes input directory: " + relative)
    return path


def read_original(root, path):
    if not path.is_file() or path.is_symlink() or not path.resolve().is_relative_to(root):
        raise ValueError("Invalid original resource: " + str(path))
    if path.stat().st_size > MAX_FILE_BYTES:
        raise ValueError("Oversized resource: " + str(path))
    return path.read_bytes()


def battery_artwork(data):
    """Export original outline and fill paths with one shared glyph canvas."""
    with TTFont(io.BytesIO(data)) as font:
        names = {n.toUnicode().strip().casefold() for n in font["name"].names
                 if n.nameID in (1, 16)}
        if "sysbatt fluent icons" not in names:
            raise ValueError("Not the SysBatt Fluent Icons font")
        cmap = font.getBestCmap() or {}
        missing = BATTERY_CODES - cmap.keys()
        if missing:
            raise ValueError("Missing SysBatt glyphs: " + ", ".join(f"U+{n:04X}" for n in sorted(missing)))
        glyphs = font.getGlyphSet()
        em = font["head"].unitsPerEm
        advance = font["hmtx"][cmap[0xf8d0]][0]
        ascent = font["hhea"].ascent
        if em <= 0 or advance <= 0 or abs(advance / em - 1.25) > 0.05:
            raise ValueError("Unexpected SysBatt glyph canvas")
        for code in sorted(BATTERY_CODES):
            pen = SVGPathPen(glyphs)
            glyphs[cmap[code]].draw(pen)
            path = pen.getCommands()
            if not path:
                raise ValueError(f"Empty SysBatt glyph U+{code:04X}")
            svg = (f'<svg xmlns="http://www.w3.org/2000/svg" '
                   f'viewBox="0 0 {advance} {em}" width="{advance}" height="{em}">'
                   f'<path fill="#ffffff" transform="translate(0 {ascent}) scale(1 -1)" '
                   f'd="{path}"/></svg>\n').encode()
            yield f"battery/{code:04x}.svg", svg, f"U+{code:04X}"


def search_artwork(root, folder, theme, state, required=True):
    prefix = "SearchIcon" + state.title() + theme.title()
    candidates = []
    for path in folder.iterdir():
        match = re.fullmatch(re.escape(prefix) + r"(?:\.scale-(\d+))?\.png", path.name, re.I)
        if match:
            scale = int(match.group(1) or 100)
            if scale in (100, 125, 150, 175, 200, 225, 250, 300, 400):
                candidates.append((scale, path))
    if not candidates:
        if required:
            raise ValueError("Missing original Search artwork: " + prefix)
        return None
    best = max(scale for scale, _ in candidates)
    paths = [path for scale, path in candidates if scale == best]
    if len(paths) != 1:
        raise ValueError("Ambiguous original Search artwork: " + prefix)
    path = paths[0]
    data = read_original(root, path)
    with Image.open(io.BytesIO(data)) as image:
        if image.format != "PNG" or not 0 < min(image.size) <= max(image.size) <= 1024:
            raise ValueError("Invalid Search PNG: " + str(path))
        image.verify()
    return path, data, best


def validate_svg(data):
    if not data or len(data) > 1024 * 1024 or b"<!doctype" in data.lower() or b"<!entity" in data.lower():
        raise ValueError("Invalid embedded Task View SVG")
    tree = ET.fromstring(data)
    if tree.tag != "{http://www.w3.org/2000/svg}svg":
        raise ValueError("Task View resource is not SVG")
    for element in tree.iter():
        tag = element.tag.rsplit("}", 1)[-1].casefold()
        if tag in ("script", "foreignobject", "image"):
            raise ValueError("Unexpected SVG element: " + tag)
        for key, value in element.attrib.items():
            name = key.rsplit("}", 1)[-1].casefold()
            if name.startswith("on") or (name == "href" and not value.startswith("#")):
                raise ValueError("External or executable Task View SVG content")
            for reference in re.findall(r"url\s*\(([^)]*)\)", value, re.I):
                if not reference.strip().strip("'\"").startswith("#"):
                    raise ValueError("External Task View SVG reference")
        if tag == "style":
            style = element.text or ""
            if "@import" in style.casefold() or any(
                    not reference.strip().strip("'\"").startswith("#")
                    for reference in re.findall(r"url\s*\(([^)]*)\)", style, re.I)):
                raise ValueError("External Task View SVG stylesheet")


def default_account_artwork(root):
    """Read only the optional system-wide default portrait, not user profiles."""
    directory = "ProgramData/Microsoft/User Account Pictures/"
    for name in ("user.png", "user.jpg", "user.bmp", "user-192.png",
                 "user-200.png", "user-48.png", "user-40.png", "user-32.png"):
        path = local_file(root, directory + name)
        if path is None:
            continue
        data = read_original(root, path)
        suffix = path.suffix.lower()
        expected = {".png": "PNG", ".jpg": "JPEG", ".bmp": "BMP"}[suffix]
        with Image.open(io.BytesIO(data)) as picture:
            if (picture.format != expected or picture.width != picture.height
                    or not 0 < picture.width <= 4096):
                raise ValueError("Invalid default Windows account picture: " + str(path))
            picture.verify()
        return path, data, suffix
    return None


def context_menu_artwork(root):
    """Export optional FileExplorerExtensions contrast-standard context-menu SVGs."""
    base = local_file(root, CONTEXT_MENU_DIR)
    if base is None or not base.is_dir():
        return
    for mode, folder_name in (("dark", "theme-dark"), ("light", "theme-light")):
        theme_dir = local_file(root, f"{CONTEXT_MENU_DIR}/{folder_name}")
        if theme_dir is None or not theme_dir.is_dir():
            continue
        for name in CONTEXT_MENU_SVGS:
            svg_path = local_file(root, f"{CONTEXT_MENU_DIR}/{folder_name}/{name}")
            if svg_path is None:
                continue
            svg_bytes = read_original(root, svg_path)
            validate_svg(svg_bytes)
            yield f"context-menu/{mode}/{name}", svg_bytes, svg_path, f"contrast-standard/{folder_name}"


def collect(source):
    root = source.resolve(strict=True)
    windows = local_file(root, "Windows")
    volume_root = None
    if windows is not None and windows.is_dir():
        volume_root = root
        root = windows
    elif root.name.casefold() == "windows":
        volume_root = root.parent
    if not root.is_dir():
        raise ValueError("Provide an extracted Windows directory")
    outputs = {}
    sources = {}

    def write(name, data, path, resource, original, source_root=None):
        relative = path.relative_to(source_root or root).as_posix()
        sources[relative] = sha256(original)
        outputs[name] = (data, {"source": relative, "resource": resource, "sha256": sha256(data)})

    font_path = next((path for relative in BATTERY_PATHS
                      if (path := local_file(root, relative)) is not None), None)
    if font_path is None:
        raise ValueError("Original Sysbatt.ttf not found in Windows")
    original_font = read_original(root, font_path)
    for name, svg, code in battery_artwork(original_font):
        write(name, svg, font_path, code, original_font)

    folder = local_file(root, SEARCH_DIR)
    if folder is None or not folder.is_dir():
        raise ValueError("Original SearchIcons directory not found in Windows")
    for theme in ("light", "dark"):
        for state in ("on", "off"):
            # The light pair and dark active image are required; the
            # original dark idle image is optional when absent from the build.
            required = theme == "light" or state == "on"
            result = search_artwork(root, folder, theme, state, required=required)
            if result is None:
                continue
            path, png, scale = result
            write(f"search/{theme}-{state}.png", png, path, f"scale-{scale}", png)

    pri_path = local_file(root, PRI_PATH)
    if pri_path is None:
        raise ValueError("Original Windows.UI.SettingsAppThreshold.pri not found")
    pri = read_original(root, pri_path)
    for theme, name, svg in zip(("light", "dark"), TASKVIEW_NAMES,
                               embedded_resources(pri, TASKVIEW_NAMES)):
        if svg is None:
            raise ValueError("Missing embedded Windows resource: " + name)
        validate_svg(svg)
        write(f"task-view/{theme}.svg", svg, pri_path, name, pri)

    if volume_root is not None:
        portrait = default_account_artwork(volume_root)
        if portrait is not None:
            path, data, suffix = portrait
            write("account/default" + suffix, data, path, "default-account-picture",
                  data, source_root=volume_root)

    for name, svg, svg_path, resource in context_menu_artwork(root):
        write(name, svg, svg_path, resource, svg)

    return outputs, sources


def install(source, destination, build):
    source = source.expanduser().resolve(strict=True)
    destination = destination.expanduser().resolve()
    if (destination == source or destination in source.parents or
            destination.is_relative_to(source)):
        raise ValueError("Keep shell artwork outside the original Windows directory")
    outputs, sources = collect(source)
    if destination.exists():
        try:
            old = json.loads((destination / "manifest.json").read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            raise ValueError("Refusing to replace an unrelated output directory") from exc
        if old.get("format") != "windows-modern-shell-assets-v1":
            raise ValueError("Refusing to replace an unrelated output directory")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".shell-assets-", dir=destination.parent) as temp:
        stage = Path(temp) / "new"
        stage.mkdir(mode=0o700)
        for relative, (data, _) in outputs.items():
            path = stage / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        manifest = {"format": "windows-modern-shell-assets-v1",
                    "declared_source_build": build, "sources": sources,
                    "outputs": {name: record for name, (_, record) in outputs.items()}}
        (stage / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        previous = Path(temp) / "previous"
        if destination.exists():
            destination.rename(previous)
        try:
            stage.rename(destination)
        except OSError:
            if previous.exists():
                previous.rename(destination)
            raise
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="extracted Windows directory or its parent")
    parser.add_argument("--build", required=True, help="actual build number of the source installation")
    parser.add_argument("--output", type=Path,
                        default=Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
                        / "windows-modern/shell-assets")
    args = parser.parse_args()
    if not re.fullmatch(r"\d+(?:\.\d+){0,3}", args.build):
        parser.error("--build must be a numeric Windows build number")
    try:
        manifest = install(args.source, args.output, args.build)
    except (OSError, ValueError, TTLibError, ET.ParseError) as exc:
        parser.exit(1, f"Shell artwork import failed: {exc}\n")
    print(f"Imported {len(manifest['outputs'])} original shell artwork files from build {args.build}.")
