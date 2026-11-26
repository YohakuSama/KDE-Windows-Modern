#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Offline numerical investigation; never used by the theme runtime.

Requires NumPy and Pillow only for this diagnostic. Supply a local copy
of the exact measured standard RGB ICC profile; do not install it.
"""
import argparse
import base64
import gzip
import hashlib
from io import BytesIO
import itertools
import json
from pathlib import Path
import re
import runpy
import struct
import zlib

import numpy as np
from PIL import Image, ImageCms, __version__ as pillow_version

ROOT = Path(__file__).resolve().parents[2]
ROUND = {"floor": np.floor, "nearest": lambda x: np.floor(x + 0.5), "ceil": np.ceil}


def sha(data):
    return hashlib.sha256(data).hexdigest().upper()


def tags(data):
    if len(data) < 132 or data[36:40] != b"acsp" or struct.unpack_from(">I", data)[0] != len(data):
        raise ValueError("Invalid ICC header")
    count = struct.unpack_from(">I", data, 128)[0]
    if count > (len(data) - 132) // 12:
        raise ValueError("Invalid ICC tag count")
    result = {}
    for i in range(count):
        sig, offset, size = struct.unpack_from(">4sII", data, 132 + i * 12)
        if sig in result or offset < 132 + count * 12 or offset + size > len(data):
            raise ValueError("Invalid ICC tag table")
        result[sig] = data[offset:offset + size]
    return result


def matrix(profile):
    return np.column_stack([np.array(struct.unpack_from(">3i", profile[key], 8)) / 65536
                            for key in (b"rXYZ", b"gXYZ", b"bXYZ")])


def decode(profile, rgb):
    curve = profile[b"rTRC"]
    if curve[:4] != b"para" or curve != profile[b"gTRC"] or curve != profile[b"bTRC"]:
        raise ValueError("Expected synthetic shared parametric TRC")
    kind = struct.unpack_from(">H", curve, 8)[0]
    if kind == 0:
        return rgb ** (struct.unpack_from(">i", curve, 12)[0] / 65536)
    if kind != 3:
        raise ValueError("Unsupported synthetic TRC")
    g, a, b, c, d = np.array(struct.unpack_from(">5i", curve, 12)) / 65536
    return np.where(rgb >= d, (a * rgb + b) ** g, c * rgb)


def inputs(root, target_path):
    evidence = json.loads((root / "docs/windows11-26h2-icc-native-matches.json").read_text())
    if evidence["windows_build"] != "26300.9974":
        raise ValueError("Unexpected reference build")
    target = target_path.read_bytes()
    if len(target) != evidence["target"]["length"] or sha(target) != evidence["target"]["sha256"]:
        raise ValueError("Target ICC does not match the measured Windows profile")
    helper = runpy.run_path(str(root / "scripts/theme/analyze-wallpaper-icc.py"))
    rows, _ = helper["source_rows"]()
    colors = sorted({pixel for row in rows for pixel in row})
    raw = b"".join(map(bytes, colors))
    if len(colors) != evidence["color_count"] or sha(raw) != evidence["input_rgb_sha256"]:
        raise ValueError("Unexpected reference RGB inputs")
    collector = (root / "scripts/capture-windows-wallpaper-probes.ps1").read_text(encoding="utf-8-sig")
    sources, references = {}, {}
    for item in evidence["samples"]:
        name = item["source"]
        match = re.search(r"'" + re.escape(name) + r"' = @\{\s+sha256 = '([0-9A-F]{64})'\s+payload = '([^']+)'", collector)
        if match is None:
            raise ValueError("Missing synthetic input ICC")
        source = zlib.decompress(base64.b64decode(match[2], validate=True))
        output = gzip.decompress(base64.b64decode(item["output_rgb_gzip_base64"], validate=True))
        if sha(source) != match[1] or sha(source) != item["source_icc_sha256"]:
            raise ValueError("Input ICC hash mismatch")
        if len(output) != len(raw) or sha(output) != item["output_rgb_sha256"]:
            raise ValueError("Native RGB output integrity failure")
        sources[name] = source
        references[name] = np.frombuffer(output, np.uint8).reshape(-1, 3).astype(int)
    if set(sources) != {"srgb", "linear-srgb"}:
        raise ValueError("Unexpected reference sources")
    return target, raw, sources, references


def metrics(prediction, reference):
    error = np.abs(prediction.astype(int) - reference)
    return {"absolute_error_sum": int(error.sum()), "different_channels": int(np.count_nonzero(error)),
            "different_colors": int(np.count_nonzero(error.any(axis=1))), "max_channel_error": int(error.max())}


def quantize(values, bits, mode):
    return values if not bits else ROUND[mode](values * 2**bits) / 2**bits


def stages(bits):
    return [(0, "nearest")] + list(itertools.product(bits, ROUND))


def analyze(target, raw, sources, references):
    target_tags = tags(target)
    trc = target_tags[b"rTRC"]
    if trc[:4] != b"curv" or trc != target_tags[b"gTRC"] or trc != target_tags[b"bTRC"]:
        raise ValueError("Expected shared sampled destination TRC")
    count = struct.unpack_from(">I", trc, 8)[0]
    if count != 1024 or len(trc) != 12 + 2 * count:
        raise ValueError("Unexpected destination TRC length")
    curve = np.array(struct.unpack_from(f">{count}H", trc, 12)) / 65535
    if curve[0] != 0 or curve[-1] != 1 or np.any(np.diff(curve) <= 0):
        raise ValueError("Destination TRC must be strictly increasing")
    inverse = np.linalg.inv(matrix(target_tags))
    domain = np.linspace(0, 1, count)
    pixels = np.frombuffer(raw, np.uint8).reshape(-1, 3)
    result = {"target_sha256": sha(target), "target_size": len(target), "icc_version_hex": target[8:12].hex(),
              "preferred_cmm": target[4:8].decode("ascii"), "pcs": target[20:24].decode("ascii"),
              "target_matrix": matrix(target_tags).tolist(), "target_trc_points": count,
              "pillow": pillow_version, "littlecms": ImageCms.core.littlecms_version,
              "numpy": np.__version__, "color_count": len(pixels), "lcms": {}, "fixed": {}}
    candidates = {}
    for name, source in sources.items():
        ref = references[name]
        source_tags = tags(source)
        src_matrix = matrix(source_tags)
        flags = ("default", "NOOPTIMIZE", "HIGHRESPRECALC", "BLACKPOINTCOMPENSATION", "FORCE_CLUT", "FORCE_CLUT+HIGHRESPRECALC")
        source_profile = ImageCms.ImageCmsProfile(BytesIO(source))
        dest_profile = ImageCms.ImageCmsProfile(BytesIO(target))
        lcms = []
        with Image.frombytes("RGB", (len(pixels), 1), raw) as image:
            for intent, flag in itertools.product(ImageCms.Intent, flags):
                value = 0
                for item in flag.split("+"):
                    if item != "default":
                        value |= ImageCms.Flags[item]
                with ImageCms.profileToProfile(image, source_profile, dest_profile, renderingIntent=intent,
                                               flags=value, outputMode="RGB") as output:
                    pred = np.frombuffer(output.tobytes(), np.uint8).reshape(-1, 3)
                    lcms.append({"intent": intent.name, "flags": flag, **metrics(pred, ref)})
        result["lcms"][name] = lcms
        # Keep all options shared across profiles. Do not tune individual RGB values.
        for scale, (sbits, sr), (xbits, xr), (dbits, dr), outscale, outr in itertools.product(
                (255, 256), stages((10, 12, 14, 15, 16)), stages((10, 12, 14, 15, 16)),
                stages((9, 10, 11, 12, 16)), (255, 256), ("floor", "nearest")):
            linear = quantize(decode(source_tags, pixels / scale), sbits, sr)
            xyz = quantize(linear @ src_matrix.T, xbits, xr)
            dest = quantize(xyz @ inverse.T, dbits, dr)
            encoded = np.interp(dest.clip(0, 1), curve, domain)
            pred = ROUND[outr](encoded * outscale + 1e-9).clip(0, 255)
            key = (scale, sbits, sr, xbits, xr, dbits, dr, outscale, outr)
            candidates.setdefault(key, {})[name] = metrics(pred, ref)
    rank = sorted(candidates, key=lambda k: sum(v["absolute_error_sum"] for v in candidates[k].values()))
    fields = ("input_scale", "source_bits", "source_round", "xyz_bits", "xyz_round", "destination_bits", "destination_round", "output_scale", "output_round")
    def entry(key):
        return {"parameters": dict(zip(fields, key)), "results": candidates[key]}
    result["fixed"] = {"shared_parameter_sets": len(candidates), "comparisons": len(candidates) * len(sources),
                       "exact_parameter_sets": sum(all(v["max_channel_error"] == 0 for v in row.values()) for row in candidates.values()),
                       "best_shared": [entry(k) for k in rank[:10]],
                       "baseline": entry((255, 0, "nearest", 0, "nearest", 0, "nearest", 255, "nearest")),
                       "binary_output_only": entry((255, 0, "nearest", 0, "nearest", 0, "nearest", 256, "floor"))}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", required=True, type=Path, help="Local hash-matching ICC profile")
    args = parser.parse_args()
    print(json.dumps(analyze(*inputs(ROOT, args.target)), indent=2))


if __name__ == "__main__":
    main()
