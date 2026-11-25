#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Fail closed on incomplete, stale, corrupt or undersized private test ZIPs."""
from collections import Counter
from pathlib import Path, PurePosixPath
import json
import re
import sys
from zipfile import ZipFile

MIN_BYTES = 90_000_000  # The owner requires at least 90 MB, measured on disk.


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
        json.loads(z.read(prefix + native + "resource-manifest.json"))
        for directory in ("png/", "original/Windows/Media/"):
            if not any(n.startswith(prefix + native + directory) for n in members):
                raise ValueError("Missing resource directory: " + directory)
        corrupt = z.testzip()
        if corrupt is not None:
            raise ValueError("Corrupt ZIP member: " + corrupt)
    print(f"Verified private owner ZIP: {filename.stat().st_size:,} bytes, {revision}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: verify-owner-bundle.py SHA ZIP")
    verify(sys.argv[1], sys.argv[2])
