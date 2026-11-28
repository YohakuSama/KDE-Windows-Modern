#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Materialize self-contained native packages from their editable sources.

--prepare refreshes generated outputs and validates source-only aliases.
--check is read-only; --write refreshes the same generated outputs.
The archive mode replaces source-only aliases with real files from the commit.
Obsolete native files must be removed deliberately, never silently deleted.
"""
import argparse
import io
import json
import os
from pathlib import Path, PurePosixPath
import runpy
import stat
import subprocess
import tarfile
import tempfile
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOTS = ("core", "modules", "platform", "packaging")
OUTPUT_ROOTS = ("plasma", "app-decorations", "boot", "config", "nix",
                "scripts", "Kvantum", "aurorae", "color-schemes")
PANEL_MARKER = "@PANEL_BODY@"
SOURCE_METADATA = {"core/README.md", "core/source-map.json", "modules/README.md",
                   "platform/README.md", "packaging/README.md",
                   "modules/terminal/plugin/README.md", "platform/nixos/README.md"}


def checked_path(relative, prefixes, root, *, allow_leaf_link=False):
    path = PurePosixPath(relative)
    if (path.is_absolute() or not path.parts or path.parts[0] not in prefixes
            or len(path.parts) < 2 or ".." in path.parts
            or str(path) != relative):
        raise ValueError(f"Invalid source-map path: {relative}")
    result = root.joinpath(*path.parts)
    for part in (result, *result.parents):
        if part == root:
            break
        if part.is_symlink() and not (allow_leaf_link and part == result):
            raise ValueError(f"Symlink in source-map path: {part}")
    return result


def regular_files(directory, prefixes, root):
    if not directory.is_dir() or directory.is_symlink():
        raise ValueError(f"Missing or invalid directory: {directory.relative_to(root)}")
    for entry in sorted(directory.rglob("*")):
        path = checked_path(entry.relative_to(root).as_posix(), prefixes, root)
        # Importing an editable Python module through its source alias can
        # create bytecode here; it is never a canonical source or an output.
        if prefixes == SOURCE_ROOTS and "__pycache__" in path.relative_to(root).parts:
            continue
        if path.is_dir():
            continue
        if not path.is_file():
            raise ValueError(f"Not a regular file: {path.relative_to(root)}")
        yield path


def file_mode(path):
    return 0o755 if path.stat().st_mode & stat.S_IXUSR else 0o644


def source_plan(root=ROOT, *, validate_links=True):
    manifest = checked_path("core/source-map.json", SOURCE_ROOTS, root)
    mapping = json.loads(manifest.read_text(encoding="utf-8"))
    if mapping["schema_version"] != 4:
        raise ValueError("Unsupported source map")
    link_names = mapping["linked_files"]
    if not isinstance(link_names, list) or len(link_names) != len(set(link_names)):
        raise ValueError("Invalid source-only aliases")
    linked = {checked_path(name, OUTPUT_ROOTS, root, allow_leaf_link=True)
              for name in link_names}
    expected = {}
    owned_trees = set()
    used_sources = set()

    def add(destination, source, payload, mode):
        if destination in expected:
            raise ValueError(f"Duplicate output: {destination.relative_to(root)}")
        if destination.exists() and not destination.is_file():
            raise ValueError(f"Not a regular output: {destination.relative_to(root)}")
        expected[destination] = (source, payload, mode)
        used_sources.add(source)

    def copy(source, destination):
        if not source.is_file():
            raise ValueError(f"Missing editable source: {source.relative_to(root)}")
        add(destination, source, source.read_bytes(), file_mode(source))

    for relative, output in mapping["trees"].items():
        source = checked_path(relative, SOURCE_ROOTS, root)
        destination = checked_path(output, OUTPUT_ROOTS, root)
        owned_trees.add(destination)
        for item in regular_files(source, SOURCE_ROOTS, root):
            target = destination / item.relative_to(source)
            copy(item, checked_path(target.relative_to(root).as_posix(), OUTPUT_ROOTS, root))

    for relative, outputs in mapping["files"].items():
        source = checked_path(relative, SOURCE_ROOTS, root)
        if not isinstance(outputs, list) or not outputs:
            raise ValueError(f"Missing outputs for {relative}")
        for output in outputs:
            destination = checked_path(output, OUTPUT_ROOTS, root,
                                       allow_leaf_link=output in link_names)
            if destination in linked and validate_links:
                target = os.path.relpath(source, destination.parent)
                if not destination.is_symlink() or os.readlink(destination) != target:
                    raise ValueError(f"Invalid source-only alias: {output}; restore it from Git")
            copy(source, destination)

    for output, recipe in mapping["rendered"].items():
        template = checked_path(recipe["template"], SOURCE_ROOTS, root)
        body = checked_path(recipe["body"], SOURCE_ROOTS, root)
        destination = checked_path(output, OUTPUT_ROOTS, root)
        indent = recipe["indent"]
        text = template.read_text(encoding="utf-8")
        if (type(indent) is not int or not 0 <= indent <= 8
                or text.count(PANEL_MARKER) != 1
                or PANEL_MARKER not in text.splitlines()):
            raise ValueError(f"Invalid panel template: {template.relative_to(root)}")
        lines = body.read_text(encoding="utf-8").rstrip("\n").split("\n")
        shared = "\n".join(" " * indent + line if line else "" for line in lines)
        add(destination, template, text.replace(PANEL_MARKER, shared).encode("utf-8"),
            file_mode(template))
        used_sources.add(body)

    # Only wholly owned trees or individually mapped files may become untracked.
    generated = set()
    for relative in mapping["generated_roots"]:
        directory = checked_path(relative, OUTPUT_ROOTS, root)
        if directory not in owned_trees and directory not in expected:
            # A contents subtree of a wholly owned native package is also safe.
            if not any(parent in owned_trees for parent in directory.parents):
                raise ValueError(f"Unowned generated root: {relative}")
        members = {p for p in expected if p == directory or directory in p.parents}
        if not members or members & generated:
            raise ValueError(f"Empty or overlapping generated root: {relative}")
        generated.update(members)

    # Aliases are allowed only for explicitly mapped script/data files.
    # Never link an independently installed package to the developer tree.
    if (linked & generated or not linked <= expected.keys()
            or any(path.relative_to(root).parts[0] != "scripts" for path in linked)):
        raise ValueError("Invalid linked output scope")
    if generated | linked != set(expected):
        raise ValueError("Every native output must be generated or a source-only alias")

    for directory in sorted(owned_trees):
        if directory.exists():
            for item in regular_files(directory, OUTPUT_ROOTS, root):
                if item not in expected:
                    raise ValueError(
                        f"Unmapped native output: {item.relative_to(root)}; "
                        "map it to an editable source or remove it deliberately"
                    )

    # Tree-owned outputs are checked recursively above. Individually mapped
    # files also need a sibling check: an ignored output removed from the map
    # can otherwise survive a branch update and be copied by an installer.
    # Preserve tracked developer files, reject untracked extras, and never
    # delete user files automatically. Archive staging uses a temporary root.
    if root.resolve() == ROOT.resolve():
        try:
            tracked_bytes = subprocess.check_output(
                ["git", "-C", str(root), "ls-files", "-z", "--", *OUTPUT_ROOTS],
                stderr=subprocess.DEVNULL,
            )
        except (OSError, subprocess.CalledProcessError):
            tracked_bytes = None
        if tracked_bytes is not None:
            tracked = {os.fsdecode(name) for name in tracked_bytes.split(b"\0") if name}
            parent_scopes = {
                destination.parent
                for destination in expected
                if not any(parent in owned_trees for parent in destination.parents)
            }
            for directory in sorted(parent_scopes):
                if directory.is_symlink():
                    raise ValueError(f"Invalid native output parent: {directory.relative_to(root)}")
                if not directory.is_dir():
                    continue
                for item in directory.iterdir():
                    relative = item.relative_to(root).as_posix()
                    if item.is_symlink():
                        if item not in expected:
                            raise ValueError(f"Unmapped native symlink: {relative}")
                        continue
                    if item.is_file() and item not in expected and relative not in tracked:
                        raise ValueError(
                            f"Unmapped native output: {relative}; "
                            "remove it deliberately or add it to the source map"
                        )
    for name in SOURCE_ROOTS:
        for item in regular_files(root / name, SOURCE_ROOTS, root):
            if item not in used_sources and item.relative_to(root).as_posix() not in SOURCE_METADATA:
                raise ValueError(f"Unmapped editable source: {item.relative_to(root)}")
    return expected, generated, linked


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


def append_archive(filename, revision, prefix):
    """Add untracked native outputs from the archived commit, not the worktree."""
    parts = PurePosixPath(prefix).parts
    if (len(revision) != 40 or any(c not in "0123456789abcdef" for c in revision)
            or len(parts) != 1 or parts[0] in ("/", "..") or prefix != parts[0] + "/"):
        raise ValueError("Invalid archive revision or prefix")
    raw = subprocess.check_output(["git", "-C", str(ROOT), "archive", "--format=tar",
                                   revision, "--", *SOURCE_ROOTS])
    policy = runpy.run_path(str(ROOT / "scripts/verify-owner-bundle.py"))["is_development_file"]
    with tempfile.TemporaryDirectory(prefix="wm-module-source-") as temp:
        root = Path(temp)
        with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as source:
            for member in source:
                if member.isdir():
                    continue
                if not member.isfile():
                    raise ValueError(f"Non-regular canonical archive member: {member.name}")
                path = checked_path(member.name, SOURCE_ROOTS, root)
                if path.exists():
                    raise ValueError(f"Duplicate canonical archive member: {member.name}")
                with source.extractfile(member) as payload:
                    replace_file(path, payload.read(), 0o755 if member.mode & stat.S_IXUSR else 0o644)
        expected, generated, linked = source_plan(root, validate_links=False)
        with ZipFile(filename, "a", compression=ZIP_DEFLATED) as archive:
            names = archive.namelist()
            if (not names or len(names) != len(set(names))
                    or archive.comment != revision.encode("ascii")
                    or any(not name.startswith(prefix) for name in names)):
                raise ValueError("Archive is not the requested committed source ZIP")
            have = set(names)
            pending = []
            for path in sorted(generated | linked):
                name = path.relative_to(root).as_posix()
                if policy(name):
                    if path in linked:
                        continue  # Development-only script; absent from install ZIP.
                    raise ValueError(f"Generated installation output is excluded: {name}")
                if prefix + name in have:
                    raise ValueError(f"Already archived generated output: {name}")
                _, data, mode = expected[path]
                info = ZipInfo(prefix + name, archive.infolist()[0].date_time)
                info.create_system = 3
                info.external_attr = (stat.S_IFREG | mode) << 16
                info.compress_type = ZIP_DEFLATED
                pending.append((info, data))
            for info, data in pending:
                archive.writestr(info, data)
        print(f"Archived {len(pending)} real native files from {revision}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="compare without writing")
    mode.add_argument("--write", action="store_true", help="refresh generated files (same as --prepare)")
    mode.add_argument("--prepare", action="store_true", help="refresh generated files and validate aliases")
    mode.add_argument("--append-archive", type=Path, metavar="ZIP")
    parser.add_argument("--revision")
    parser.add_argument("--prefix")
    args = parser.parse_args()
    try:
        if args.append_archive is not None:
            if not args.revision or not args.prefix:
                parser.error("--append-archive requires --revision and --prefix")
            append_archive(args.append_archive, args.revision, args.prefix)
            return 0
        if args.revision is not None or args.prefix is not None:
            parser.error("--revision/--prefix require --append-archive")
        expected, generated, linked = source_plan()
        drift = [
            (destination, source, payload, permissions)
            for destination, (source, payload, permissions) in sorted(expected.items())
            if destination in generated and (
                not destination.is_file() or destination.read_bytes() != payload
                or file_mode(destination) != permissions)
        ]
        if args.check and drift:
            for destination, source, _, _ in drift:
                print(f"Out of date: {destination.relative_to(ROOT)} <- {source.relative_to(ROOT)}")
            print("Run python3 -I scripts/materialize-modules.py --prepare.")
            return 1
        if not args.check:
            for destination, _, payload, permissions in drift:
                replace_file(destination, payload, permissions)
        print(f"Native outputs: {len(generated)} generated, {len(linked)} source aliases, "
              f"{len(drift)} refreshed or stale")
        return 0
    except (OSError, ValueError, KeyError, TypeError, tarfile.TarError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Module source map: {error}\n")


if __name__ == "__main__":
    raise SystemExit(main())
