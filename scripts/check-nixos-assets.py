#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check that generated native assets match this source and mapping."""
import hashlib
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from native_assets_input import importer_fingerprint


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(root, source, mapping):
    root = root.resolve(strict=True)
    manifest = json.loads((root / "manifest.json").read_text())
    if manifest["mapping_sha256"] != digest(mapping):
        raise ValueError("mapping changed")
    if manifest.get("importer_sha256") != importer_fingerprint():
        raise ValueError("native resource importer changed")
    if manifest["indexed_source"]["manifest_sha256"] != digest(source / "resource-manifest.json"):
        raise ValueError("Windows resource manifest changed")
    outputs = manifest["outputs"]
    if not outputs or not (root / "wallpapers/Windows-modern/metadata.json").is_file():
        raise ValueError("incomplete generated assets")
    actual = {p.relative_to(root).as_posix() for p in root.rglob("*")
              if p.is_file() or p.is_symlink()}
    if actual != set(outputs) | {"manifest.json"}:
        raise ValueError("generated asset list changed")
    for name, info in outputs.items():
        p = root / name
        if p.is_symlink() or not p.resolve().is_relative_to(root) or not p.is_file():
            raise ValueError("invalid generated asset: " + name)
        if digest(p) != info["sha256"]:
            raise ValueError("generated asset changed: " + name)


if __name__ == "__main__":
    try:
        verify(*(Path(x) for x in sys.argv[1:]))
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f"Native assets require import: {exc}")
        raise SystemExit(1)
    print("Native assets: verified, unchanged")
