#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check that wallpaper packages contain the owner's unchanged original image bytes."""
import hashlib
import json
from pathlib import Path
import sys

MAPPING = Path(__file__).with_name("native-assets-map.json")
# Original Git blobs from the reviewed resources/windows11 pin. A matching
# description or filename alone is not proof of original Windows artwork.
BLOOM = {
    "Web/Wallpaper/Windows/img0.jpg": "6569fdd746fc35ff5c45bac8430d6052244ccc50",
    "Web/Wallpaper/Windows/img19.jpg": "e7d139f77d2ab2df00b45ff84999d9a49cfd5f10",
}


def verify_package(native_root, package, package_id, mapping, expected_blobs=BLOOM):
    manifest = json.loads((native_root / "manifest.json").read_text(encoding="utf-8"))
    meta = json.loads((package / "metadata.json").read_text(encoding="utf-8"))
    plugin = meta["KPlugin"]
    if (plugin["Id"] != package_id
            or plugin["Description"] != "Local Windows reference image"):
        raise ValueError("Wallpaper is not the imported original: " + package_id)
    entries = [entry for entry in mapping["wallpapers"] if entry[0] == package_id]
    if len(entries) != 1:
        raise ValueError("Unknown wallpaper package: " + package_id)
    _, _, light, dark = entries[0]
    expected = {"images": light}
    if dark:
        expected["images_dark"] = dark
    for folder, original in expected.items():
        directory = package / "contents" / folder
        files = list(directory.iterdir())
        if len(files) != 1 or files[0].suffix.lower() != ".jpg" or files[0].is_symlink():
            raise ValueError("Unexpected wallpaper files: " + str(directory))
        image = files[0]
        data = image.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        key = "wallpapers/" + package_id + "/contents/" + folder + "/" + image.name
        output = manifest["outputs"][key]
        source = manifest["sources"][original]
        if (output["source"] != original or output["sha256"] != digest
                or source["sha256"] != digest or source["bytes"] != len(data)):
            raise ValueError("Wallpaper bytes differ from original: " + str(image))
        if original in expected_blobs:
            git_blob = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
            if git_blob != expected_blobs[original]:
                raise ValueError("Wallpaper differs from the pinned owner resource: " + original)
    actual_dirs = {p.name for p in (package / "contents").iterdir()
                   if p.is_dir() and p.name.startswith("images")}
    if actual_dirs != set(expected):
        raise ValueError("Unexpected wallpaper variant: " + package_id)
    return len(expected)


def main():
    try:
        root, package, name = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
        count = verify_package(root, package, name, json.loads(MAPPING.read_text()))
    except (OSError, ValueError, KeyError, TypeError, IndexError) as exc:
        print("Original wallpaper verification failed: " + str(exc), file=sys.stderr)
        return 1
    print(f"Verified {count} unchanged original wallpaper images: {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
