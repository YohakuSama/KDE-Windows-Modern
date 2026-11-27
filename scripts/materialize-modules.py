#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Materialize self-contained native packages from their editable sources.

Development only: --check is read-only, --write refreshes declared mirrors.
Obsolete native files must be removed deliberately, never silently deleted.
"""
import argparse
import json
import os
from pathlib import Path, PurePosixPath
import stat
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOTS = ("core", "modules", "platform", "packaging")
OUTPUT_ROOTS = ("plasma", "app-decorations", "boot", "config", "nix",
                "scripts", "Kvantum", "aurorae", "color-schemes")
PANEL_MARKER = "@PANEL_BODY@"
SOURCE_METADATA = {"core/README.md", "core/source-map.json", "modules/README.md",
                   "platform/README.md", "packaging/README.md"}


def checked_path(relative, prefixes):
    path = PurePosixPath(relative)
    if (path.is_absolute() or not path.parts or path.parts[0] not in prefixes
            or len(path.parts) < 2 or ".." in path.parts
            or str(path) != relative):
        raise ValueError(f"Invalid source-map path: {relative}")
    result = ROOT.joinpath(*path.parts)
    for part in (result, *result.parents):
        if part == ROOT:
            break
        if part.is_symlink():
            raise ValueError(f"Symlink in source-map path: {part}")
    return result


def regular_files(directory, prefixes):
    if not directory.is_dir() or directory.is_symlink():
        raise ValueError(f"Missing or invalid directory: {directory.relative_to(ROOT)}")
    for entry in sorted(directory.rglob("*")):
        path = checked_path(entry.relative_to(ROOT).as_posix(), prefixes)
        if path.is_dir():
            continue
        if not path.is_file():
            raise ValueError(f"Not a regular file: {path.relative_to(ROOT)}")
        yield path


def file_mode(path):
    return 0o755 if path.stat().st_mode & stat.S_IXUSR else 0o644


def source_plan():
    manifest = checked_path("core/source-map.json", SOURCE_ROOTS)
    mapping = json.loads(manifest.read_text(encoding="utf-8"))
    if mapping["schema_version"] != 2:
        raise ValueError("Unsupported source map")
    expected = {}
    owned_trees = set()
    used_sources = set()

    def add(destination, source, payload, mode):
        if destination in expected:
            raise ValueError(f"Duplicate output: {destination.relative_to(ROOT)}")
        if destination.exists() and not destination.is_file():
            raise ValueError(f"Not a regular output: {destination.relative_to(ROOT)}")
        expected[destination] = (source, payload, mode)
        used_sources.add(source)

    def copy(source, destination):
        if not source.is_file():
            raise ValueError(f"Missing editable source: {source.relative_to(ROOT)}")
        add(destination, source, source.read_bytes(), file_mode(source))

    for relative, output in mapping["trees"].items():
        source = checked_path(relative, SOURCE_ROOTS)
        destination = checked_path(output, OUTPUT_ROOTS)
        owned_trees.add(destination)
        for item in regular_files(source, SOURCE_ROOTS):
            target = destination / item.relative_to(source)
            copy(item, checked_path(target.relative_to(ROOT).as_posix(), OUTPUT_ROOTS))

    for relative, outputs in mapping["files"].items():
        source = checked_path(relative, SOURCE_ROOTS)
        if not isinstance(outputs, list) or not outputs:
            raise ValueError(f"Missing outputs for {relative}")
        for output in outputs:
            copy(source, checked_path(output, OUTPUT_ROOTS))

    # Both Plasma panel entry points use the same geometry and widget body.
    # Only the wrapper decides whether to add one panel or replace all panels.
    for output, recipe in mapping["rendered"].items():
        template = checked_path(recipe["template"], SOURCE_ROOTS)
        body = checked_path(recipe["body"], SOURCE_ROOTS)
        destination = checked_path(output, OUTPUT_ROOTS)
        indent = recipe["indent"]
        text = template.read_text(encoding="utf-8")
        if (type(indent) is not int or not 0 <= indent <= 8
                or text.count(PANEL_MARKER) != 1
                or PANEL_MARKER not in text.splitlines()):
            raise ValueError(f"Invalid panel template: {template.relative_to(ROOT)}")
        lines = body.read_text(encoding="utf-8").rstrip("\n").split("\n")
        shared = "\n".join(" " * indent + line if line else "" for line in lines)
        add(destination, template, text.replace(PANEL_MARKER, shared).encode("utf-8"),
            file_mode(template))
        used_sources.add(body)

    # All files in a fully owned native subtree must have exactly one producer.
    for directory in sorted(owned_trees):
        if directory.exists():
            for item in regular_files(directory, OUTPUT_ROOTS):
                if item not in expected:
                    raise ValueError(
                        f"Unmapped native output: {item.relative_to(ROOT)}; "
                        "map it to an editable source or remove it deliberately"
                    )
    # A new editable source must actually reach a native consumer. Documentation
    # at the roots and the map itself are not runtime input.
    for name in SOURCE_ROOTS:
        for item in regular_files(ROOT / name, SOURCE_ROOTS):
            if item not in used_sources and item.relative_to(ROOT).as_posix() not in SOURCE_METADATA:
                raise ValueError(f"Unmapped editable source: {item.relative_to(ROOT)}")
    return expected


def replace_file(destination, payload, mode):
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as out:
            temporary = Path(out.name)
            out.write(payload)
        temporary.chmod(mode)
        os.replace(temporary, destination)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="compare without writing")
    mode.add_argument("--write", action="store_true", help="refresh declared mirrors")
    args = parser.parse_args()
    try:
        expected = source_plan()
        drift = [
            (destination, source, payload, permissions)
            for destination, (source, payload, permissions) in sorted(expected.items())
            if (not destination.is_file() or destination.read_bytes() != payload
                or file_mode(destination) != permissions)
        ]
        if args.check:
            for destination, source, _, _ in drift:
                print(f"Out of date: {destination.relative_to(ROOT)} <- {source.relative_to(ROOT)}")
            if drift:
                print("Run python3 -I scripts/materialize-modules.py --write from the source checkout.")
                return 1
        else:
            for destination, _, payload, permissions in drift:
                replace_file(destination, payload, permissions)
        print(f"Native source mirrors: {len(expected)} files, {len(drift)} changed or stale")
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f"Module source map: {error}\n")


if __name__ == "__main__":
    raise SystemExit(main())
