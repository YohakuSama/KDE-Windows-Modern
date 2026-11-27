#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Materialize native package source mirrors from the editable module tree.

Development only. The installed packages remain self-contained and retain
their original IDs and paths. --check is read-only; --write changes only
declared files. Remove obsolete generated files deliberately before writing.
"""
import argparse
import json
from pathlib import Path, PurePosixPath
import shutil

ROOT = Path(__file__).resolve().parents[1]


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
    if not directory.is_dir():
        raise ValueError(f"Missing directory: {directory.relative_to(ROOT)}")
    for entry in sorted(directory.rglob("*")):
        path = checked_path(entry.relative_to(ROOT).as_posix(), prefixes)
        if path.is_dir():
            continue
        if not path.is_file():
            raise ValueError(f"Not a regular file: {path.relative_to(ROOT)}")
        yield path


def source_plan():
    manifest = checked_path("core/source-map.json", ("core",))
    mapping = json.loads(manifest.read_text(encoding="utf-8"))
    if mapping["schema_version"] != 1:
        raise ValueError("Unsupported source map")
    expected = {}
    owned_trees = set()

    def add(source, destination):
        if not source.is_file():
            raise ValueError(f"Missing editable source: {source.relative_to(ROOT)}")
        if destination in expected:
            raise ValueError(f"Duplicate output: {destination.relative_to(ROOT)}")
        if destination.exists() and not destination.is_file():
            raise ValueError(f"Not a regular output: {destination.relative_to(ROOT)}")
        expected[destination] = source

    for relative, output in mapping["trees"].items():
        source = checked_path(relative, ("modules",))
        destination = checked_path(output, ("plasma",))
        owned_trees.add(destination)
        for item in regular_files(source, ("modules",)):
            target = destination / item.relative_to(source)
            add(item, checked_path(target.relative_to(ROOT).as_posix(), ("plasma",)))

    for relative, outputs in mapping["files"].items():
        source = checked_path(relative, ("core", "modules"))
        for output in outputs:
            add(source, checked_path(output, ("plasma",)))

    # Do not silently leave stale native source or delete untracked work.
    for directory in sorted(owned_trees):
        if directory.exists():
            for item in regular_files(directory, ("plasma",)):
                if item not in expected:
                    raise ValueError(
                        f"Unmapped native output: {item.relative_to(ROOT)}; "
                        "map it to an editable source or remove it deliberately"
                    )
    return expected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="compare without writing")
    mode.add_argument("--write", action="store_true", help="refresh declared mirrors")
    args = parser.parse_args()
    try:
        expected = source_plan()
        drift = [
            (destination, source)
            for destination, source in sorted(expected.items())
            if not destination.is_file() or destination.read_bytes() != source.read_bytes()
        ]
        if args.check:
            for destination, source in drift:
                print(f"Out of date: {destination.relative_to(ROOT)} <- {source.relative_to(ROOT)}")
            if drift:
                print("Run scripts/materialize-modules.py --write from the source checkout.")
                return 1
        else:
            for destination, source in drift:
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, destination)
        print(f"Native source mirrors: {len(expected)} files, {len(drift)} changed or stale")
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f"Module source map: {error}\n")


if __name__ == "__main__":
    raise SystemExit(main())
