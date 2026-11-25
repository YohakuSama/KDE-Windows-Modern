#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Import the owner's reviewed Commons Microsoft Store artwork, unchanged."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import tempfile
from urllib.parse import urlencode, urlparse
from urllib.request import Request, urlopen
import xml.etree.ElementTree as ET

# Filenames refer to the bag color, not the system mode.
SOURCES = {
    "light": ("Microsoft_Store_logo_dark.svg", "2025-09-15T18:19",
              "48395b228d8c6ea1f14b822983a8616ca8df1718"),
    "dark": ("Microsoft_Store_logo_light.svg", "2025-09-15T18:21", None),
}
ALIASES = ("discover", "org.kde.discover", "plasma-discover", "plasmadiscover", "muondiscover")
LIMIT = 1024 * 1024
INDEX = """[Icon Theme]
Name=Windows Modern Light
Comment=Light-mode Store artwork; all other icons inherit Windows Modern
Inherits=windows-modern
FollowsColorScheme=true
KDE-Extensions=.svg
Directories=apps

[apps]
Context=Applications
Type=Scalable
Size=48
MinSize=16
MaxSize=256
"""


def get(url):
    hosts = ("commons.wikimedia.org", "upload.wikimedia.org")
    if urlparse(url).scheme != "https" or urlparse(url).hostname not in hosts:
        raise ValueError("Unexpected artwork URL")
    with urlopen(Request(url, headers={"User-Agent": "KDE-Windows-Modern/1.0 (public artwork importer)"}), timeout=30) as response:
        if urlparse(response.geturl()).hostname not in hosts:
            raise ValueError("Unexpected artwork redirect")
        data = response.read(LIMIT + 1)
        if len(data) > LIMIT:
            raise ValueError("Unexpected artwork size")
        return data


def check_svg(data):
    if not data or len(data) > LIMIT or b"<!DOCTYPE" in data.upper() or b"<!ENTITY" in data.upper():
        raise ValueError("Invalid SVG data")
    root = ET.fromstring(data)
    if root.tag != "{http://www.w3.org/2000/svg}svg":
        raise ValueError("Not an SVG file")
    for node in root.iter():
        tag = node.tag.rsplit("}", 1)[-1].lower()
        if tag in ("script", "foreignobject", "iframe", "image", "animate", "set", "animatetransform"):
            raise ValueError("Unexpected SVG element: " + tag)
        for key, value in node.attrib.items():
            key = key.rsplit("}", 1)[-1].lower()
            if key.startswith("on") or (key == "href" and not value.startswith("#")):
                raise ValueError("Unexpected external SVG content")
        values = " ".join(node.attrib.values()) + (node.text or "")
        if "@import" in values.lower():
            raise ValueError("Unexpected SVG style import")
        for match in re.finditer(r"url\s*\(\s*([^)]*)\)", values, re.I):
            if not match.group(1).strip(" \"'").startswith("#"):
                raise ValueError("Unexpected external SVG reference")


def metadata(mode):
    name, minute, known_hash = SOURCES[mode]
    query = urlencode({
        "action": "query", "format": "json", "titles": "File:" + name,
        "prop": "imageinfo", "iiprop": "timestamp|sha1|url|size",
        "iistart": minute + ":59Z", "iiend": minute + ":00Z", "iilimit": 10,
    })
    pages = json.loads(get("https://commons.wikimedia.org/w/api.php?" + query))["query"]["pages"]
    matches = [info for page in pages.values() for info in page.get("imageinfo", [])
               if info["timestamp"].startswith(minute)]
    if len(matches) != 1:
        raise ValueError("Reviewed Commons revision not found: " + name)
    info = matches[0]
    sha = info["sha1"]
    digest = sha if re.fullmatch(r"[0-9a-f]{40}", sha) else format(int(sha, 36), "040x")
    if known_hash and digest != known_hash:
        raise ValueError("Reviewed Commons SHA-1 changed: " + name)
    return {"file": name, "timestamp": info["timestamp"], "sha1": digest,
            "size": info["size"], "url": info["url"]}


def verify_bytes(mode, data, info):
    name, minute, known_hash = SOURCES[mode]
    actual = hashlib.sha1(data).hexdigest()
    if (info["file"] != name or not info["timestamp"].startswith(minute)
            or actual != info["sha1"] or info["size"] != len(data)
            or (known_hash and actual != known_hash)):
        raise ValueError("Store artwork does not match reviewed revision: " + name)
    check_svg(data)


def verify(directory):
    manifest = json.loads((directory / "manifest.json").read_text(encoding="utf-8"))
    if set(manifest) != set(SOURCES):
        raise ValueError("Missing Store artwork variant")
    for mode, info in manifest.items():
        verify_bytes(mode, (directory / SOURCES[mode][0]).read_bytes(), info)
    return manifest


def prepare(directory, bundled=None):
    if bundled is not None and (bundled / "manifest.json").is_file():
        verify(bundled)
        if bundled.resolve() != directory.resolve():
            directory.mkdir(parents=True, exist_ok=True)
            for name in ["manifest.json", *(entry[0] for entry in SOURCES.values())]:
                shutil.copyfile(bundled / name, directory / name)
        verify(directory)
        return
    try:
        verify(directory)
        return
    except (OSError, ValueError, KeyError, TypeError, ET.ParseError):
        pass
    directory.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=directory.parent) as tmp:
        stage = Path(tmp)
        manifest = {}
        for mode in SOURCES:
            info = metadata(mode)
            data = get(info["url"])
            verify_bytes(mode, data, info)
            (stage / info["file"]).write_bytes(data)
            manifest[mode] = info
        (stage / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        verify(stage)
        directory.mkdir(parents=True, exist_ok=True)
        for p in stage.iterdir():
            shutil.copyfile(p, directory / p.name)
    verify(directory)


def apply(directory, dark_theme, light_theme):
    manifest = verify(directory)
    if not (dark_theme / "index.theme").is_file():
        raise ValueError("Windows Modern base theme is missing")
    light_theme.mkdir(parents=True, exist_ok=True)
    (light_theme / "index.theme").write_text(INDEX, encoding="utf-8")
    for mode, theme in (("dark", dark_theme), ("light", light_theme)):
        artwork = (directory / SOURCES[mode][0]).read_bytes()
        apps = theme / "apps"
        apps.mkdir(parents=True, exist_ok=True)
        for name in ALIASES:
            for ext in (".svg", ".svgz", ".png", ".xpm"):
                path = apps / (name + ext)
                if path.is_symlink() or path.is_file():
                    path.unlink()
            (apps / (name + ".svg")).write_bytes(artwork)
    (dark_theme / "Microsoft-Store-artwork.json").write_text(json.dumps(manifest, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    stage = commands.add_parser("prepare")
    stage.add_argument("directory", type=Path)
    stage.add_argument("--bundled", type=Path)
    check = commands.add_parser("verify")
    check.add_argument("directory", type=Path)
    install = commands.add_parser("apply")
    install.add_argument("directory", type=Path)
    install.add_argument("dark_theme", type=Path)
    install.add_argument("light_theme", type=Path)
    args = parser.parse_args()
    if args.command == "prepare":
        prepare(args.directory, args.bundled)
    elif args.command == "verify":
        verify(args.directory)
    else:
        apply(args.directory, args.dark_theme, args.light_theme)
    print("Microsoft Store: both reviewed SVG variants verified.")


if __name__ == "__main__":
    main()
