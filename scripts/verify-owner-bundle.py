#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Fail closed on incomplete, stale, corrupt or undersized private test ZIPs."""
from collections import Counter
from pathlib import Path, PurePosixPath
import hashlib
import json
import re
import sys
from zipfile import ZipFile

MIN_BYTES = 90_000_000  # The owner requires at least 90 MB, measured on disk.


def verify_resource_index(z, prefix, index, required_originals):
    """Check the same indexed file fields consumed by the native importer.

    The staging script includes Web, Media, SystemResources, SegoeIcons.ttf
    and the whole png tree, not every original from the reference archive.
    """
    expected = {}

    def add(path, digest, size=None):
        parts = PurePosixPath(path).parts
        if (not parts or PurePosixPath(path).is_absolute() or ".." in parts
                or not re.fullmatch(r"[0-9a-f]{64}", digest)):
            raise ValueError("Invalid indexed resource: " + path)
        old = expected.get(path)
        entry = (digest, size)
        if old is not None and old != entry:
            raise ValueError("Conflicting indexed resource: " + path)
        expected[path] = entry

    for entry in index["original_files"]:
        path = entry["path"]
        if (path.startswith(("original/Windows/Web/", "original/Windows/Media/",
                             "original/Windows/SystemResources/"))
                or path == "original/Windows/Fonts/SegoeIcons.ttf"):
            add(path, entry["sha256"], entry["size_bytes"])
    if not set(required_originals).issubset(expected):
        raise ValueError("Required originals missing from resource index")

    png_count = 0
    for group in index["groups"]:
        previews = set()
        for frame in group["frames"]:
            path = frame.get("png")
            if path:
                if not path.startswith("png/"):
                    raise ValueError("Unexpected indexed PNG: " + path)
                add(path, frame["png_sha256"])
                previews.add(path)
                png_count += 1
        if group.get("preview_png") and group["preview_png"] not in previews:
            raise ValueError("Group preview missing from indexed frames")
    if not png_count:
        raise ValueError("Resource index contains no PNG frames")

    for path, (digest, size) in expected.items():
        name = prefix + path
        try:
            info = z.getinfo(name)
        except KeyError as exc:
            raise ValueError("Missing indexed resource: " + path) from exc
        if info.is_dir() or (size is not None and info.file_size != size):
            raise ValueError("Indexed resource size mismatch: " + path)
        hash_value = hashlib.sha256()
        with z.open(info) as stream:
            while chunk := stream.read(1024 * 1024):
                hash_value.update(chunk)
        if hash_value.hexdigest() != digest:
            raise ValueError("Indexed resource hash mismatch: " + path)
    return len(expected)


def verify(revision, filename, min_bytes=MIN_BYTES):
    filename = Path(filename)
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("Expected full Git commit SHA")
    if filename.stat().st_size < min_bytes:
        raise ValueError(f"Owner ZIP has only {filename.stat().st_size} bytes; minimum is {min_bytes}")
    with ZipFile(filename) as z:
        members = [i.filename for i in z.infolist() if not i.is_dir()]
        if any(n > 1 for n in Counter(members).values()):
            raise ValueError("Duplicate ZIP members")
        roots = {PurePosixPath(n).parts[0] for n in members}
        if len(roots) != 1 or any(PurePosixPath(n).is_absolute() or ".." in PurePosixPath(n).parts for n in members):
            raise ValueError("Invalid archive paths")
        prefix = next(iter(roots)) + "/"
        native = "native-resources/"
        required = (
            "INTEGRATION-BUILD", "install.sh", "install-nixos.sh",
            "uninstall.sh", "third_party/plasma-login-manager/CMakeLists.txt",
            "tests/systemtray/tst_trayMetrics.qml", "tests/run-qml-tests.sh",
            "plasma/applets/org.kde.windowsmodern.systemtray/systemtray.cpp",
            "plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/PanelStatusGlyph.qml",
            "plasma/applets/org.kde.windowsmodern.icontasks/CMakeLists.txt",
            "plasma/containmentactions/org.kde.windowsmodern.contextmenu/CMakeLists.txt",
            "bundled-store-artwork/manifest.json",
            native + "RESOURCE-COMMIT", native + "resource-manifest.json",
            native + "original/Windows/Web/Wallpaper/Windows/img0.jpg",
            native + "original/Windows/Web/Wallpaper/Windows/img19.jpg",
            native + "original/Windows/Web/Screen/img100.jpg",
            native + "original/Windows/SystemResources/imageres.dll.mun",
            native + "original/Windows/SystemResources/shell32.dll.mun",
            native + "original/Windows/SystemResources/imagesp1.dll.mun",
            native + "original/Windows/Fonts/SegoeIcons.ttf",
        )
        for name in required:
            if prefix + name not in members or z.getinfo(prefix + name).file_size == 0:
                raise ValueError("Missing/empty owner payload: " + name)
        if z.read(prefix + "INTEGRATION-BUILD").decode().strip() != revision:
            raise ValueError("ZIP revision differs from checkout")
        stage = z.read(prefix + "scripts/stage-native-resources.sh").decode()
        match = re.search(r"^pin=([0-9a-f]{40})$", stage, re.M)
        if not match or z.read(prefix + native + "RESOURCE-COMMIT").decode().strip() != match[1]:
            raise ValueError("Resource revision differs from reviewed pin")
        index = json.loads(z.read(prefix + native + "resource-manifest.json"))
        required_originals = [name[len(native):] for name in required
                              if name.startswith(native + "original/")]
        checked_resources = verify_resource_index(z, prefix + native, index, required_originals)
        for directory in ("png/", "original/Windows/Media/"):
            if not any(n.startswith(prefix + native + directory) for n in members):
                raise ValueError("Missing resource directory: " + directory)
        corrupt = z.testzip()
        if corrupt is not None:
            raise ValueError("Corrupt ZIP member: " + corrupt)
    print(f"Verified private owner ZIP: {filename.stat().st_size:,} bytes, {revision}, "
          f"{checked_resources} indexed resources")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: verify-owner-bundle.py SHA ZIP")
    verify(sys.argv[1], sys.argv[2])
