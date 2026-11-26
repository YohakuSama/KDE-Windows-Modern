#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Single fixed-point RGB8 ICC execution path for Windows wallpaper analysis.

Generate supported matrix/TRC tables independently. Full-domain verified
local tables supply otherwise unmeasured profile identities to the same
executor. No approximate secondary color engine or v1 runtime receipt.
"""
import argparse
import base64
from bisect import bisect_left
from functools import lru_cache
import gzip
import hashlib
from io import BytesIO
import json
import math
import os
from pathlib import Path
import stat
import struct
import tempfile

TARGET_SHA = "2B3AA1645779A9E634744FAF9B01E9102B0C9B88FD6DECED7934DF86B949AF7E"
# Original calibration controls, also checked when importing additional profiles.
PROFILES = (
    ("srgb", "47FDA5236B74B9F11DA23C9834FAE1DBF0C0E195DEBEB22EFD147268C1CEC98C",
     "2E9CF49200C44791A7F70EBEF00A889E1EADABC8E992B5350CF1EE0CB1FAB1CD"),
    ("linear-srgb", "BC77188D9AABAF2F17730FBE0C3B3954579190954C6E273C35C33D52CFB193B6",
     "97E8FB0C2828CEB25B993BB6F6D2EA8967C292C86D843187CD9F01951F93FE36"),
)
LINK_SIZE = 205204
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


def check_location(path):
    if any(p.is_symlink() for p in (path, path.parent, path.parent.parent)):
        raise ValueError("Refusing externally managed ICC replay data")


def full_bundle_path():
    return (Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
            / "windows-modern" / "icc-replay-v2.bin")


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
    # Only full-domain verified supplemental data participates in runtime
    # cache identity. The retired v1 receipt is never opened.
    full = read_full_bundle()
    return sha(full) if full is not None else None


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


# Standard sRGB target: the three XYZ colorants in signed 16.16 units.
# These are colorimetric parameters, not a native profile or captured LUT.
SRGB_COLORANTS = ((28578, 25241, 9376), (14581, 46981, 3972), (912, 6362, 46799))
D50 = (63190, 65536, 54061)
# Legacy registered sRGB v2 profile records D65 media white but its
# colorants are already D50-adapted. Relative intent uses those colorants.
D65_MEDIA_WHITE = (62289, 65536, 71372)
GENERATED_GRID_SHA = "61A243BB0A50A4B0346873DA3D9C6F20FDDC7EC2945DD8946B6DD2E8D93658B2"
GENERATED_OUTPUT_SHA = "1943A4178D0F62F28694CE524D529A944F04CBB4E7E9FC4722ABC906A13BF216"
GENERATED_SOURCE_SHA = {
    "47FDA5236B74B9F11DA23C9834FAE1DBF0C0E195DEBEB22EFD147268C1CEC98C": "888A2852424F361D9A87E68B17365304A7B49CFE4FCA63D22A0EFF13620F0ED3",
    "BC77188D9AABAF2F17730FBE0C3B3954579190954C6E273C35C33D52CFB193B6": "8B814990ADF93775BF8BFAF2C3A54DCEDE47D1F68E81809388E7E1D9624B24D6",
    "3633820C700F656C83A23C1D0DAA20214E73D040AB13E6B87262CEF513D0B5CA": "CDEAE3D012117A4CA09205FD85AC6674096EB179E1CC8FAE0A4287566A0F0E0F",
    "6A907D854C58B4625AADACA152438EE1BC857B46EE106D31381208493023B268": "A59D9DE387CF63271412822721FED6A6338EAD3F6EA0CB3A84E47E3DDA7EACE5",
}


class UnsupportedMatrixProfile(ValueError):
    """Outside the reviewed RGB matrix/TRC generation branch."""


def matrix_profile_tags(data):
    if (not isinstance(data, bytes) or not 132 <= len(data) <= 1024 * 1024
            or struct.unpack_from(">I", data)[0] != len(data)
            or data[8] not in (2, 4) or data[12:16] not in (b"mntr", b"scnr")
            or data[16:24] != b"RGB XYZ "
            or data[36:40] != b"acsp" or struct.unpack_from(">3i", data, 68) != D50):
        raise UnsupportedMatrixProfile("Expected a D50 RGB monitor or input matrix profile")
    count = struct.unpack_from(">I", data, 128)[0]
    end = 132 + 12 * count
    if count > 128 or end > len(data):
        raise UnsupportedMatrixProfile("Invalid matrix profile tag directory")
    tags = {}
    extents = []
    for sig, offset, size in struct.iter_unpack(">4sII", data[132:end]):
        if (sig in tags or offset % 4 or offset < end or size < 8
                or offset + size > len(data)):
            raise UnsupportedMatrixProfile("Invalid matrix profile tag extent")
        extent = (offset, offset + size)
        if any(extent != previous and extent[0] < previous[1] and previous[0] < extent[1]
               for previous in extents):
            raise UnsupportedMatrixProfile("Overlapping matrix profile tags")
        extents.append(extent)
        tags[sig] = data[offset:offset + size]
    # The native forward transform checks A2B1 and A2B0 before the matrix.
    # B2A tables describe the opposite direction and do not displace it.
    # Keep every forward LUT outside this generator.
    allowed = {b"rXYZ", b"gXYZ", b"bXYZ", b"rTRC", b"gTRC", b"bTRC", b"wtpt",
               b"desc", b"cprt", b"chad", b"chrm", b"dmnd", b"dmdd", b"tech",
               b"view", b"vued", b"lumi", b"meas", b"meta", b"bkpt",
               b"B2A0", b"B2A1", b"B2A2"}
    if set(tags) - allowed:
        raise UnsupportedMatrixProfile("ICC profile has unreviewed transform or metadata tags")
    white = tags.get(b"wtpt", b"")
    if (len(white) != 20 or white[:4] != b"XYZ "
            or struct.unpack_from(">3i", white, 8) not in (D50, D65_MEDIA_WHITE)):
        raise UnsupportedMatrixProfile("Media white outside the reviewed relative-intent branch")
    black = tags.get(b"bkpt")
    if black is not None and (len(black) != 20 or black[:4] != b"XYZ "
                              or struct.unpack_from(">3i", black, 8) != (0, 0, 0)):
        raise UnsupportedMatrixProfile("Unreviewed media black point")
    return tags


def matrix_colorants(tags):
    columns = []
    for key in (b"rXYZ", b"gXYZ", b"bXYZ"):
        value = tags.get(key, b"")
        if len(value) != 20 or value[:4] != b"XYZ ":
            raise UnsupportedMatrixProfile("Missing RGB colorant")
        columns.append(struct.unpack_from(">3i", value, 8))
    matrix = tuple(zip(*columns))
    if (any(not 0 <= v <= 131072 for row in matrix for v in row)
            or any(abs(sum(row) - white) > 16 for row, white in zip(matrix, D50))):
        raise UnsupportedMatrixProfile("RGB colorants outside the reviewed D50 matrix range")
    return matrix


def _round_signed_ratio(numerator, denominator):
    if denominator <= 0:
        raise UnsupportedMatrixProfile("Invalid matrix determinant")
    magnitude = (2 * abs(numerator) + denominator) // (2 * denominator)
    return -magnitude if numerator < 0 else magnitude


def _inverse_parts(matrix):
    a, b, c = zip(*matrix)

    def cross(x, y):
        return (x[1] * y[2] - x[2] * y[1], x[2] * y[0] - x[0] * y[2],
                x[0] * y[1] - x[1] * y[0])

    adj = (cross(b, c), cross(c, a), cross(a, b))
    det = sum(x * y for x, y in zip(a, adj[0]))
    if det <= 0:
        raise UnsupportedMatrixProfile("Expected a positive matrix determinant")
    return adj, det


@lru_cache(maxsize=4)
def build_matrix_grid(source, target):
    """Generate the staged 32-cube from signed ICC 16.16 colorants."""
    for matrix in (source, target):
        if (len(matrix) != 3 or any(len(row) != 3 for row in matrix)
                or any(type(v) is not int or abs(v) > 131072 for row in matrix for v in row)):
            raise UnsupportedMatrixProfile("ICC matrix outside signed 16.16 bounds")
    _inverse_parts(source)
    adj, det = _inverse_parts(target)
    if any(abs(v) * 2 * 65536 > 16 * det for row in adj for v in row):
        raise UnsupportedMatrixProfile("Destination inverse outside reviewed bounds")
    first = tuple(tuple(_round_signed_ratio(v * 16368, 2 * 65536) for v in row)
                  for row in source)
    second = tuple(tuple(_round_signed_ratio(v * 2 * 65536 * 16368, det) for v in row)
                   for row in adj)
    for matrix in (first, second):
        for row in matrix:
            low = sum(min(v, 0) for v in row) * 16384 + 511
            high = sum(max(v, 0) for v in row) * 16384 + 511
            if low < -(1 << 31) or high >= 1 << 31:
                raise UnsupportedMatrixProfile("Matrix accumulator outside signed 32-bit range")
    axis = tuple((i << 11) | (i << 6) | (i << 1) | (i >> 4) for i in range(32))
    identity = tuple(min(65535, (2047 + i * 262396) >> 12) for i in range(1024))

    def stage(rgb, matrix):
        r, g, b = (((v - (v >> 8)) * 257 >> 8) + 2 >> 2 for v in rgb)
        result = []
        for a, c, d in matrix:
            coordinate = min(261888, max(0, (r * a + g * c + b * d + 511) >> 10))
            index, fraction = coordinate >> 8, coordinate & 255
            result.append((identity[index] * (256 - fraction)
                           + identity[min(index + 1, 1023)] * fraction) >> 8)
        return result

    return tuple(v for r in axis for g in axis for b in axis
                 for v in stage(stage((r, g, b), first), second))


def matrix_input_curve(tag):
    """Generate the native 256-entry RGB8 curve for supported ICC TRCs."""
    if len(tag) < 12:
        raise UnsupportedMatrixProfile("Truncated RGB tone curve")
    if tag[:4] == b"curv":
        count = struct.unpack_from(">I", tag, 8)[0]
        if count >= 8192 or len(tag) != 12 + 2 * count:
            raise UnsupportedMatrixProfile("Sampled ICC curve exceeds native bounds")
        if count == 0:
            return tuple(i * 257 for i in range(256))
        samples = struct.unpack_from(f">{count}H", tag, 12)
        if count > 1:
            if any(a > b for a, b in zip(samples, samples[1:])):
                raise UnsupportedMatrixProfile("Nonmonotone sampled tone curve")
            # Native sampled-curve construction uses a Q18 step and Q15
            # position. A rounded position may hit the final sample exactly.
            step = ((count - 1) << 18) // 255
            result = []
            for code in range(256):
                position = (step * code + 4) >> 3
                i, f = position >> 15, position & 32767
                value = samples[i]
                if f:
                    delta = (samples[i + 1] - value) >> 1
                    value += ((delta * f >> 1) + 4095) >> 13
                result.append(value)
            return tuple(result)
        gamma = samples[0] / 256
        evaluate = lambda x: x if gamma == 1 else x ** gamma
    elif tag[:4] == b"para":
        kind = struct.unpack_from(">H", tag, 8)[0]
        sizes = (1, 3, 4, 5, 7)
        if kind >= len(sizes) or len(tag) != 12 + 4 * sizes[kind]:
            raise UnsupportedMatrixProfile("Invalid parametric tone curve")
        params = tuple(v / 65536 for v in struct.unpack_from(f">{sizes[kind]}i", tag, 12))
        gamma = params[0]
        if kind == 0:
            evaluate = lambda x: x if gamma == 1 else x ** gamma
        else:
            a, b = params[1:3]
            if a <= 0:
                raise UnsupportedMatrixProfile("Invalid parametric tone curve scale")
            if kind in (1, 2):
                threshold = -b / a
                offset = params[3] if kind == 2 else 0
                evaluate = lambda x: (a * x + b) ** gamma + offset if x >= threshold else offset
            else:
                c, d = params[3:5]
                e, f = params[5:7] if kind == 4 else (0, 0)
                if c < 0 or not 0 <= d <= 1 or a * d + b < 0:
                    raise UnsupportedMatrixProfile("Invalid parametric tone curve branch")
                evaluate = lambda x: (a * x + b) ** gamma + e if x >= d else c * x + f
    else:
        raise UnsupportedMatrixProfile("Unreviewed tone curve type")
    if not 0 < gamma <= 16:
        raise UnsupportedMatrixProfile("Tone curve gamma outside reviewed bounds")

    def sample(code):
        try:
            value = evaluate(code * (1.0 / 255.0))
        except (ArithmeticError, ValueError) as error:
            raise UnsupportedMatrixProfile("Invalid analytic tone curve") from error
        if not isinstance(value, (float, int)) or not math.isfinite(value):
            raise UnsupportedMatrixProfile("Invalid analytic tone curve")
        # Native analytic callbacks clamp to the normalized interval.
        return math.floor(min(1, max(0, value)) * 65535)

    anchors = [sample(code) for code in (*range(0, 256, 4), 255)]
    if any(a > b for a, b in zip(anchors, anchors[1:])):
        raise UnsupportedMatrixProfile("Nonmonotone analytic tone curve")
    result = [anchors[i // 4] + ((anchors[i // 4 + 1] - anchors[i // 4])
                                 * (i % 4) * 2 + 4) // 8 for i in range(252)]
    result.extend(anchors[63] + ((anchors[64] - anchors[63]) * (i - 252) * 2 + 3) // 6
                  for i in range(252, 256))
    # For exponents below one, the original generator evaluates the first
    # four input codes directly instead of interpolating from zero.
    if gamma < 1:
        result[:4] = [sample(i) for i in range(4)]
    if any(a > b for a, b in zip(result, result[1:])):
        raise UnsupportedMatrixProfile("Nonmonotone generated tone curve")
    return tuple(result)


def _table_hash(table):
    return sha(struct.pack(f">{len(table)}H", *table))


@lru_cache(maxsize=1)
def srgb_output_curve():
    # The measured registered-sRGB TRC equals these 1024 mathematically
    # sampled standard sRGB values, including every rounded 16-bit entry.
    def srgb_decode(x):
        return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4

    curve = tuple(math.floor(65535 * srgb_decode(i / 1023) + 0.5) for i in range(1024))
    values = []
    for i in range(1024):
        x = (i * 65535 + 511) // 1023
        k = min(1022, max(0, bisect_left(curve, x) - 1))
        value = k * 65536 // 1023 + (x - curve[k]) * 65536 // ((curve[k + 1] - curve[k]) * 1023)
        values.append(min(65535, max(0, value)))
    result = tuple(values) * 3
    if _table_hash(result) != GENERATED_OUTPUT_SHA:
        raise ValueError("Generated standard sRGB output curve differs from the native reference")
    return result


def generate_matrix_tables(profile):
    tags = matrix_profile_tags(profile)
    source = tuple(v for key in (b"rTRC", b"gTRC", b"bTRC")
                   for v in matrix_input_curve(tags.get(key, b"")))
    grid = build_matrix_grid(matrix_colorants(tags), SRGB_COLORANTS)
    target = srgb_output_curve()
    # These four full-domain measurements are hard acceptance anchors, not
    # stored conversion tables. Other supported profiles are generated
    # by the same reviewed branch, but have not been individually measured.
    expected = GENERATED_SOURCE_SHA.get(sha(profile))
    if expected is not None and (_table_hash(source) != expected or _table_hash(grid) != GENERATED_GRID_SHA):
        raise ValueError("Generated ICC tables differ from the native reference")
    return source, grid, target


@lru_cache(maxsize=2)
def generated_transform(profile):
    try:
        tables = generate_matrix_tables(profile)
    except UnsupportedMatrixProfile:
        return None
    return lru_cache(maxsize=32768)(Rgb8Replay(tables).convert)


def transform_for_profile(profile):
    if not isinstance(profile, bytes) or not profile:
        raise ValueError("Invalid embedded wallpaper ICC profile")
    digest = sha(profile)
    if digest in GENERATED_SOURCE_SHA:
        # The independently generated tables are already fully measured for
        # these profiles; don't read or prefer an obsolete private receipt.
        transform = generated_transform(profile)
        if transform is None:
            raise ValueError("Measured ICC profile rejected by the independent generator")
        return transform
    full = read_full_bundle()
    if full is not None:
        entry = full_bundle_entries(full).get(digest)
        if entry is not None:
            _, packed = entry
            values = struct.unpack(f">{TABLE_WORDS}H", packed)
            tables = values[:768], values[768:768 + 98304], values[768 + 98304:]
            return lru_cache(maxsize=32768)(Rgb8Replay(tables).convert)
    # Other profiles may use the independently reconstructed matrix branch.
    # A verified supplemental table is data for this same executor, never
    # a second algorithm. Unsupported profiles are explicit failures.
    if len(profile) <= 1024 * 1024:
        return generated_transform(profile)
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
    parser.add_argument("--import-full-report", type=Path, required=True)
    parser.add_argument("--profile-sha256", action="append", default=[],
                        help="Select exact source identities from the full-domain report")
    args = parser.parse_args()
    try:
        path = import_full_report(args.import_full_report, args.profile_sha256)
    except (OSError, ValueError, KeyError, TypeError, struct.error) as error:
        parser.exit(1, f"ICC replay import: {error}\n")
    print(f"Imported verified local RGB8 replay: {path}")


if __name__ == "__main__":
    main()
