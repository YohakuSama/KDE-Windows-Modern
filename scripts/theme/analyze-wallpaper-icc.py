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
import struct
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


def alpha_probe_rgba(patch_alpha):
    """Recreate the controlled DecodeAlphaProfile pixels, not a user image."""
    if patch_alpha not in (1, 128):
        raise ValueError("Unexpected probe alpha")
    red, blue, green, purple, magenta = (
        bytes.fromhex(color) for color in ("E13030", "3030E1", "148A14", "A03CD0", "FF00FF"))
    rows = []
    for y in range(800):
        if y < 281:
            row = (red + bytes((patch_alpha,))) * 1280
        elif 450 <= y < 610:
            band = (y - 450) // 40
            parts = []
            for level in range(256):
                alternate = (y + level) % 2
                if band < 2:
                    pixel = (red if band == 0 else blue) + bytes((level,))
                elif band == 2:
                    pixel = red + bytes((255,)) if alternate else blue + bytes((0,))
                else:
                    pixel = green + bytes((128,)) if alternate else purple + bytes((1,))
                parts.append(pixel * 5)
            row = b"".join(parts)
        elif y >= 700:
            row = (magenta + bytes((255,))) * 160 + (green + bytes((255,))) * 1120
        else:
            row = (green + bytes((255,))) * 1280
        rows.append(row)
    return b"".join(rows)


def checked_alpha_buffer(entry, expected_source):
    if ((entry["source_width"], entry["source_height"], entry["width"], entry["height"],
         entry["order"], entry["pixel_format"], entry["interpolation_mode"])
            != (1280, 800, 256, 256, "top-down BGRX", "32bppBGR", 1)
            or entry["source_sha256"] != expected_source):
        raise ValueError("Unexpected alpha capture dimensions or source identity")
    limit = 256 * 256 * 4
    encoded = entry["gzip_base64"]
    if len(encoded) > 4 * ((limit + 65536 + 2) // 3):
        raise ValueError("Oversized alpha buffer")
    with gzip.GzipFile(fileobj=BytesIO(base64.b64decode(encoded, validate=True))) as stream:
        data = stream.read(limit + 1)
    if len(data) != limit or sha(data) != entry["bitmap_sha256"]:
        raise ValueError("Alpha capture buffer failed integrity check")
    return data


def alpha_metrics(actual, reference):
    return {**metrics(actual, reference),
            "different_markers": sum(a != b for a, b in zip(actual[3::4], reference[3::4])),
            "different_rgb_pixels": sum(actual[i:i+3] != reference[i:i+3]
                                        for i in range(0, len(actual), 4))}


def map_alpha_rgb(data, transform, bgr=False, preserve_hidden=True):
    """Apply a candidate straight RGB transform while preserving alpha."""
    output = bytearray(data)
    cache = {}
    for i in range(0, len(data), 4):
        if preserve_hidden and not data[i+3]:
            # Hidden RGB is not observable after premultiplication, but
            # it can distinguish full-resolution cache construction.
            continue
        key = data[i:i+3]
        if key not in cache:
            converted = bytes(transform(*(key[::-1] if bgr else key)))
            cache[key] = converted[::-1] if bgr else converted
        output[i:i+3] = cache[key]
    return bytes(output)


def alpha_palette_metrics(runtime, bitmap, capture):
    measured = capture["native_wallpaper_color_api"]
    argb = measured["argb"]
    if (measured["status"] != "ok" or not measured["argb_matches_image_color"]
            or not measured["rgb_matches_dwm_colorization"]
            or not re.fullmatch(r"0x[0-9A-Fa-f]{8}", argb)):
        raise ValueError("Missing verified native colorization reference")
    roles = ("Accent", *runtime["PRESET_SHADE_ROLES"])
    observed = {}
    for role in roles:
        value = capture["appearance"]["colors_argb"][role]
        if not re.fullmatch(r"#FF[0-9A-Fa-f]{6}", value):
            raise ValueError("Expected an opaque native shade")
        observed[role] = "#" + value[3:].upper()

    def shade_difference(candidate):
        try:
            palette = runtime["derive_automatic_palette"](candidate)
        except ValueError as error:
            return {"status": "outside-reviewed-range", "reason": str(error)}
        return {"status": "compared", "different_roles": {
            role: {"candidate": palette[role], "native": observed[role]}
            for role in roles if palette[role] != observed[role]}}

    # Independently compare shades from native RGB, so a decoder mismatch
    # cannot be mistaken for a seven-role palette error.
    result = {"native_argb": argb, "native_rgb_shades": shade_difference("#" + argb[4:])}
    statistics = runtime["derive_weighted_wallpaper_bitmaps"](((256, 256, bitmap),))
    if statistics is None:
        return {**result, "status": "no-sampled-group"}
    seed, alpha = statistics
    candidate = runtime["normalize_weighted_wallpaper_seed"](seed)
    predicted = f"0x{alpha:02X}{candidate[1:]}"
    return {**result, "status": "compared", "weighted_seed": seed,
            "candidate_argb": predicted, "matches_native_argb": predicted.upper() == argb.upper(),
            "candidate_shades": shade_difference(candidate)}


# Table identities are independent of the generated device-link header.
# Both the original precision capture and the later full-domain capture
# contain these exact two RGB8 table sets.
ALPHA_CONTROL_TABLE_SHA = {
    "srgb": "97E7346083017BD0E85A33FF4A95B2B358494328EE144C5C1DCCD4551452B283",
    "linear-srgb": "DFA3F6063DDC61DCDB6D9A221F4BC837377F741EA6DA168B539316824821790D",
}
ALPHA_FULL_RGB8_SHA = {
    "srgb": "FD5EEB3579A1F00177FF32350870FB4AB020A76E393B8FD3A432009E0FC0D86F",
    "linear-srgb": "89A60E70F2990F0AC205BB194D59E8074D41A5ED92CA25DF3183F058C3964349",
}


def alpha_control_replays(native, precision_path):
    """Use either measured report without publishing local runtime data.

    For schema 2, require the same exact previously reviewed control tables,
    not arbitrary generated links or the synthetic curve-control profiles.
    Recheck the scalar calibration samples. The native whole-domain hashes
    identify the archived measurements; this is not a fresh exhaustive run.
    """
    limit = native["FULL_REPORT_LIMIT"]
    with precision_path.open("rb") as stream:
        raw = stream.read(limit + 1)
    if len(raw) > limit:
        raise ValueError("Oversized precision report")
    report = json.loads(raw.decode("utf-8-sig"))
    schema = report["schema_version"]
    if schema == 1:
        if sha(raw) != "42F2C3D2FEBE30FC65B8F04F931CD154AFA520116DD5A40356C62AF9B5BDA76A":
            raise ValueError("Unexpected historical precision report")
    elif schema == 2:
        if (report["windows_build"], report["target_sha256"], report["flags"],
                report["calibration_count"], report["mixed_count"]) != (
                "26300.9974", native["TARGET_SHA"], 3, 1024, 4096):
            raise ValueError("Unexpected precision reference identity")
    else:
        raise ValueError("Unsupported ICC precision report schema")

    checked = native["checked_payload"]
    colors = checked(report["input_rgb"], 5120 * 3, native["INPUT_SHA"])
    transforms = {}
    identities = {"none": None}
    for name, digest, original_link_sha in native["PROFILES"]:
        if report["sources"].get(name) != digest:
            raise ValueError("Unexpected alpha control source: " + name)
        item = report["results"][name]
        if schema == 2:
            full = item["full_rgb8"]
            if (full["status"], full["color_count"], full["order"], full["sha256"]) != (
                    "ok", 1 << 24, "ascending-rgb24", ALPHA_FULL_RGB8_SHA[name]):
                raise ValueError("Unexpected alpha control full-domain identity: " + name)
        entry = item["intents"]["1"]
        if entry["status"] != "ok":
            raise ValueError("Missing alpha control relative-colorimetric link")
        link = entry["link_profile"]
        data = checked(link, native["LINK_SIZE"], original_link_sha if schema == 1 else link["sha256"])
        table = native["read_rgb8_tables"](data)
        packed = struct.pack(f">{native['TABLE_WORDS']}H", *table[0], *table[1], *table[2])
        if sha(packed) != ALPHA_CONTROL_TABLE_SHA[name]:
            raise ValueError("Alpha control conversion table differs from reviewed evidence")
        convert = native["Rgb8Replay"](table).convert
        reference = checked(item["wic"], len(colors), native["WIC_SHA"][name])
        if b"".join(bytes(convert(*pixel)) for pixel in struct.iter_unpack("3B", colors)) != reference:
            raise ValueError("Alpha control scalar calibration differs from native WIC")
        transforms[name] = convert
        identities[name] = digest
    return transforms, identities


def alpha_roundtrip(data):
    """Model the candidate loss of precision through premultiplied RGBa."""
    with Image.frombytes("RGBA", (1280, 800), data) as image:
        with image.convert("RGBa") as premultiplied:
            with premultiplied.convert("RGBA") as restored:
                return restored.tobytes()


def alpha_decoded_hash(data):
    with Image.frombytes("RGBA", (1280, 800), data) as image:
        return sha(image.tobytes("raw", "BGRA"))


def compare_alpha(root, report_path, precision_path):
    with report_path.open("rb") as stream:
        raw = stream.read(16 * 1024 * 1024 + 1)
    if len(raw) > 16 * 1024 * 1024:
        raise ValueError("Oversized alpha probe report")
    report = json.loads(raw.decode("utf-8-sig"))
    if (report["probe_set"] != "DecodeAlphaProfile"
            or report["baseline"]["windows_build"] != "26300.9974"
            or not report["restoration"]["wallpaper_path_verified"]
            or not report["restoration"]["palette_matches_baseline"]):
        raise ValueError("Unexpected or unrestored alpha probe capture")
    samples = {(s["image"]["icc_profile"], s["image"]["patch_alpha"]): s
               for s in report["samples"]}
    if len(report["samples"]) != 6 or set(samples) != {
            (name, alpha) for name in NAMES for alpha in (1, 128)}:
        raise ValueError("Incomplete or duplicate alpha probe set")
    runtime = runpy.run_path(str(root / "scripts/theme/sync-accent.py"))
    native = runpy.run_path(str(root / "scripts/theme/wallpaper-icc.py"))
    # Read the owner's verified control tables from either precision
    # report. Do not publish or import any native data into the runtime.
    links, identities = alpha_control_replays(native, precision_path)
    result = {"windows_build": report["baseline"]["windows_build"], "samples": {}}
    for (name, alpha), sample in samples.items():
        probe, observation = sample["image"], sample["observation"]
        capture = observation["capture"]
        source_hash = capture["appearance"]["source_wallpaper_sha256"]
        boundary = observation["wic_boundary"]
        validation = probe["pixel_validation"]
        if ((sample["width"], sample["height"]) != (1280, 800)
                or capture["windows_build"] != "26300.9974"
                or capture["accent_mode_registry"] != "Automatic"
                or capture["accent_mode_registry_conflict"]
                or not observation["registered_source_matches"]
                or capture["appearance"]["registered_wallpaper_sha256"] != source_hash
                or validation["icc_profile_sha256"] != identities[name]
                or not probe["alpha_calibration"] or probe["profile_calibration"]):
            raise ValueError("Unexpected alpha probe identity")
        pixels = alpha_probe_rgba(alpha)
        raw_hash = alpha_decoded_hash(pixels)
        if (not validation["decoded_bgra_matches"]
                or raw_hash != validation["expected_bgra_sha256"]
                or raw_hash != validation["decoded_bgra_sha256"]
                or raw_hash != boundary["source"]["decoded_bgra_sha256"]):
            raise ValueError("Reconstructed alpha probe differs from native source")

        def prepare(data):
            with Image.frombytes("RGBA", (1280, 800), data) as image:
                with image.convert("RGBa") as premultiplied:
                    return runtime["prepare_premultiplied_wallpaper_bitmap"](
                        premultiplied.tobytes(), 1280, 800)[2]

        untagged = prepare(pixels)
        source = checked_alpha_buffer(boundary["source"], source_hash)
        row = {"source_preparation": alpha_metrics(untagged, source),
               "cache_status": boundary["transcoded_status"]}
        result["samples"][f"{name}-{alpha}"] = row
        if boundary["transcoded_status"] != "matched-controlled-opaque-regions":
            continue
        cache = observation["cache_observation"]["transcoded"]
        isolation = observation["isolation_reference"]
        before = isolation["caches"]["transcoded"]
        cache_hash = cache["sha256"]
        baseline = report["baseline"]
        if (cache["status"] != "ok" or before["status"] != "ok"
                or cache_hash == before["sha256"]
                or isolation["wallpaper_sha256"] != baseline["appearance"]["registered_wallpaper_sha256"]
                or isolation["native_argb"] != baseline["native_wallpaper_color_api"]["argb"]):
            raise ValueError("Transcoded cache lacks independent isolation evidence")
        reference = checked_alpha_buffer(boundary["transcoded"], cache_hash)
        # A settled registered source and changed cache are useful pixel
        # evidence, but unchanged native colorization may still be stale.
        palette_verified = (observation["stable_captures"] >= 2
                            and observation["registered_wallpaper_changed_since_previous"]
                            and observation["native_argb_changed_from_reference"]
                            and capture["native_wallpaper_color_api"]["argb"] != isolation["native_argb"])

        def colorization(bitmap):
            if not palette_verified:
                return {"status": "inconclusive-native-colorization"}
            return alpha_palette_metrics(runtime, bitmap, capture)

        row["native_cache_analysis"] = colorization(reference)

        # The collector also hashes the full decoded cache frame when WIC
        # exposes straight BGRA. Compare that boundary independently of
        # the 256x256 scaled buffer. An exact cache-frame match is stronger
        # evidence of conversion order; a missing frame hash is inconclusive.
        roundtrip = alpha_roundtrip(pixels)
        frame_candidates = {"unchanged": raw_hash,
                            "premultiply_roundtrip": alpha_decoded_hash(roundtrip)}
        if name == "none":
            candidates = {"untagged": untagged}
        else:
            transform = links[name]
            converted_preserved = map_alpha_rgb(pixels, transform)
            converted = map_alpha_rgb(pixels, transform, preserve_hidden=False)
            restored_converted = map_alpha_rgb(roundtrip, transform)
            frame_candidates.update(
                straight_convert_preserve_hidden=alpha_decoded_hash(converted_preserved),
                straight_convert_all=alpha_decoded_hash(converted),
                premultiply_roundtrip_then_convert=alpha_decoded_hash(restored_converted),
                convert_then_premultiply_roundtrip=alpha_decoded_hash(alpha_roundtrip(converted)))
            candidates = {
                "convert_then_premultiply_and_scale": prepare(converted),
                "runtime_tap_conversion": runtime["_prepare_wallpaper_bitmap"](
                    pixels, 1280, 800, 4, transform)[2],
                "premultiply_roundtrip_then_convert_and_scale": prepare(restored_converted),
                "scale_then_convert": map_alpha_rgb(untagged, transform, bgr=True),
            }
        native_frame_hash = boundary["transcoded"].get("decoded_bgra_sha256")
        if native_frame_hash is not None:
            native["digest_bytes"](native_frame_hash)
        row["decoded_cache_frame"] = {
            "status": "compared" if native_frame_hash else "unavailable",
            "native_sha256": native_frame_hash,
            "candidate_sha256": frame_candidates,
            "matching_candidates": [label for label, digest in frame_candidates.items()
                                    if digest == native_frame_hash],
        }
        row["candidates"] = {
            label: {"cache": alpha_metrics(bitmap, reference),
                    "colorization": colorization(bitmap)}
            for label, bitmap in candidates.items()}
    return result


# These are the exact synthetic source and native output identities from
# the target-build family report, not embedded conversion tables.
FAMILY_LUT_FULL_SHA = {
    "D32E4F221D8FBA508546D930EC200C200AEAAAE95EA22E23331B68D3495BF1A4":
        "7DA3D42C3664A08A331095CF2C49526D2C2AB9DB6CFB84F20AE934B80AC0CDEA",
    "086832DEE2195FBFC5FAF48A48C30CF2301D70CBA9C92CA46C11E6257C5DBB18":
        "4B78538B0FC4C275B6DE3D48A87CBAF8089F14D8A32AC5DB2362FD0FED6C5075",
}
FAMILY_GRAY_SHA = {
    "gray-linear": ("FCA615D30B83A208A33AFB4A4FF7EAE18AD3F9BB66EE2872619ACA101A044AC4",
                    "B5643195AD00E72793FDDB40ADABA26617B894B24817C31149537AEE7B6065AF"),
    "gray-gamma22": ("CC2F4242F64AA4624D41A3853547F84BBF861A221C738D742959019169085B28",
                     "C3A571A6A7E554745A5417B4785F2C587053E998917BB0ED6D797B79380D1CB8"),
}


def compare_families(root, report_path, *, full_domain=False):
    """Validate the two measured LUT and two gray controls without publishing data."""
    native = runpy.run_path(str(root / "scripts/theme/wallpaper-icc.py"))
    # Reuse the existing exact matrix-control and reference identity checks.
    alpha_control_replays(native, report_path)
    with report_path.open("rb") as stream:
        raw = stream.read(native["FULL_REPORT_LIMIT"] + 1)
    if len(raw) > native["FULL_REPORT_LIMIT"]:
        raise ValueError("Oversized ICC family report")
    report = json.loads(raw.decode("utf-8-sig"))
    if report["schema_version"] != 2:
        raise ValueError("Expected schema 2 ICC family report")
    controls = {name: digest for name, digest, _ in native["PROFILES"]}
    lut_sources = {"custom-" + digest: digest for digest in FAMILY_LUT_FULL_SHA}
    if (report["sources"] != {**controls, **lut_sources}
            or set(report["results"]) != set(report["sources"])
            or set(report["synthetic_sources"]) != set(lut_sources)
            or set(report["gray8"]) != set(FAMILY_GRAY_SHA)):
        raise ValueError("Unexpected ICC family control set")

    checked = native["checked_payload"]
    colors = checked(report["input_rgb"], 5120 * 3, native["INPUT_SHA"])
    target = native["srgb_output_curve"]()
    lut_source = native["mft2_unity_curve"](256, 65534) * 3
    result = {"windows_build": report["windows_build"], "report_sha256": sha(raw),
              "rgb_lut": {}, "gray": {}}

    def tables_summary(tables, source):
        return {
            "input_entries": len(tables[0]), "grid_entries": len(tables[1]),
            "output_entries": len(tables[2]),
            "table_sha256": [native["_table_hash"](table) for table in tables],
            "generated_input_differences": sum(a != b for a, b in zip(source, tables[0])),
            "generated_output_differences": sum(a != b for a, b in zip(target, tables[2])),
            "grid_independently_generated": False,
        }

    for name, digest in lut_sources.items():
        entry = report["synthetic_sources"][name]
        checked(entry, entry["length"], digest)
        item = report["results"][name]
        relative = item["intents"]["1"]
        if relative["status"] != "ok":
            raise ValueError("Missing native relative LUT transform")
        link = relative["link_profile"]
        tables = native["read_rgb8_tables"](checked(link, link["length"], link["sha256"]),
                                            full_domain=True)
        replay = native["Rgb8Replay"](tables)
        wic = item["wic"]
        reference = checked(wic, len(colors), wic["sha256"])
        for method in ("direct", "link_replay"):
            checked(relative[method]["outputs"]["8to8"], len(colors), wic["sha256"])
        actual = b"".join(bytes(replay.convert(*pixel)) for pixel in struct.iter_unpack("3B", colors))
        full = item["full_rgb8"]
        if ((full["status"], full["color_count"], full["order"], full["sha256"])
                != ("ok", 1 << 24, "ascending-rgb24", FAMILY_LUT_FULL_SHA[digest])
                or len(full["red_slice_sha256"]) != 256):
            raise ValueError("Unexpected native LUT full-domain measurement")
        for value in full["red_slice_sha256"]:
            native["digest_bytes"](value)
        row = tables_summary(tables, lut_source)
        row.update(calibration_colors=len(colors) // 3,
                   calibration_different_channels=sum(a != b for a, b in zip(actual, reference)),
                   native_full_sha256=full["sha256"], full_domain_verified=False)
        if full_domain:
            native["verify_full_rgb8"](replay, full)
            row["full_domain_verified"] = True
        result["rgb_lut"][digest] = row

    for name, (profile_sha, wic_sha) in FAMILY_GRAY_SHA.items():
        item = report["gray8"][name]
        if (item["input_order"], item["output_order"]) != ("gray8-0-through-255", "rgb24"):
            raise ValueError("Unexpected gray ramp order")
        profile = checked(item["profile"], item["profile"]["length"], profile_sha)
        count = struct.unpack_from(">I", profile, 128)[0]
        end = 132 + 12 * count
        if end > len(profile):
            raise ValueError("Invalid gray profile directory")
        curves = [profile[offset:offset + size]
                  for sig, offset, size in struct.iter_unpack(">4sII", profile[132:end])
                  if sig == b"kTRC" and end <= offset <= len(profile) - size]
        if len(curves) != 1:
            raise ValueError("Missing measured gray kTRC")
        source = native["matrix_input_curve"](curves[0])
        link = item["relative_link"]
        tables = native["read_rgb8_tables"](checked(link, link["length"], link["sha256"]),
                                            source_channels=1)
        replay = native["Rgb8Replay"](tables)
        reference = checked(item["wic"], 768, wic_sha)
        actual = bytes(channel for code in range(256) for channel in replay.convert(code))
        generated = native["generate_gray_tables"](profile)
        generated_replay = native["Rgb8Replay"](generated)
        generated_actual = bytes(channel for code in range(256) for channel in generated_replay.convert(code))
        row = tables_summary(tables, source)
        row.update(grid_independently_generated=True,
                   generated_grid_differences=sum(a != b for a, b in zip(generated[1], tables[1])),
                   generated_rgb_differences=sum(a != b for a, b in zip(generated_actual, reference)),
                   gray_codes=256, different_channels=sum(a != b for a, b in zip(actual, reference)),
                   native_output_sha256=wic_sha, replay_sha256=sha(actual))
        result["gray"][name] = row
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", action="append", type=Path, default=[], help="Optional local ICC target (never bundled)")
    parser.add_argument("--native-report", type=Path, help="Compare a read-only Windows native API capture")
    parser.add_argument("--alpha-report", type=Path, help="Compare combined alpha/profile probe caches")
    parser.add_argument("--precision-report", type=Path, help="Verified ICC precision or full-RGB8 report for alpha comparison")
    parser.add_argument("--family-report", type=Path, help="Compare the measured RGB LUT and Gray ICC families")
    parser.add_argument("--full-domain", action="store_true", help="Enumerate all RGB8 inputs for the family report")
    args = parser.parse_args()
    if args.full_domain and not args.family_report:
        parser.error("--full-domain requires --family-report")
    if args.family_report:
        if args.alpha_report or args.precision_report or args.native_report or args.target:
            parser.error("--family-report excludes other modes")
        result = compare_families(ROOT, args.family_report, full_domain=args.full_domain)
    elif args.alpha_report:
        if not args.precision_report or args.native_report or args.target:
            parser.error("--alpha-report requires --precision-report and excludes other modes")
        result = compare_alpha(ROOT, args.alpha_report, args.precision_report)
    else:
        if args.precision_report or (args.native_report and args.target):
            parser.error("Choose a single diagnostic mode")
        result = compare_native(ROOT, args.native_report) if args.native_report else analyze(ROOT, args.target)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
