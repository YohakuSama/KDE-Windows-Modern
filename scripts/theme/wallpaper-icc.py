#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Replay two measured Windows RGB8 links, imported privately by the owner.

Only the exact source ICC hashes and Windows 26H2 registered-sRGB target
measured in the precision report are eligible. No Windows profile or
device-link payload is distributed. This does not generate arbitrary ICC
transforms, and does not replace the existing color-managed baseline.
"""
import argparse
import base64
from functools import lru_cache
import gzip
import hashlib
from io import BytesIO
import json
import os
from pathlib import Path
import struct
import tempfile

REPORT_SHA = "42F2C3D2FEBE30FC65B8F04F931CD154AFA520116DD5A40356C62AF9B5BDA76A"
TARGET_SHA = "2B3AA1645779A9E634744FAF9B01E9102B0C9B88FD6DECED7934DF86B949AF7E"
# Order is part of the private binary bundle format.
PROFILES = (
    ("srgb", "47FDA5236B74B9F11DA23C9834FAE1DBF0C0E195DEBEB22EFD147268C1CEC98C",
     "2E9CF49200C44791A7F70EBEF00A889E1EADABC8E992B5350CF1EE0CB1FAB1CD"),
    ("linear-srgb", "BC77188D9AABAF2F17730FBE0C3B3954579190954C6E273C35C33D52CFB193B6",
     "97E8FB0C2828CEB25B993BB6F6D2EA8967C292C86D843187CD9F01951F93FE36"),
)
LINK_SIZE = 205204
BUNDLE_SIZE = len(PROFILES) * LINK_SIZE
BUNDLE_SHA = "CDB09ED87EFC0B147BA64E705E2343CAC1C6E37828AC97B424937CE7B51DA6D2"
REPORT_LIMIT = 8 * 1024 * 1024
INPUT_SHA = "6B0C4D1258AB2EB58940BC3FE9236AFFC052081F6D14E4D9F296CA2BDBD0B550"
WIC_SHA = {
    "srgb": "EE7B6683A8D6C9395DCF89DBEF9E1016C8EC6D1B2DBCC07B651367AF4F64878F",
    "linear-srgb": "F35265C39A8D89B7B0AF1ED7755758084064601F017E65804EF6295BA00B2725",
}


def sha(data):
    return hashlib.sha256(data).hexdigest().upper()


def bundle_path():
    return (Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
            / "windows-modern" / "icc-replay-v1.bin")


def check_location(path):
    if any(p.is_symlink() for p in (path, path.parent, path.parent.parent)):
        raise ValueError("Refusing externally managed ICC replay data")


def read_bundle(path=None):
    path = bundle_path() if path is None else path
    if not path.exists() and not path.is_symlink():
        return None
    check_location(path)
    if not path.is_file() or path.stat().st_uid != os.getuid():
        raise ValueError("ICC replay data is not a user-owned file")
    with path.open("rb") as stream:
        data = stream.read(BUNDLE_SIZE + 1)
    if len(data) != BUNDLE_SIZE or sha(data) != BUNDLE_SHA:
        raise ValueError("Private ICC replay data failed SHA-256 verification")
    return data


def reference_identity():
    # Presence or removal invalidates the accent and material caches.
    return BUNDLE_SHA if read_bundle() is not None else None


def read_rgb8_tables(data):
    """Read the already measured RGB-to-RGB mft2 link, not a general ICC."""
    if (len(data) != LINK_SIZE or struct.unpack_from(">I", data)[0] != len(data)
            or data[12:24] != b"linkRGB RGB " or data[36:40] != b"acsp"):
        raise ValueError("Invalid RGB8 device-link header")
    count = struct.unpack_from(">I", data, 128)[0]
    end = 132 + 12 * count
    if end > len(data):
        raise ValueError("Invalid device-link tag count")
    matches = []
    for i in range(count):
        sig, offset, size = struct.unpack_from(">4sII", data, 132 + 12 * i)
        if offset < end or size < 8 or offset + size > len(data):
            raise ValueError("Invalid device-link tag extent")
        if sig == b"A2B0":
            matches.append(data[offset:offset + size])
    if len(matches) != 1:
        raise ValueError("Expected one A2B0 device-link table")
    tag = matches[0]
    if (len(tag) != 52 + 6 * 256 + 6 * 32**3 + 6 * 1024
            or tag[:4] != b"mft2" or tag[8:11] != bytes((3, 3, 32))
            or struct.unpack_from(">9i", tag, 12) != (65536, 0, 0, 0, 65536, 0, 0, 0, 65536)
            or struct.unpack_from(">HH", tag, 48) != (256, 1024)):
        raise ValueError("Unexpected measured RGB8 table layout")
    return (struct.unpack_from(">768H", tag, 52),
            struct.unpack_from(">98304H", tag, 52 + 6 * 256),
            struct.unpack_from(">3072H", tag, len(tag) - 6 * 1024))


def coordinate(value):
    code = value * 31 >> 5
    return code >> 11, 2048 if value == 65535 else code & 2047


class Rgb8Replay:
    """Scalar execution of the independently verified tetrahedral replay."""

    def __init__(self, tables):
        source, self.grid, self.target = tables
        self.coordinates = tuple(tuple(coordinate(v) for v in source[i:i + 256])
                                 for i in (0, 256, 512))

    def convert(self, red, green, blue):
        (r, fr), (g, fg), (b, fb) = (self.coordinates[0][red],
                                    self.coordinates[1][green],
                                    self.coordinates[2][blue])
        # The three fractional coordinates choose a tetrahedron. Equal
        # fractions telescope regardless of their relative ordering.
        (f1, s1), (f2, s2), (f3, s3) = sorted(
            ((fr, 32 * 32 * 3), (fg, 32 * 3), (fb, 3)), reverse=True)
        p0 = ((r * 32 + g) * 32 + b) * 3
        p1 = p0 + s1
        p2 = p1 + s2
        p3 = p2 + s3
        weights = 2048 - f1, f1 - f2, f2 - f3, f3
        result = []
        for channel in range(3):
            numerator = (self.grid[p0 + channel] * weights[0]
                         + self.grid[p1 + channel] * weights[1]
                         + self.grid[p2 + channel] * weights[2]
                         + self.grid[p3 + channel] * weights[3])
            index = min(1023, max(0, numerator >> 17))
            result.append(self.target[channel * 1024 + index] >> 8)
        return tuple(result)


def transform_for_profile(profile):
    digest = sha(profile)
    for i, (_, source_sha, _) in enumerate(PROFILES):
        if digest != source_sha:
            continue
        bundle = read_bundle()
        if bundle is None:
            return None
        link = bundle[i * LINK_SIZE:(i + 1) * LINK_SIZE]
        # Only resampling taps need conversion. Bound the cache even when
        # a wallpaper contains a large number of distinct colors.
        return lru_cache(maxsize=32768)(Rgb8Replay(read_rgb8_tables(link)).convert)
    return None


def checked_payload(entry, length, digest):
    if (entry["status"] != "ok" or entry["length"] != length or entry["sha256"] != digest
            or ("base64" in entry) == ("gzip_base64" in entry)):
        raise ValueError("Unexpected native ICC payload identity")
    if "base64" in entry:
        data = base64.b64decode(entry["base64"], validate=True)
    else:
        compressed = base64.b64decode(entry["gzip_base64"], validate=True)
        with gzip.GzipFile(fileobj=BytesIO(compressed)) as stream:
            data = stream.read(length + 1)
    if len(data) != length or sha(data) != digest:
        raise ValueError("Native ICC payload SHA-256 mismatch")
    return data


def extract_bundle(report_path):
    with report_path.open("rb") as stream:
        raw = stream.read(REPORT_LIMIT + 1)
    if len(raw) > REPORT_LIMIT or sha(raw) != REPORT_SHA:
        raise ValueError("Expected the exact previously verified Windows ICC precision report")
    report = json.loads(raw.decode("utf-8-sig"))
    if (report["windows_build"], report["target_sha256"], report["flags"]) != ("26300.9974", TARGET_SHA, 3):
        raise ValueError("Unexpected ICC reference identity")
    if report["sources"] != {name: source for name, source, _ in PROFILES}:
        raise ValueError("Unexpected source profile identities")
    colors = checked_payload(report["input_rgb"], 5120 * 3, INPUT_SHA)
    links = []
    for name, _, digest in PROFILES:
        item = report["results"][name]
        link = checked_payload(item["intents"]["1"]["link_profile"], LINK_SIZE, digest)
        reference = checked_payload(item["wic"], len(colors), WIC_SHA[name])
        # The owner's import itself verifies the scalar execution against
        # every recorded native calibration and mixed RGB8 sample.
        replay = Rgb8Replay(read_rgb8_tables(link))
        converted = b"".join(bytes(replay.convert(*colors[i:i + 3]))
                             for i in range(0, len(colors), 3))
        if converted != reference:
            raise ValueError("Scalar RGB8 replay differs from the recorded WIC output: " + name)
        links.append(link)
    bundle = b"".join(links)
    if sha(bundle) != BUNDLE_SHA:
        raise ValueError("Unexpected combined ICC reference hash")
    return bundle


def import_report(report_path):
    if os.geteuid() == 0:
        raise ValueError("Import ICC replay data as the desktop user")
    data = extract_bundle(report_path)
    path = bundle_path()
    check_location(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if read_bundle(path) is not None:
        return path
    # Atomic no-overwrite publication. A concurrent valid import is safe.
    with tempfile.NamedTemporaryFile(prefix=".wm-icc-", dir=path.parent) as temp:
        temp.write(data)
        temp.flush()
        try:
            os.link(temp.name, path)
        except FileExistsError:
            if read_bundle(path) is None:
                raise ValueError("ICC reference changed during import")
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--import-report", type=Path, required=True)
    args = parser.parse_args()
    try:
        path = import_report(args.import_report)
    except (OSError, ValueError, KeyError, TypeError, struct.error) as error:
        parser.exit(1, f"ICC replay import: {error}\n")
    print(f"Imported two verified local RGB8 links: {path}")


if __name__ == "__main__":
    main()
