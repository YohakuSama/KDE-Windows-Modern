#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Fail closed on incomplete, stale, corrupt or redundant private theme ZIPs."""
from collections import Counter
from pathlib import Path, PurePosixPath
import hashlib
import json
import re
import sys
from zipfile import ZipFile

# runpy-based tests and direct invocation use the same runtime resource selector.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from native_assets_index import mapped_resource_entries, verify_reference_index


# Keep installation, upgrade, rollback, runtime checks, licence and artwork.
# Exclude only known development material; upstream build sources stay intact.
DEV_PATHS = (
    "tests", ".github", "plans", "AGENTS.md", "CLAUDE.md",
    ".editorconfig", ".shellcheckrc", "CONTRIBUTING.md", "PRODUCT.md",
    "verify-all.sh", "docs/PROGRESS.md", "docs/icon-pack",
    "docs/PANEL_UI_CONTRACT.md", "docs/PLASMA_SYSTEMTRAY_ARCHITECTURE.md",
    "docs/RELEASE.md", "docs/STARTMENU_PLAN.md", "docs/STYLE.md",
    "docs/SYSTEMTRAY_ARCHITECTURE.md", "docs/SYSTEMTRAY_DECISION.md",
    "docs/WINDOWS11_FIDELITY.md", "docs/NATIVE_COVERAGE.md",
    "docs/windows11-resource-index.json",
    "scripts/ci-build.sh", "scripts/check-qml-syntax.sh",
    "scripts/capture-screenshots.sh", "scripts/commit-icons.sh",
    "scripts/gen-switch-svg.py", "scripts/icon-coverage.py",
    "scripts/inspect-shell-resources.py", "scripts/package-plugins.sh",
    "scripts/package.sh", "scripts/release.sh", "scripts/store",
    "scripts/update-plm.sh", "scripts/update-previews.sh",
    "scripts/verify-integration-bundle.py", "scripts/verify-owner-bundle.py",
)


def archive_excludes():
    return [*(":(exclude,literal)" + p for p in DEV_PATHS),
            ":(exclude,glob)View-*.png", ":(exclude,glob)plasma/**/tests/**"]


def is_development_file(name):
    parts = PurePosixPath(name).parts
    return (not parts
            or any(name == p or name.startswith(p + "/") for p in DEV_PATHS)
            or (len(parts) == 1 and re.fullmatch(r"View-.*\.png", name))
            or (parts[0] == "plasma" and "tests" in parts[1:-1])
            or any(p in (".git", "__pycache__", "wm-build") for p in parts))


def verify_resource_index(z, prefix, index, mapping):
    """Require exactly the inputs the indexed importer consumes, with hashes."""
    expected = mapped_resource_entries(index, mapping)
    actual = {name[len(prefix):] for name in z.namelist()
              if name.startswith(prefix) and not z.getinfo(name).is_dir()}
    if actual - (set(expected) | {"resource-manifest.json", "RESOURCE-COMMIT"}):
        raise ValueError("Unused native resource in owner ZIP")
    for path, (digest, size) in expected.items():
        try:
            info = z.getinfo(prefix + path)
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


def verify(revision, filename):
    filename = Path(filename)
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("Expected full Git commit SHA")
    with ZipFile(filename) as z:
        members = [i.filename for i in z.infolist() if not i.is_dir()]
        if any(n > 1 for n in Counter(members).values()):
            raise ValueError("Duplicate ZIP members")
        roots = {PurePosixPath(n).parts[0] for n in members}
        if len(roots) != 1 or any(PurePosixPath(n).is_absolute() or ".." in PurePosixPath(n).parts for n in members):
            raise ValueError("Invalid archive paths")
        prefix = next(iter(roots)) + "/"
        for name in members:
            if not name.startswith(prefix) or is_development_file(name[len(prefix):]):
                raise ValueError("Development payload in owner ZIP: " + name)
        native = "native-resources/"
        required = (
            "INTEGRATION-BUILD", "install.sh", "install-nixos.sh",
            "uninstall.sh", "third_party/plasma-login-manager/CMakeLists.txt",
            "nix/test-runtime.nix", "scripts/prepare-native-assets.sh",
            "scripts/import-windows-assets.py", "scripts/native-assets-map.json",
            "scripts/native_assets_index.py", "scripts/native_assets_input.py",
            "scripts/stage-native-resources.sh",
            "scripts/install-icons.sh", "scripts/install-themes.sh",
            "scripts/install-sounds.sh", "scripts/verify-nixos-runtime.py",
            "plasma/applets/org.kde.windowsmodern.systemtray/systemtray.cpp",
            "plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/PanelStatusGlyph.qml",
            "plasma/applets/org.kde.windowsmodern.icontasks/CMakeLists.txt",
            "plasma/containmentactions/org.kde.windowsmodern.contextmenu/CMakeLists.txt",
            "bundled-store-artwork/manifest.json",
            native + "RESOURCE-COMMIT", native + "resource-manifest.json",
            native + "original/Windows/Web/Wallpaper/Windows/img0.jpg",
            native + "original/Windows/Web/Wallpaper/Windows/img19.jpg",
            native + "original/Windows/Web/Screen/img100.jpg",
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
        raw_index = z.read(prefix + native + "resource-manifest.json")
        verify_reference_index(raw_index)
        mapping = json.loads(z.read(prefix + "scripts/native-assets-map.json"))
        checked_resources = verify_resource_index(z, prefix + native, json.loads(raw_index), mapping)
        for directory in ("png/", "original/Windows/Media/"):
            if not any(n.startswith(prefix + native + directory) for n in members):
                raise ValueError("Missing resource directory: " + directory)
        corrupt = z.testzip()
        if corrupt is not None:
            raise ValueError("Corrupt ZIP member: " + corrupt)
    print(f"Verified private owner ZIP: {filename.stat().st_size:,} bytes, {revision}, "
          f"{checked_resources} indexed resources")


if __name__ == "__main__":
    if sys.argv[1:] == ["--archive-excludes"]:
        print("\n".join(archive_excludes()))
        raise SystemExit(0)
    if len(sys.argv) != 3:
        raise SystemExit("usage: verify-owner-bundle.py SHA ZIP")
    verify(sys.argv[1], sys.argv[2])
