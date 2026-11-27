#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate and synchronize canonical SVGs and their semantic icon-name aliases."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import tempfile

ROOT = Path(__file__).resolve().parents[1]
THEME = ROOT / "icons" / "windows-modern"
MANIFEST = ROOT / "icons" / "windows-modern-aliases.json"
SHA1 = re.compile(r"^[0-9a-f]{40}$")


def blob_sha1(data):
    header = b"blob " + str(len(data)).encode("ascii") + b"\0"
    return hashlib.sha1(header + data).hexdigest()


def checked_svg(relative):
    rel = PurePosixPath(relative)
    if (rel.is_absolute() or not rel.parts or ".." in rel.parts
            or "\\" in relative or str(rel) != relative or rel.suffix != ".svg"):
        raise ValueError("Invalid SVG alias path: " + relative)
    path = THEME.joinpath(*rel.parts)
    root = THEME.resolve()
    for part in (path, *path.parents):
        if part == THEME:
            break
        if part.is_symlink():
            raise ValueError("Symlink in icon theme source: " + str(part.relative_to(ROOT)))
    if not path.resolve(strict=False).is_relative_to(root):
        raise ValueError("SVG path escapes icon theme: " + relative)
    return path


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o644
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(data)
        temporary.chmod(mode)
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def load_manifest():
    if MANIFEST.is_symlink() or not MANIFEST.is_file():
        raise ValueError("Missing or invalid SVG alias manifest")
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("Invalid SVG alias manifest root")
    if data.get("schema_version") != 1 or data.get("theme") != "windows-modern":
        raise ValueError("Unsupported SVG alias manifest")
    if not isinstance(data.get("groups"), list):
        raise ValueError("Invalid SVG alias groups")
    used = set()
    expected = set()
    for group in data["groups"]:
        if not isinstance(group, dict):
            raise ValueError("Invalid SVG alias group")
        canonical = group.get("canonical")
        aliases = group.get("aliases")
        digest = group.get("blob_sha1")
        if (not isinstance(canonical, str) or not isinstance(aliases, list)
                or not aliases or not all(isinstance(p, str) for p in aliases)
                or not isinstance(digest, str) or not SHA1.fullmatch(digest)):
            raise ValueError("Invalid SVG alias group")
        members = [canonical, *aliases]
        if len(members) != len(set(members)):
            raise ValueError("Repeated path in SVG alias group: " + canonical)
        for relative in members:
            checked_svg(relative)
            if relative in used:
                raise ValueError("SVG path belongs to multiple alias groups: " + relative)
            used.add(relative)
        expected.add(tuple(sorted(members)))
    if len(expected) != len(data["groups"]):
        raise ValueError("Duplicate SVG alias group")
    return data, expected


def inventory():
    if not THEME.is_dir() or THEME.is_symlink():
        raise ValueError("Missing or invalid Windows Modern icon theme")
    files = []
    by_hash = {}
    for path in sorted(THEME.rglob("*.svg")):
        if path.is_symlink() or not path.is_file():
            raise ValueError("Non-regular SVG in icon theme: " + str(path.relative_to(ROOT)))
        relative = path.relative_to(THEME).as_posix()
        digest = blob_sha1(path.read_bytes())
        files.append(relative)
        by_hash.setdefault(digest, []).append(relative)
    actual = {tuple(sorted(paths)) for paths in by_hash.values() if len(paths) > 1}
    return files, by_hash, actual


def compare_groups(actual, expected):
    if actual == expected:
        return
    unexpected = sorted(actual - expected)
    missing = sorted(expected - actual)
    details = []
    if unexpected:
        details.append("unclassified duplicate groups: " + str(unexpected[:8]))
    if missing:
        details.append("manifest groups no longer identical: " + str(missing[:8]))
    raise ValueError("; ".join(details))


def check():
    manifest, expected = load_manifest()
    files, _, actual = inventory()
    alias_count = sum(len(group["aliases"]) for group in manifest["groups"])
    counts = {
        "svg_count": len(files),
        "canonical_count": len(files) - alias_count,
        "alias_group_count": len(manifest["groups"]),
        "alias_path_count": alias_count,
    }
    for key, value in counts.items():
        if manifest.get(key) != value:
            raise ValueError(f"Manifest {key} is stale: expected {value}, found {manifest.get(key)}")
    errors = []
    for group in manifest["groups"]:
        canonical = checked_svg(group["canonical"])
        if not canonical.is_file() or canonical.is_symlink():
            errors.append("missing canonical SVG: " + group["canonical"])
            continue
        data = canonical.read_bytes()
        digest = blob_sha1(data)
        if digest != group["blob_sha1"]:
            errors.append("canonical SVG changed: " + group["canonical"] + " (run --sync)")
        for relative in group["aliases"]:
            alias = checked_svg(relative)
            if not alias.is_file() or alias.is_symlink():
                errors.append("missing or invalid alias SVG: " + relative)
            elif alias.read_bytes() != data:
                errors.append("alias differs from canonical: " + relative)
    compare_groups(actual, expected)
    if errors:
        raise ValueError("; ".join(errors[:20]))
    print(f"Verified {counts['alias_group_count']} canonical SVG groups, "
          f"{alias_count} semantic aliases and {len(files)} theme SVG files")


def sync():
    manifest, expected = load_manifest()
    changed = 0
    for group in manifest["groups"]:
        canonical = checked_svg(group["canonical"])
        if not canonical.is_file() or canonical.is_symlink():
            raise ValueError("Missing canonical SVG: " + group["canonical"])
        data = canonical.read_bytes()
        group["blob_sha1"] = blob_sha1(data)
        for relative in group["aliases"]:
            alias = checked_svg(relative)
            if alias.exists() and (alias.is_symlink() or not alias.is_file()):
                raise ValueError("Refusing to replace non-regular alias: " + relative)
            if not alias.is_file() or alias.read_bytes() != data:
                atomic_write(alias, data)
                changed += 1
    files, _, actual = inventory()
    compare_groups(actual, expected)
    alias_count = sum(len(group["aliases"]) for group in manifest["groups"])
    manifest["svg_count"] = len(files)
    manifest["canonical_count"] = len(files) - alias_count
    manifest["alias_group_count"] = len(manifest["groups"])
    manifest["alias_path_count"] = alias_count
    atomic_write(MANIFEST, (json.dumps(manifest, indent=2, ensure_ascii=False) + "\n").encode("utf-8"))
    check()
    print(f"Synchronized {changed} semantic SVG aliases")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--check", action="store_true")
    modes.add_argument("--sync", action="store_true")
    args = parser.parse_args()
    try:
        sync() if args.sync else check()
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
        parser.exit(1, "SVG resource check failed: " + str(error) + "\n")


if __name__ == "__main__":
    main()
