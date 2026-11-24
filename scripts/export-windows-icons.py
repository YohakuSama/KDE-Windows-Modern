#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Export every icon group in the supplied MUN files to local ICOs and PNGs."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import struct

from native_assets_input import read_assets, source_manifest
from native_assets_pe import pe_resources


LIBRARIES = ("imageres.dll.mun", "imagesp1.dll.mun", "shell32.dll.mun")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def sort_key(value):
    return tuple((0, part) if isinstance(part, int) else (1, part) for part in value)


def group_frames(resources, key):
    data = resources[key]
    reserved, typ, count = struct.unpack_from("<HHH", data)
    if reserved != 0 or typ != 1 or count == 0 or len(data) < 6 + 14 * count:
        raise ValueError("Invalid group icon directory")
    frames = []
    for index in range(count):
        w, h, colors, zero, planes, bpp, size, rid = struct.unpack_from(
            "<BBBBHHIH", data, 6 + 14 * index
        )
        candidates = sorted(
            (k for k in resources if k[:2] == (3, rid) and len(k) == 3),
            key=sort_key,
        )
        if not candidates:
            raise ValueError(f"Missing RT_ICON resource {rid}")
        preferred = (3, rid, key[2])
        neutral = (3, rid, 0)
        selected = preferred if preferred in resources else (
            neutral if neutral in resources else candidates[0]
        )
        raw = resources[selected]
        if not raw or size != len(raw):
            raise ValueError(f"Invalid RT_ICON length for resource {rid}")
        frames.append({
            "entry": (w, h, colors, zero, planes, bpp),
            "raw": raw,
            "resource_id": rid,
            "language": selected[2],
        })
    return frames


def make_ico(frames):
    if not frames:
        raise ValueError("ICO requires at least one frame")
    entries, payload = [], []
    offset = 6 + 16 * len(frames)
    for frame in frames:
        raw = frame["raw"]
        entries.append(struct.pack("<BBBBHHII", *frame["entry"], len(raw), offset))
        payload.append(raw)
        offset += len(raw)
    return struct.pack("<HHH", 0, 1, len(frames)) + b"".join(entries + payload)


def read_libraries(source):
    if source.is_dir() and all((source / n).is_file() for n in LIBRARIES):
        data = read_assets(source, set(LIBRARIES))
        return {"SystemResources/" + name: data[name] for name in LIBRARIES}
    return read_assets(source, {"SystemResources/" + name for name in LIBRARIES})


def export_library(name, data, output):
    from PIL import Image

    resources = pe_resources(data, include_named=True)
    keys = sorted((k for k in resources if len(k) == 3 and k[0] == 14), key=sort_key)
    if not keys:
        raise ValueError(f"No icon groups in {name}")
    report = {"library": name, "group_variants": len(keys),
              "distinct_group_ids": len({k[1] for k in keys}), "groups": [], "errors": []}
    for index, key in enumerate(keys, 1):
        # Numeric directory names are independent of untrusted PE strings.
        rel = Path(name) / f"{index:04d}"
        folder = output / rel
        group = {"id": key[1], "language": key[2], "path": rel.as_posix(),
                 "frames": []}
        report["groups"].append(group)
        try:
            frames = group_frames(resources, key)
            folder.mkdir(parents=True)
            ico = make_ico(frames)
            (folder / "original.ico").write_bytes(ico)
            group["ico_sha256"] = digest(ico)
        except (ValueError, struct.error) as exc:
            report["errors"].append({"group": key[1], "language": key[2], "error": str(exc)})
            continue
        best = None
        for ordinal, frame in enumerate(frames, 1):
            w, h, _, _, _, bpp = frame["entry"]
            filename = f"{ordinal:02d}-{w or 256}x{h or 256}-{bpp}bpp.png"
            info = {"resource_id": frame["resource_id"], "language": frame["language"],
                    "width": w or 256, "height": h or 256, "bpp": bpp,
                    "sha256": digest(frame["raw"])}
            group["frames"].append(info)
            try:
                with Image.open(io.BytesIO(make_ico([frame]))) as image:
                    converted = image.convert("RGBA")
                    if converted.size != (w or 256, h or 256):
                        raise ValueError("Decoded dimensions do not match icon directory")
                    converted.save(folder / filename, format="PNG")
                info["preview"] = filename
                score = ((w or 256) * (h or 256), bpp)
                if best is None or score > best[0]:
                    best = (score, filename)
            except (OSError, ValueError, SyntaxError) as exc:
                report["errors"].append({"group": key[1], "language": key[2],
                                         "frame": ordinal, "error": str(exc)})
        if best is not None:
            group["preview"] = best[1]
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Archive or directory with the three original MUN libraries")
    parser.add_argument("--output", type=Path, required=True, help="New local output directory")
    args = parser.parse_args()
    source = args.source.expanduser().resolve()
    output = args.output.expanduser().resolve()
    if output.exists() or source == output or (source.is_dir() and source in output.parents):
        parser.error("Use a new output directory outside the original source directory")
    data = read_libraries(source)
    output.mkdir(parents=True)
    result = {"sources": source_manifest(data), "libraries": []}
    for name in LIBRARIES:
        result["libraries"].append(export_library(name, data["SystemResources/" + name], output))
    result["distinct_groups"] = sum(x["distinct_group_ids"] for x in result["libraries"])
    result["group_variants"] = sum(x["group_variants"] for x in result["libraries"])
    result["errors"] = sum(len(x["errors"]) for x in result["libraries"])
    (output / "index.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f'{result["distinct_groups"]} groups, {result["group_variants"]} language variants, '
          f'{result["errors"]} errors; index: {output / "index.json"}')
    # Preserve any recoverable original ICOs and disclose all decode failures.
    return 1 if result["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
