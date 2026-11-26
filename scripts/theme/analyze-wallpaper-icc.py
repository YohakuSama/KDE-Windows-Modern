#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Offline comparison of ICC candidates against the archived DecodeProfile capture."""
import argparse
import base64
import gzip
import hashlib
from io import BytesIO
import json
from pathlib import Path
import re
import runpy
import zlib

from PIL import Image, ImageCms, __version__ as pillow_version

ROOT = Path(__file__).resolve().parents[2]
NAMES = ("none", "srgb", "linear-srgb")
FLAGS = ("default", "NOOPTIMIZE", "HIGHRESPRECALC", "BLACKPOINTCOMPENSATION",
         "FORCE_CLUT", "FORCE_CLUT+HIGHRESPRECALC")


def sha(data):
    return hashlib.sha256(data).hexdigest().upper()


def checked_buffer(entry):
    if (entry["width"], entry["height"], entry["order"]) != (256, 256, "top-down BGRX"):
        raise ValueError("Unexpected capture buffer format")
    data = gzip.decompress(base64.b64decode(entry["gzip_base64"], validate=True))
    if len(data) != 256 * 256 * 4 or sha(data) != entry["bitmap_sha256"] or set(data[3::4]) != {255}:
        raise ValueError("Capture buffer failed integrity check")
    return data


def checked_profile(collector, name, expected):
    match = re.search(r"'" + re.escape(name) + r"' = @\{\s+sha256 = '([0-9A-F]{64})'\s+payload = '([^']+)'", collector)
    if not match:
        raise ValueError("Missing synthetic profile: " + name)
    data = zlib.decompress(base64.b64decode(match[2], validate=True))
    if sha(data) != match[1] or sha(data) != expected:
        raise ValueError("Synthetic profile hash mismatch: " + name)
    return ImageCms.ImageCmsProfile(BytesIO(data))


def source_rows():
    # Exact DecodeProfile collector geometry; full decoded hash is checked below.
    background = ((20, 138, 20),) * 1280
    patch = ((225, 48, 48),) * 1280
    marker = ((255, 0, 255),) * 160 + background[160:]
    gray = tuple((x // 5,) * 3 for x in range(1280))
    red = tuple((x // 5, 0, 0) for x in range(1280))
    green = tuple((0, x // 5, 0) for x in range(1280))
    blue = tuple((0, 0, x // 5) for x in range(1280))
    return (patch, background, gray, red, green, blue, marker), (
        (0,) * 281 + (1,) * 169 + (2,) * 40 + (3,) * 40 + (4,) * 40
        + (5,) * 40 + (1,) * 90 + (6,) * 100)


def bitmap(rows, layout, mapping, prepare):
    packed = [b"".join(mapping[pixel] for pixel in row) for row in rows]
    return prepare(b"".join(packed[i] for i in layout), 1280, 800)[2]


def metrics(actual, reference):
    if len(actual) != len(reference) or len(actual) % 4:
        raise ValueError("Mismatched BGRX buffers")
    errors = [abs(a - b) for a, b in zip(actual, reference)]
    return {"sha256": sha(actual), "different_pixels": sum(any(errors[i:i+4]) for i in range(0, len(errors), 4)),
            "different_channels": sum(e != 0 for e in errors), "absolute_error_sum": sum(errors),
            "max_channel_error": max(errors, default=0)}


def reference_data(root):
    report = json.loads((root / "docs/windows11-26h2-wallpaper-probes-decode-profile.json").read_text(encoding="utf-8-sig"))
    if report["probe_set"] != "DecodeProfile" or report["baseline"]["windows_build"] != "26300.9974":
        raise ValueError("Unexpected calibration capture")
    samples = {s["image"]["icc_profile"]: s for s in report["samples"]}
    if set(samples) != set(NAMES) or len(report["samples"]) != len(NAMES):
        raise ValueError("Unexpected calibration profiles")
    collector = (root / "scripts/capture-windows-wallpaper-probes.ps1").read_text(encoding="utf-8-sig")
    prepare = runpy.run_path(str(root / "scripts/theme/sync-accent.py"))["prepare_opaque_wallpaper_bitmap"]
    rows, layout = source_rows()
    colors = sorted({pixel for row in rows for pixel in row})
    raw = {pixel: bytes(pixel) for pixel in colors}
    bgra = [b"".join(bytes((b, g, r, 255)) for r, g, b in row) for row in rows]
    source_hash = sha(b"".join(bgra[i] for i in layout))
    untagged = bitmap(rows, layout, raw, prepare)
    references = {}
    for name, sample in samples.items():
        boundary = sample["observation"]["wic_boundary"]
        if boundary["transcoded_status"] != "matched-controlled-opaque-regions":
            raise ValueError("Unverified cache: " + name)
        if source_hash != sample["image"]["pixel_validation"]["decoded_bgra_sha256"]:
            raise ValueError("Reconstructed source hash mismatch: " + name)
        if checked_buffer(boundary["source"]) != untagged:
            raise ValueError("Reconstructed untagged buffer mismatch: " + name)
        references[name] = checked_buffer(boundary["transcoded"])
    if references["none"] != untagged:
        raise ValueError("Untagged source and cache differ")
    return samples, collector, prepare, rows, layout, colors, source_hash, untagged, references


def analyze(root, target_paths):
    samples, collector, prepare, rows, layout, colors, source_hash, untagged, references = reference_data(root)
    targets = [("generated-srgb", ImageCms.createProfile("sRGB"), None)]
    for path in target_paths:
        data = path.read_bytes()
        targets.append((str(path), ImageCms.ImageCmsProfile(BytesIO(data)), sha(data)))
    result = {"pillow": pillow_version, "littlecms": ImageCms.core.littlecms_version,
              "source_bgra_sha256": source_hash, "verified_buffers": 6,
              "untagged": metrics(untagged, references["none"]), "candidates": []}
    with Image.new("RGB", (len(colors), 1)) as palette:
        palette.putdata(colors)
        for name in NAMES[1:]:
            profile = checked_profile(collector, name, samples[name]["image"]["pixel_validation"]["icc_profile_sha256"])
            cached = {}
            for target, target_profile, target_hash in targets:
                for intent in ImageCms.Intent:
                    for flag_name in FLAGS:
                        flags = 0
                        if flag_name != "default":
                            for item in flag_name.split("+"):
                                flags |= (ImageCms.Flags[item] if hasattr(ImageCms, "Flags") else ImageCms.FLAGS[item])
                        with ImageCms.profileToProfile(palette, profile, target_profile, renderingIntent=intent,
                                                       outputMode="RGB", flags=flags) as converted:
                            key = converted.tobytes()
                        if key not in cached:
                            mapping = {color: key[3*i:3*i+3] for i, color in enumerate(colors)}
                            cached[key] = metrics(bitmap(rows, layout, mapping, prepare), references[name])
                        result["candidates"].append({"source": name, "target": target, "target_sha256": target_hash,
                                                     "intent": intent.name, "flags": flag_name, **cached[key]})
    return result


def compare_native(root, report_path):
    samples, _, prepare, rows, layout, colors, _, _, references = reference_data(root)
    report = json.loads(report_path.read_text(encoding="utf-8-sig"))
    if report["schema_version"] != 1 or report["windows_build"] != "26300.9974":
        raise ValueError("Unexpected native report schema or Windows build")
    raw = b"".join(bytes(color) for color in colors)
    if (report["color_count"] != len(colors) or report["input_rgb_sha256"] != sha(raw)
            or base64.b64decode(report["input_rgb_base64"], validate=True) != raw):
        raise ValueError("Native report input colors differ from the calibration source")
    expected = {name: samples[name]["image"]["pixel_validation"]["icc_profile_sha256"] for name in NAMES[1:]}
    if report["sources"] != expected:
        raise ValueError("Native report source ICC hashes differ from the calibration source")
    targets = report["targets"]
    result = {"windows_build": report["windows_build"], "verified_buffers": 6,
              "verified_input_colors": len(colors), "targets": targets, "candidates": [], "failures": []}
    cached = {}
    seen = set()
    for candidate in report["candidates"]:
        source, target = candidate["source"], candidate["target"]
        if source not in expected or target not in targets or targets[target]["status"] != "ok":
            raise ValueError("Unexpected native candidate source or target")
        if candidate["target_sha256"] != targets[target]["sha256"]:
            raise ValueError("Native candidate target hash mismatch")
        metadata = {k: v for k, v in candidate.items() if k not in ("output_rgb_base64", "output_rgb_sha256")}
        identity = (source, target, candidate["api"], candidate["format"], candidate["intent"], candidate["flags"])
        if identity in seen:
            raise ValueError("Duplicate native candidate")
        seen.add(identity)
        if candidate["status"] == "error":
            result["failures"].append(metadata)
            continue
        if candidate["status"] != "ok":
            raise ValueError("Unexpected native candidate status")
        data = base64.b64decode(candidate["output_rgb_base64"], validate=True)
        if len(data) != len(raw) or sha(data) != candidate["output_rgb_sha256"]:
            raise ValueError("Native candidate output failed integrity check")
        key = (source, data)
        if key not in cached:
            mapping = {color: data[3*i:3*i+3] for i, color in enumerate(colors)}
            cached[key] = metrics(bitmap(rows, layout, mapping, prepare), references[source])
        result["candidates"].append({**metadata, "output_rgb_sha256": sha(data), **cached[key]})
    result["candidates"].sort(key=lambda item: (item["source"], item["absolute_error_sum"], item["max_channel_error"]))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", action="append", type=Path, default=[], help="Optional local ICC target (never bundled)")
    parser.add_argument("--native-report", type=Path, help="Compare a read-only Windows native API capture")
    args = parser.parse_args()
    if args.native_report and args.target:
        parser.error("--native-report and --target are mutually exclusive")
    result = compare_native(ROOT, args.native_report) if args.native_report else analyze(ROOT, args.target)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
