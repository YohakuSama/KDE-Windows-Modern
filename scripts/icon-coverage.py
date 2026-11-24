#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Inventory icon coverage without inventing resource IDs or replacing artwork."""
import argparse
import configparser
import hashlib
import json
import os
from collections import defaultdict
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
EXTENSIONS = {".svg", ".svgz", ".png", ".xpm"}
NAME = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_.+-]*$")
# Literal references only. Dynamic expressions and pixmap providers require
# live inspection. The source: form is a candidate, not a proven icon lookup.
REFERENCE = re.compile(
    r'\b(icon\.name|iconName|iconSource|icon|source)\s*:\s*["\']([^"\']+)["\']'
)


def read_ini(path):
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    try:
        with path.open(encoding="utf-8") as f:
            parser.read_file(f)
    except (OSError, UnicodeError, configparser.Error):
        return None
    return parser


def theme_inventory(theme):
    config = read_ini(theme / "index.theme")
    if config is None or not config.has_section("Icon Theme"):
        raise ValueError("Missing or unreadable icon theme index")
    index = config["Icon Theme"]
    names = defaultdict(list)
    broken = []
    missing_dirs = []
    dirs = set((index.get("Directories", "") + "," +
                index.get("ScaledDirectories", "")).split(",")) - {""}
    for directory in sorted(dirs):
        folder = theme / directory
        if not folder.is_dir():
            missing_dirs.append(directory)
            continue
        for path in sorted(folder.iterdir()):
            if path.suffix.lower() not in EXTENSIONS:
                continue
            rel = path.relative_to(theme).as_posix()
            if path.is_symlink() and not path.exists():
                broken.append(rel)
            elif path.is_file():
                names[path.stem].append(rel)
    return dict(names), broken, missing_dirs


def native_inventory(mapping, manifest, theme, names):
    expected = defaultdict(list)
    for source, targets in mapping["icons"].items():
        for target in targets.split():
            expected[Path(target).name].append((source, target + ".svg"))
    outputs = manifest.get("outputs", {})
    actual = defaultdict(list)
    mismatched = []
    for rel, info in sorted(outputs.items()):
        if not rel.startswith("icons/") or not rel.endswith(".svg"):
            continue
        target = rel.removeprefix("icons/")
        # Do not read arbitrary paths specified by a local manifest.
        if ".." in Path(target).parts or Path(target).is_absolute():
            raise ValueError("Invalid native icon output path")
        path = theme / target
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != info["sha256"]:
            mismatched.append(target)
        else:
            actual[path.stem].append(target)
    return expected, actual, mismatched


def qml_candidates(root):
    found = defaultdict(list)
    for path in sorted((root / "plasma").rglob("*.qml")):
        if any(p.startswith("build") for p in path.parts):
            continue
        for line, content in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for match in REFERENCE.finditer(content):
                field, name = match.groups()
                if NAME.fullmatch(name) and not Path(name).suffix.lower() in (
                    EXTENSIONS | {".qml", ".js", ".json", ".jpg", ".webp"}
                ):
                    found[name].append({
                        "file": path.relative_to(root).as_posix(),
                        "line": line, "field": field,
                    })
    return found


def desktop_candidates(data_dirs):
    found = defaultdict(list)
    seen = set()
    for base in data_dirs:
        folder = base / "applications"
        if not folder.is_dir():
            continue
        for path in sorted(folder.rglob("*.desktop")):
            desktop_id = path.relative_to(folder).as_posix().replace("/", "-")
            if desktop_id in seen:
                continue
            seen.add(desktop_id)
            config = read_ini(path)
            if config is None or not config.has_section("Desktop Entry"):
                continue
            entry = config["Desktop Entry"]
            if (entry.get("Type") != "Application" or
                    entry.get("Hidden", "").lower() == "true" or
                    entry.get("NoDisplay", "").lower() == "true"):
                continue
            icon = entry.get("Icon", "").strip()
            if icon:
                found[icon].append(desktop_id)
    return found


def classify(name, names, expected, actual):
    if "/" in name:
        return "path_bypasses_theme"
    if name in actual:
        return "native_hash_verified"
    if name in expected:
        return "native_mapping_not_verified"
    if name in names:
        return "bundled_not_native_verified"
    return "not_in_theme"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--installed", action="store_true", help="Audit installed icons and XDG desktop entries")
    parser.add_argument("--theme", type=Path, help="Override icon theme path")
    parser.add_argument("--manifest", type=Path, help="Override local import manifest")
    args = parser.parse_args()
    data_home = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
    theme = args.theme or (data_home / "icons/windows-modern" if args.installed else ROOT / "icons/windows-modern")
    manifest_path = args.manifest or data_home / "windows-modern/native-assets/manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.is_file() else {}
    mapping = json.loads((ROOT / "scripts/native-assets-map.json").read_text(encoding="utf-8"))
    names, broken, missing_dirs = theme_inventory(theme)
    expected, actual, mismatched = native_inventory(mapping, manifest, theme, names)
    qml = qml_candidates(ROOT)
    desktop = desktop_candidates([data_home] + [
        Path(p) for p in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":") if p
    ]) if args.installed else {}
    report = defaultdict(list)
    for name in sorted(set(qml) | set(desktop) | set(expected)):
        status = classify(name, names, expected, actual)
        report[status].append({
            "name": name,
            "native_mapping": expected.get(name, []),
            "verified_native_files": actual.get(name, []),
            "theme_files": names.get(name, []),
            "qml_candidates": qml.get(name, []),
            "desktop_ids": desktop.get(name, []),
        })
    print(json.dumps({
        "mode": "installed" if args.installed else "repository",
        "manifest_present": bool(manifest),
        "theme_icon_names": len(names),
        "mapped_native_paths": sum(map(len, expected.values())),
        "verified_native_paths": sum(map(len, actual.values())),
        "broken_theme_links": broken,
        "missing_index_directories": missing_dirs,
        "native_output_missing_or_changed": mismatched,
        "counts": {k: len(v) for k, v in sorted(report.items())},
        "references": dict(sorted(report.items())),
        "limitations": [
            "Not in this theme may still resolve through inherited themes.",
            "Bundled does not establish Windows origin; verify the resource before replacing.",
            "Literal QML candidates may include non-icon sources; dynamic names, native applets and pixmaps need live testing.",
            "A verified output hash establishes local import parity, not semantic identity or Windows version."
        ],
    }, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
