#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Replay measured Windows RGB8 links, imported privately by the owner.

The original two-profile bundle is unchanged. Additional RGB profiles
require an explicit import with matching native full-domain output hashes.
This is not independent CMM generation. No native profile or device-link
payload is distributed; unverified profiles keep the color-managed baseline.
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
import stat
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
FULL_REPORT_LIMIT = 64 * 1024 * 1024
FULL_MAGIC = b"WMICC002"
FULL_MAX_PROFILES = 6
MAX_LINK_SIZE = 16 * 1024 * 1024
TABLE_WORDS = 768 + 98304 + 3072
TABLE_SIZE = 2 * TABLE_WORDS
FULL_HEADER_SIZE = len(FULL_MAGIC) + 32 + 1
FULL_ENTRY_SIZE = 64 + TABLE_SIZE
FULL_BUNDLE_LIMIT = FULL_HEADER_SIZE + FULL_MAX_PROFILES * FULL_ENTRY_SIZE + 32
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


def full_bundle_path():
    return bundle_path().with_name("icc-replay-v2.bin")


def read_private_file(path, limit):
    if not path.exists() and not path.is_symlink():
        return None
    check_location(path)
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    except FileNotFoundError:
        return None
    with os.fdopen(fd, "rb") as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
            raise ValueError("ICC replay data is not a user-owned file")
        if info.st_size > limit:
            raise ValueError("ICC replay data exceeds its size bound")
        data = stream.read(limit + 1)
    if len(data) > limit:
        raise ValueError("ICC replay data exceeds its size bound")
    return data


def read_bundle(path=None):
    data = read_private_file(bundle_path() if path is None else path, BUNDLE_SIZE)
    if data is None:
        return None
    if len(data) != BUNDLE_SIZE or sha(data) != BUNDLE_SHA:
        raise ValueError("Private ICC replay data failed SHA-256 verification")
    return data


def full_bundle_entries(data):
    """Validate the bounded, canonical local receipt before exposing tables."""
    if (len(data) < FULL_HEADER_SIZE + FULL_ENTRY_SIZE + 32
            or len(data) > FULL_BUNDLE_LIMIT
            or data[:len(FULL_MAGIC)] != FULL_MAGIC
            or data[len(FULL_MAGIC):FULL_HEADER_SIZE-1] != bytes.fromhex(TARGET_SHA)):
        raise ValueError("Unexpected full-domain ICC bundle header")
    count = data[FULL_HEADER_SIZE - 1]
    if (not 1 <= count <= FULL_MAX_PROFILES
            or len(data) != FULL_HEADER_SIZE + count * FULL_ENTRY_SIZE + 32
            or hashlib.sha256(data[:-32]).digest() != data[-32:]):
        raise ValueError("Full-domain ICC bundle failed integrity verification")
    entries = {}
    previous = b""
    for i in range(count):
        offset = FULL_HEADER_SIZE + i * FULL_ENTRY_SIZE
        digest = data[offset:offset+32]
        if digest <= previous:
            raise ValueError("Duplicate or unordered full-domain ICC source")
        previous = digest
        native_digest = data[offset+32:offset+64]
        tables = data[offset+64:offset+FULL_ENTRY_SIZE]
        entries[digest.hex().upper()] = (native_digest, tables)
    return entries


def read_full_bundle(path=None):
    data = read_private_file(full_bundle_path() if path is None else path, FULL_BUNDLE_LIMIT)
    if data is not None:
        full_bundle_entries(data)
    return data


def reference_identity():
    # Preserve the old cache identity when no full-domain bundle is
    # installed. Either bundle's publication or removal invalidates both
    # existing accent and material caches.
    legacy = read_bundle()
    full = read_full_bundle()
    if full is None:
        return BUNDLE_SHA if legacy is not None else None
    return sha(FULL_MAGIC + (bytes.fromhex(BUNDLE_SHA) if legacy is not None else b"")
               + hashlib.sha256(full).digest())


def read_rgb8_tables(data, *, full_domain=False):
    """Read the measured RGB-to-RGB mft2 shape, not a general ICC."""
    if (not 132 <= len(data) <= MAX_LINK_SIZE or (not full_domain and len(data) != LINK_SIZE)
            or struct.unpack_from(">I", data)[0] != len(data)
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
    full = read_full_bundle()
    if full is not None:
        entry = full_bundle_entries(full).get(digest)
        if entry is not None:
            _, packed = entry
            values = struct.unpack(f">{TABLE_WORDS}H", packed)
            tables = values[:768], values[768:768 + 98304], values[768 + 98304:]
            return lru_cache(maxsize=32768)(Rgb8Replay(tables).convert)
    for i, (_, source_sha, _) in enumerate(PROFILES):
        if digest != source_sha:
            continue
        bundle = read_bundle()
        if bundle is not None:
            link = bundle[i * LINK_SIZE:(i + 1) * LINK_SIZE]
            return lru_cache(maxsize=32768)(Rgb8Replay(read_rgb8_tables(link)).convert)
        break
    # Unmeasured source profiles retain the existing ICC-managed path.
    return None


def checked_payload(entry, length, digest):
    if (entry["status"] != "ok" or entry["length"] != length or entry["sha256"] != digest
            or ("base64" in entry) == ("gzip_base64" in entry)):
        raise ValueError("Unexpected native ICC payload identity")
    if type(length) is not int or not 0 < length <= MAX_LINK_SIZE:
        raise ValueError("Invalid native ICC payload length")
    if "base64" in entry:
        if len(entry["base64"]) != 4 * ((length + 2) // 3):
            raise ValueError("Unexpected native ICC encoding length")
        data = base64.b64decode(entry["base64"], validate=True)
    else:
        if len(entry["gzip_base64"]) > 4 * ((length + 65536 + 2) // 3):
            raise ValueError("Oversized compressed ICC payload")
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


def digest_bytes(value):
    if (not isinstance(value, str) or len(value) != 64
            or any(c not in "0123456789ABCDEF" for c in value)):
        raise ValueError("Expected a canonical SHA-256 identity")
    return bytes.fromhex(value)


def verify_full_rgb8(replay, full):
    """Verify the actual scalar runtime, once at explicit local import."""
    if (full["status"], full["color_count"], full["order"]) != ("ok", 1 << 24, "ascending-rgb24"):
        raise ValueError("Missing full native RGB8 measurement")
    expected = digest_bytes(full["sha256"])
    slices = full["red_slice_sha256"]
    if not isinstance(slices, list) or len(slices) != 256:
        raise ValueError("Missing native red-slice hashes")
    expected_slices = tuple(map(digest_bytes, slices))
    overall = hashlib.sha256()
    convert = replay.convert
    for red in range(256):
        output = bytes(channel for green in range(256) for blue in range(256)
                       for channel in convert(red, green, blue))
        if hashlib.sha256(output).digest() != expected_slices[red]:
            raise ValueError(f"Native RGB8 replay differs at red slice {red}")
        overall.update(output)
    if overall.digest() != expected:
        raise ValueError("Native full RGB8 output hash differs")
    return expected


def extract_full_bundle(report_path, selected=()):
    with report_path.open("rb") as stream:
        raw = stream.read(FULL_REPORT_LIMIT + 1)
    if len(raw) > FULL_REPORT_LIMIT:
        raise ValueError("Oversized full-domain ICC report")
    report = json.loads(raw.decode("utf-8-sig"))
    if (report["schema_version"], report["windows_build"], report["target_sha256"],
            report["flags"], report["calibration_count"], report["mixed_count"]) != (
            2, "26300.9974", TARGET_SHA, 3, 1024, 4096):
        raise ValueError("Unexpected full-domain ICC reference identity")
    controls = {name: source for name, source, _ in PROFILES}
    sources = report["sources"]
    if (not len(controls) <= len(sources) <= FULL_MAX_PROFILES
            or any(sources.get(name) != digest for name, digest in controls.items())
            or set(sources) != set(report["results"])
            or len(set(sources.values())) != len(sources)):
        raise ValueError("Unexpected full-domain ICC source set")
    for name, digest in sources.items():
        digest_bytes(digest)
        if name not in controls and name != "custom-" + digest:
            raise ValueError("Unexpected custom ICC identity")
    chosen = set(selected) if selected else set(sources.values())
    if not chosen or not chosen <= set(sources.values()):
        raise ValueError("Requested ICC source is absent from the report")
    colors = checked_payload(report["input_rgb"], 5120 * 3, INPUT_SHA)
    # Always reproduce the established controls, even if the owner imports
    # only one additional profile. The report itself remains local.
    for name, expected in WIC_SHA.items():
        checked_payload(report["results"][name]["wic"], len(colors), expected)
    entries = []
    for name, digest in sorted(sources.items(), key=lambda item: item[1]):
        if digest not in chosen:
            continue
        item = report["results"][name]
        entry = item["intents"]["1"]
        if entry["status"] != "ok":
            raise ValueError("Native relative-colorimetric transform failed: " + name)
        link_entry = entry["link_profile"]
        digest_bytes(link_entry["sha256"])
        link = checked_payload(link_entry, link_entry["length"], link_entry["sha256"])
        tables = read_rgb8_tables(link, full_domain=True)
        replay = Rgb8Replay(tables)
        wic = item["wic"]
        digest_bytes(wic["sha256"])
        reference = checked_payload(wic, len(colors), wic["sha256"])
        if b"".join(bytes(replay.convert(*colors[i:i+3])) for i in range(0, len(colors), 3)) != reference:
            raise ValueError("Scalar replay differs from the calibration and mixed samples: " + name)
        native_digest = verify_full_rgb8(replay, item["full_rgb8"])
        packed = struct.pack(f">{TABLE_WORDS}H", *tables[0], *tables[1], *tables[2])
        entries.append(digest_bytes(digest) + native_digest + packed)
    data = FULL_MAGIC + bytes.fromhex(TARGET_SHA) + bytes((len(entries),)) + b"".join(entries)
    return data + hashlib.sha256(data).digest()


def import_full_report(report_path, selected=()):
    if os.geteuid() == 0:
        raise ValueError("Import ICC replay data as the desktop user")
    data = extract_full_bundle(report_path, selected)
    path = full_bundle_path()
    check_location(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    existing = read_full_bundle(path)
    if existing is not None:
        if existing != data:
            raise ValueError("Different full-domain bundle already installed; remove it explicitly first")
        return path
    with tempfile.NamedTemporaryFile(prefix=".wm-icc-", dir=path.parent) as temp:
        temp.write(data)
        temp.flush()
        os.fsync(temp.fileno())
        try:
            os.link(temp.name, path)
        except FileExistsError:
            if read_full_bundle(path) != data:
                raise ValueError("Full-domain ICC bundle changed during import")
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--import-report", type=Path)
    group.add_argument("--import-full-report", type=Path)
    parser.add_argument("--profile-sha256", action="append", default=[],
                        help="Select exact source identities from the full-domain report")
    args = parser.parse_args()
    if args.profile_sha256 and args.import_full_report is None:
        parser.error("--profile-sha256 requires --import-full-report")
    try:
        if args.import_full_report is not None:
            path = import_full_report(args.import_full_report, args.profile_sha256)
        else:
            path = import_report(args.import_report)
    except (OSError, ValueError, KeyError, TypeError, struct.error) as error:
        parser.exit(1, f"ICC replay import: {error}\n")
    print(f"Imported verified local RGB8 replay: {path}")


if __name__ == "__main__":
    main()
