#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify that a CI archive contains the exact revision and necessary payload."""
from pathlib import PurePosixPath
from collections import Counter
import hashlib
import re
import sys
import runpy
import json
from pathlib import Path
from zipfile import ZipFile

STORE = runpy.run_path(str(Path(__file__).with_name("store-artwork.py")))
THEME_POLICY = runpy.run_path(str(Path(__file__).with_name("verify-owner-bundle.py")))


def verify(revision, filename):
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("Expected a full Git commit SHA")
    with ZipFile(filename) as bundle:
        members = [item.filename for item in bundle.infolist() if not item.is_dir()]
        if any(n > 1 for n in Counter(members).values()):
            raise ValueError("Archive contains duplicate files")
        roots = set()
        for name in members:
            path = PurePosixPath(name)
            if path.is_absolute() or ".." in path.parts:
                raise ValueError("Unsafe archive path: " + name)
            roots.add(path.parts[0])
            if any(part in (".git", "__pycache__", "wm-build") for part in path.parts):
                raise ValueError("Unexpected build/cache file: " + name)
        if len(roots) != 1:
            raise ValueError("Archive must contain a single top-level directory")
        prefix = next(iter(roots)) + "/"
        for name in members:
            if THEME_POLICY["is_development_file"](name[len(prefix):]):
                raise ValueError("Development payload in integration ZIP: " + name)
        THEME_POLICY["verify_script_payload"](bundle, prefix)
        required = (
            "INTEGRATION-BUILD", "install.sh", "install-nixos.sh",
            "config/kxmlgui5/dolphin/dolphinui.rc",
            "config/kxmlgui5/konsole/sessionui.rc",
            "plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/components/ViewModeMenu.qml",
            "plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/components/ClipboardPage.qml",
            "scripts/theme/window-frames.py", "scripts/theme/palette.json",
            "color-schemes/WindowsModern.colors.in",
            "scripts/theme/appearance-packages.py", "scripts/theme/sync-accent.py",
            "scripts/theme/accent-control.py", "scripts/theme/wallpaper-icc.py",
            "app-decorations/kvantum/live-reload-1.1.9.patch",
            "prebuilt/SHA256SUMS",
            "bundled-store-artwork/manifest.json",
            "bundled-store-artwork/Microsoft_Store_logo_dark.svg",
            "bundled-store-artwork/Microsoft_Store_logo_light.svg",
        )
        missing = [name for name in required if prefix + name not in members]
        if missing:
            raise ValueError("Missing archive payload: " + ", ".join(missing))
        if bundle.read(prefix + "INTEGRATION-BUILD").decode().strip() != revision:
            raise ValueError("Archive revision does not match CI commit")
        manifest = bundle.read(prefix + "prebuilt/SHA256SUMS").decode().splitlines()
        if not manifest:
            raise ValueError("No prebuilt checksums")
        for line in manifest:
            expected, name = line.split(maxsplit=1)
            name = name.lstrip("*")
            if not re.fullmatch(r"[0-9a-f]{64}", expected) or "/" in name or name in (".", ".."):
                raise ValueError("Invalid plugin manifest line")
            digest = hashlib.sha256()
            with bundle.open(prefix + "prebuilt/" + name) as plugin:
                for chunk in iter(lambda: plugin.read(1024 * 1024), b""):
                    digest.update(chunk)
            if digest.hexdigest() != expected:
                raise ValueError("Prebuilt plugin checksum mismatch: " + name)
        artwork_prefix = prefix + "bundled-store-artwork/"
        artwork = json.loads(bundle.read(artwork_prefix + "manifest.json"))
        if set(artwork) != set(STORE["SOURCES"]):
            raise ValueError("Missing reviewed Store variant")
        for mode, info in artwork.items():
            name = STORE["SOURCES"][mode][0]
            STORE["verify_bytes"](mode, bundle.read(artwork_prefix + name), info)
        corrupt = bundle.testzip()
        if corrupt is not None:
            raise ValueError("Corrupt ZIP entry: " + corrupt)
    print("Verified exact archive revision, required resources, prebuilt checksums and ZIP integrity")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: verify-integration-bundle.py SHA ZIP")
    verify(sys.argv[1], sys.argv[2])
