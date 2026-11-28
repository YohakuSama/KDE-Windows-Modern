#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Import original Windows 11 26H2 cursors into a private local XCursor theme."""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import struct
import tarfile
import tempfile
import zipfile

from native_pe_resources import pe_resources

THEME_NAME = "Windows-Modern-26H2"
MANIFEST_FORMAT = "windows-modern-cursor-assets-v1"
MAX_CURSOR_BYTES = 32 * 1024 * 1024
MAX_DIMENSION = 512
MAX_ANI_STEPS = 256
XCURSOR_MAGIC = b"Xcur"
XCURSOR_VERSION = 0x00010000
XCURSOR_IMAGE_TYPE = 0xFFFD0002
XCURSOR_IMAGE_VERSION = 1

# Verified against 26H2 Resources/Themes/aero.theme and dark.theme
# ([Control Panel\Cursors], DefaultValue=Windows Default).
AERO_THEME_ROLES = {
    "Arrow": "aero_arrow.cur",
    "Help": "aero_helpsel.cur",
    "AppStarting": "aero_working.ani",
    "Wait": "aero_busy.ani",
    "NWPen": "aero_pen.cur",
    "No": "aero_unavail.cur",
    "SizeNS": "aero_ns.cur",
    "SizeWE": "aero_ew.cur",
    "SizeNWSE": "aero_nwse.cur",
    "SizeNESW": "aero_nesw.cur",
    "SizeAll": "aero_move.cur",
    "UpArrow": "aero_up.cur",
    "Hand": "aero_link.cur",
}

# Canonical XCursor targets backed by Windows/Cursors/* files.
# Crosshair and IBeam are empty in aero.theme; beam_r.cur and cross_r.cur
# supply the multi-DPI black-core + white-outline bitmaps without Win32
# hardware XOR screen inversion (which X11/Wayland ARGB32 cursors lack).
CURSOR_FILE_ROLES = {
    "default": ("Arrow", "Cursors/aero_arrow.cur"),
    "help": ("Help", "Cursors/aero_helpsel.cur"),
    "progress": ("AppStarting", "Cursors/aero_working.ani"),
    "wait": ("Wait", "Cursors/aero_busy.ani"),
    "pencil": ("NWPen", "Cursors/aero_pen.cur"),
    "not-allowed": ("No", "Cursors/aero_unavail.cur"),
    "size_ver": ("SizeNS", "Cursors/aero_ns.cur"),
    "size_hor": ("SizeWE", "Cursors/aero_ew.cur"),
    "size_fdiag": ("SizeNWSE", "Cursors/aero_nwse.cur"),
    "size_bdiag": ("SizeNESW", "Cursors/aero_nesw.cur"),
    "fleur": ("SizeAll", "Cursors/aero_move.cur"),
    "up-arrow": ("UpArrow", "Cursors/aero_up.cur"),
    "pointer": ("Hand", "Cursors/aero_link.cur"),
    "pin": ("Pin", "Cursors/aero_pin.cur"),
    "person": ("Person", "Cursors/aero_person.cur"),
    "text": ("IBeam", "Cursors/beam_r.cur"),
    "crosshair": ("Crosshair", "Cursors/cross_r.cur"),
}

# Optional 32-bit multi-DPI OLE drag-and-drop cursor groups in System32/ole32.dll:
# group 2 = DROPEFFECT_MOVE, group 3 = DROPEFFECT_COPY (+), group 4 = DROPEFFECT_LINK.
OLE32_CURSOR_GROUPS = {
    "dnd-move": (2, "default"),
    "copy": (3, "default"),
    "alias": (4, "pointer"),
}

# Freedesktop / Wayland cursor-shape-v1 / Qt / GTK / X11 legacy & hash aliases.
CURSOR_ALIASES = {
    "default": (
        "arrow",
        "left_ptr",
        "top_left_arrow",
        "wayland-cursor",
    ),
    "help": (
        "left_ptr_help",
        "question_arrow",
        "whats_this",
        "5c6cd98b3f3ebcb1f9c7f1c204630408",
        "d9ce0ab605698f320427677b458ad60b",
    ),
    "progress": (
        "left_ptr_watch",
        "half-busy",
        "00000000000000020006000e7e9ffc3f",
        "08e8e1c95fe2fc01f976f1e063a24ccd",
        "3ecb610c1bf2410f44200f48c40d3599",
    ),
    "wait": (
        "watch",
    ),
    "pencil": (
        "draft",
    ),
    "not-allowed": (
        "no-drop",
        "dnd-no-drop",
        "forbidden",
        "circle",
        "crossed_circle",
        "pirate",
        "03b6e0fcb3499374a867c041f52298f0",
    ),
    "size_ver": (
        "ns-resize",
        "n-resize",
        "s-resize",
        "row-resize",
        "split_v",
        "sb_v_double_arrow",
        "v_double_arrow",
        "top_side",
        "bottom_side",
        "size-ver",
        "00008160000006810000408080010102",
    ),
    "size_hor": (
        "ew-resize",
        "e-resize",
        "w-resize",
        "col-resize",
        "split_h",
        "sb_h_double_arrow",
        "h_double_arrow",
        "left_side",
        "right_side",
        "size-hor",
    ),
    "size_fdiag": (
        "nwse-resize",
        "nw-resize",
        "se-resize",
        "top_left_corner",
        "bottom_right_corner",
        "size-fdiag",
    ),
    "size_bdiag": (
        "nesw-resize",
        "ne-resize",
        "sw-resize",
        "top_right_corner",
        "bottom_left_corner",
        "size-bdiag",
    ),
    "fleur": (
        "size_all",
        "all-scroll",
        "move",
        "closedhand",
        "grabbing",
        "openhand",
        "grab",
        "4498f0e0c1937ffe01fd06f973665830",
        "9081237383d90e509aa00f00170e968f",
        "fcf21c00b30f7e3f83fe0dfd12e71cff",
    ),
    "up-arrow": (
        "center_ptr",
        "sb_up_arrow",
    ),
    "pointer": (
        "pointing_hand",
        "hand",
        "hand1",
        "hand2",
        "9d800788f1b08800ae810202380a0822",
        "e29285e634086352946a0e7090d73106",
    ),
    "text": (
        "ibeam",
        "xterm",
    ),
    "crosshair": (
        "cross",
        "tcross",
        "cell",
        "plus",
    ),
    "dnd-move": (
        "dnd-none",
    ),
    "copy": (
        "dnd-copy",
        "1081e37283d90000800003c07f3ef6bf",
        "6407b0e94181790501fd1e167b474872",
        "b66166c04f8c3109214a4fbd64a50fc8",
    ),
    "alias": (
        "link",
        "dnd-link",
        "3085a0e285430894940527032f8b26df",
        "640fb0e74195791501fd1ed57b41487f",
        "a2a266d0498c3104214a47bd64ab0fc8",
    ),
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def importer_fingerprint() -> str:
    h = hashlib.sha256()
    root = Path(__file__).resolve().parent
    for name in ("import-cursor-assets.py", "native_pe_resources.py"):
        h.update(name.encode("utf-8") + b"\0")
        h.update(hashlib.sha256((root / name).read_bytes()).digest())
    return h.hexdigest()


def nominal_size_for_canvas(width: int) -> int:
    """Map Windows 32/48/64/96/128 cursor canvases to KDE's 24/36/48/72/96 nominal sizes.

    KDE Plasma's default cursorSize=24 uses 32x32 bitmaps at 100% (subtype=24),
    48x48 bitmaps at 150% (subtype=36), and 64x64 bitmaps at 200% (subtype=48),
    matching breeze_cursors so Windows 11 bitmaps render 1:1 without resampling.
    """
    return max(12, round(width * 3 / 4))


def _local_casefold(root: Path, relative: str) -> Path | None:
    path = root
    for part in PurePosixPath(relative).parts:
        if part in ("..", ".") or PurePosixPath(part).is_absolute():
            raise ValueError("Invalid resource path: " + relative)
        if not path.is_dir():
            return None
        matches = [c for c in path.iterdir() if c.name.casefold() == part.casefold()]
        if len(matches) > 1:
            raise ValueError("Ambiguous resource path: " + relative)
        if not matches:
            return None
        path = matches[0]
        if path.is_symlink() or not path.resolve().is_relative_to(root):
            raise ValueError("Resource escapes input directory: " + relative)
    return path


def _read_bounded(stream, size: int, label: str) -> bytes:
    if size <= 0 or size > MAX_CURSOR_BYTES:
        raise ValueError("Invalid or oversized cursor input: " + label)
    data = stream.read(size + 1)
    if len(data) != size:
        raise ValueError("Truncated cursor input: " + label)
    return data


def read_cursor_inputs(source: Path) -> dict[str, bytes]:
    """Read required cursor files and optional aero.theme / ole32.dll from dir or archive."""
    required = {rel for _, rel in CURSOR_FILE_ROLES.values()}
    optional = {"Resources/Themes/aero.theme", "System32/ole32.dll"}
    wanted_lower = {p.casefold(): p for p in required | optional}
    found: dict[str, bytes] = {}

    if source.is_dir():
        root = source.resolve(strict=True)
        win = _local_casefold(root, "Windows")
        if win is not None and win.is_dir():
            root = win
        for canonical in sorted(required | optional):
            path = _local_casefold(root, canonical)
            if path is None or not path.is_file():
                continue
            if path.is_symlink() or not path.resolve().is_relative_to(root):
                raise ValueError("Invalid cursor file: " + canonical)
            with path.open("rb") as stream:
                found[canonical] = _read_bounded(stream, path.stat().st_size, canonical)
    elif zipfile.is_zipfile(source):
        with zipfile.ZipFile(source) as archive:
            for member in archive.infolist():
                parts = PurePosixPath(member.filename).parts
                if ".." in parts or PurePosixPath(member.filename).is_absolute():
                    raise ValueError("Unsafe archive path: " + member.filename)
                lower_parts = [p.casefold() for p in parts]
                rel_parts = parts[lower_parts.index("windows") + 1:] if "windows" in lower_parts else parts
                key = "/".join(rel_parts).casefold()
                canonical = wanted_lower.get(key)
                if canonical is None:
                    continue
                mode = member.external_attr >> 16
                if member.is_dir() or stat.S_IFMT(mode) not in (0, stat.S_IFREG):
                    raise ValueError("Non-regular archive member: " + canonical)
                if canonical in found:
                    raise ValueError("Duplicate archive member: " + canonical)
                with archive.open(member) as stream:
                    found[canonical] = _read_bounded(stream, member.file_size, canonical)
    elif tarfile.is_tarfile(source):
        with tarfile.open(source, "r:*") as archive:
            for member in archive:
                parts = PurePosixPath(member.name).parts
                if ".." in parts or PurePosixPath(member.name).is_absolute():
                    raise ValueError("Unsafe archive path: " + member.name)
                lower_parts = [p.casefold() for p in parts]
                rel_parts = parts[lower_parts.index("windows") + 1:] if "windows" in lower_parts else parts
                key = "/".join(rel_parts).casefold()
                canonical = wanted_lower.get(key)
                if canonical is None:
                    continue
                if not member.isfile():
                    raise ValueError("Non-regular archive member: " + canonical)
                if canonical in found:
                    raise ValueError("Duplicate archive member: " + canonical)
                extracted = archive.extractfile(member)
                if extracted is None:
                    raise ValueError("Unreadable archive member: " + canonical)
                with extracted:
                    found[canonical] = _read_bounded(extracted, member.size, canonical)
    else:
        raise ValueError("Provide an extracted Windows directory or ZIP/TAR archive")

    missing = sorted(required - found.keys())
    if missing:
        raise ValueError("Missing original Windows cursor files: " + ", ".join(missing))
    return found


def verify_aero_theme(raw: bytes) -> None:
    """Confirm aero.theme still maps the expected 26H2 default cursor filenames."""
    text = None
    for encoding in ("utf-8-sig", "utf-16", "cp1252"):
        try:
            candidate = raw.decode(encoding)
        except UnicodeDecodeError:
            continue
        if "[Control Panel\\Cursors]" in candidate:
            text = candidate
            break
    if text is None:
        raise ValueError("Unreadable Windows aero.theme cursor section")
    section = text.split("[Control Panel\\Cursors]", 1)[1].split("\n[", 1)[0]
    entries: dict[str, str] = {}
    for raw_line in section.splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        entries[key.strip()] = value.strip()
    for role, expected_file in AERO_THEME_ROLES.items():
        actual = entries.get(role, "").replace("/", "\\").rsplit("\\", 1)[-1]
        if actual.casefold() != expected_file.casefold():
            raise ValueError(f"aero.theme cursor mismatch for {role}: {entries.get(role)!r}")


def _premultiply_bgra(r: int, g: int, b: int, a: int) -> bytes:
    if a <= 0:
        return b"\x00\x00\x00\x00"
    if a >= 255:
        return struct.pack("<BBBB", b, g, r, 255)
    return struct.pack(
        "<BBBB",
        (b * a + 127) // 255,
        (g * a + 127) // 255,
        (r * a + 127) // 255,
        a,
    )


def _decode_png_rgba(payload: bytes) -> tuple[int, int, bytes]:
    from PIL import Image

    with Image.open(io.BytesIO(payload)) as img:
        if img.format != "PNG":
            raise ValueError("Expected PNG cursor payload")
        rgba = img.convert("RGBA")
        width, height = rgba.size
        if not (0 < width <= MAX_DIMENSION and 0 < height <= MAX_DIMENSION):
            raise ValueError(f"Invalid PNG cursor dimensions: {width}x{height}")
        raw = rgba.tobytes()
    out = bytearray(width * height * 4)
    for idx in range(0, len(raw), 4):
        r, g, b, a = raw[idx], raw[idx + 1], raw[idx + 2], raw[idx + 3]
        out[idx:idx + 4] = _premultiply_bgra(r, g, b, a)
    return width, height, bytes(out)


def decode_cursor_bitmap(payload: bytes) -> tuple[int, int, int, bytes]:
    """Decode a Windows cursor DIB or PNG frame into premultiplied BGRA bytes."""
    if payload.startswith(b"\x89PNG\r\n\x1a\n"):
        width, height, bgra = _decode_png_rgba(payload)
        return width, height, 32, bgra

    if len(payload) < 40:
        raise ValueError("Truncated cursor BITMAPINFOHEADER")
    bi_size, bi_w, bi_h_total, bi_planes, bi_bpp, bi_comp = struct.unpack_from("<IiiHHI", payload, 0)
    if bi_size < 40 or bi_comp != 0 or bi_planes not in (0, 1):
        raise ValueError(f"Unsupported cursor DIB header (size={bi_size}, comp={bi_comp})")
    if bi_bpp not in (1, 4, 8, 24, 32):
        raise ValueError(f"Unsupported cursor bit depth: {bi_bpp}")
    width = abs(bi_w)
    height = abs(bi_h_total) // 2
    if not (0 < width <= MAX_DIMENSION and 0 < height <= MAX_DIMENSION):
        raise ValueError(f"Invalid cursor dimensions: {width}x{height}")
    top_down = bi_h_total < 0

    offset = bi_size
    palette: list[tuple[int, int, int]] = []
    if bi_bpp <= 8:
        clr_used = struct.unpack_from("<I", payload, 32)[0]
        ncolors = clr_used if 0 < clr_used <= (1 << bi_bpp) else (1 << bi_bpp)
        if offset + ncolors * 4 > len(payload):
            raise ValueError("Truncated cursor color table")
        for i in range(ncolors):
            b, g, r, _ = struct.unpack_from("<BBBB", payload, offset + i * 4)
            palette.append((r, g, b))
        offset += ncolors * 4

    xor_stride = ((width * bi_bpp + 31) // 32) * 4
    and_stride = ((width + 31) // 32) * 4
    xor_len = xor_stride * height
    and_len = and_stride * height
    if offset + xor_len > len(payload):
        raise ValueError("Truncated cursor XOR bitmap")
    xor_bytes = payload[offset:offset + xor_len]
    and_bytes = payload[offset + xor_len:offset + xor_len + and_len]
    has_and = len(and_bytes) == and_len

    has_alpha = False
    if bi_bpp == 32:
        for pos in range(3, len(xor_bytes), 4):
            if xor_bytes[pos] != 0:
                has_alpha = True
                break

    out = bytearray(width * height * 4)
    write_pos = 0
    for y in range(height):
        src_y = y if top_down else (height - 1 - y)
        xor_row = src_y * xor_stride
        and_row = src_y * and_stride
        for x in range(width):
            and_bit = ((and_bytes[and_row + (x >> 3)] >> (7 - (x & 7))) & 1) if has_and else 0
            if bi_bpp == 32:
                b, g, r, a = struct.unpack_from("<BBBB", xor_bytes, xor_row + x * 4)
                eff_a = a if has_alpha else (0 if and_bit else 255)
                out[write_pos:write_pos + 4] = _premultiply_bgra(r, g, b, eff_a)
            elif bi_bpp == 24:
                b, g, r = struct.unpack_from("<BBB", xor_bytes, xor_row + x * 3)
                out[write_pos:write_pos + 4] = _premultiply_bgra(r, g, b, 0 if and_bit else 255)
            elif bi_bpp == 1:
                xor_bit = (xor_bytes[xor_row + (x >> 3)] >> (7 - (x & 7))) & 1
                if and_bit == 1 and xor_bit == 0:
                    out[write_pos:write_pos + 4] = b"\x00\x00\x00\x00"
                elif and_bit == 1 and xor_bit == 1:
                    raise ValueError("XOR-inverted monochrome cursor cannot be represented losslessly in XCursor")
                else:
                    r, g, b = palette[xor_bit]
                    out[write_pos:write_pos + 4] = _premultiply_bgra(r, g, b, 255)
            else:
                if bi_bpp == 8:
                    idx = xor_bytes[xor_row + x]
                else:
                    byte = xor_bytes[xor_row + (x >> 1)]
                    idx = (byte >> 4) if (x % 2 == 0) else (byte & 0x0F)
                if idx >= len(palette):
                    raise ValueError("Cursor palette index out of range")
                if and_bit == 1:
                    if idx == 0:
                        out[write_pos:write_pos + 4] = b"\x00\x00\x00\x00"
                    else:
                        raise ValueError("XOR-inverted indexed cursor cannot be represented losslessly in XCursor")
                else:
                    r, g, b = palette[idx]
                    out[write_pos:write_pos + 4] = _premultiply_bgra(r, g, b, 255)
            write_pos += 4

    return width, height, bi_bpp, bytes(out)


def parse_cur_frames(data: bytes, delay_ms: int = 0) -> list[dict]:
    """Parse a Windows .cur / .ico container and select the best-bpp image per size."""
    if len(data) < 6:
        raise ValueError("Truncated .cur header")
    reserved, res_type, count = struct.unpack_from("<HHH", data, 0)
    if reserved != 0 or res_type not in (1, 2) or count <= 0 or 6 + count * 16 > len(data):
        raise ValueError("Invalid .cur directory header")

    by_size: dict[tuple[int, int], tuple[int, dict]] = {}
    for index in range(count):
        _, _, _, _, xhot, yhot, byte_len, img_off = struct.unpack_from("<BBBBHHII", data, 6 + index * 16)
        if byte_len <= 0 or img_off < 6 + count * 16 or img_off + byte_len > len(data):
            raise ValueError("Invalid .cur image bounds")
        width, height, bpp, bgra = decode_cursor_bitmap(data[img_off:img_off + byte_len])
        if res_type == 1:
            xhot, yhot = width // 2, height // 2
        if xhot >= width or yhot >= height:
            raise ValueError(f"Cursor hotspot ({xhot},{yhot}) outside {width}x{height} frame")
        frame = {
            "nominal": nominal_size_for_canvas(width),
            "width": width,
            "height": height,
            "xhot": xhot,
            "yhot": yhot,
            "delay": delay_ms,
            "bgra": bgra,
        }
        prev = by_size.get((width, height))
        if prev is None or bpp > prev[0]:
            by_size[(width, height)] = (bpp, frame)

    return [entry[1] for _, entry in sorted(by_size.items())]


def parse_ani_frames(data: bytes) -> list[dict]:
    """Parse a RIFF ACON (.ani) animated cursor into ordered XCursor image records."""
    if len(data) < 12 or data[:4] != b"RIFF" or data[8:12] != b"ACON":
        raise ValueError("Not a RIFF ACON animated cursor")
    riff_end = min(len(data), 8 + struct.unpack_from("<I", data, 4)[0])
    anih = None
    rates: list[int] | None = None
    sequence: list[int] | None = None
    raw_frames: list[bytes] = []

    def walk(start: int, limit: int) -> None:
        nonlocal anih, rates, sequence
        pos = start
        while pos + 8 <= limit:
            chunk_id = data[pos:pos + 4]
            chunk_size = struct.unpack_from("<I", data, pos + 4)[0]
            body_start = pos + 8
            if body_start + chunk_size > limit:
                raise ValueError("Truncated RIFF chunk in .ani cursor")
            body = data[body_start:body_start + chunk_size]
            if chunk_id == b"LIST":
                if len(body) < 4:
                    raise ValueError("Truncated RIFF LIST chunk")
                walk(body_start + 4, body_start + chunk_size)
            elif chunk_id == b"anih":
                if len(body) < 36:
                    raise ValueError("Invalid anih header")
                cb, nframes, nsteps, _, _, _, _, jiffies, attr = struct.unpack_from("<9I", body, 0)
                if cb < 36 or nframes == 0 or nsteps == 0 or nsteps > MAX_ANI_STEPS or not (attr & 1):
                    raise ValueError("Unsupported .ani header attributes")
                anih = {"nFrames": nframes, "nSteps": nsteps, "jiffies": jiffies or 3}
            elif chunk_id == b"rate":
                if len(body) % 4 != 0:
                    raise ValueError("Invalid .ani rate table")
                rates = list(struct.unpack(f"<{len(body) // 4}I", body))
            elif chunk_id == b"seq ":
                if len(body) % 4 != 0:
                    raise ValueError("Invalid .ani sequence table")
                sequence = list(struct.unpack(f"<{len(body) // 4}I", body))
            elif chunk_id == b"icon":
                raw_frames.append(body)
            pos = body_start + chunk_size + (chunk_size & 1)

    walk(12, riff_end)
    if anih is None or len(raw_frames) != anih["nFrames"]:
        raise ValueError("Incomplete .ani frame list")
    steps = sequence if sequence is not None else list(range(anih["nFrames"]))
    if len(steps) != anih["nSteps"] or any(idx >= len(raw_frames) for idx in steps):
        raise ValueError("Invalid .ani playback sequence")
    if rates is not None and len(rates) != len(steps):
        raise ValueError("Mismatched .ani rate table length")

    decoded_frames = [parse_cur_frames(blob, delay_ms=0) for blob in raw_frames]
    by_nominal: dict[int, list[dict]] = {}
    for step_idx, frame_idx in enumerate(steps):
        jiffies = rates[step_idx] if rates is not None else anih["jiffies"]
        delay_ms = max(1, round(jiffies * 1000 / 60))
        for size_entry in decoded_frames[frame_idx]:
            entry = dict(size_entry, delay=delay_ms)
            by_nominal.setdefault(entry["nominal"], []).append(entry)

    ordered: list[dict] = []
    for nominal in sorted(by_nominal):
        if len(by_nominal[nominal]) != len(steps):
            raise ValueError("Inconsistent .ani sizes across animation frames")
        ordered.extend(by_nominal[nominal])
    return ordered


def parse_pe_cursor_group(resources: dict, group_id: int) -> list[dict]:
    """Decode an RT_GROUP_CURSOR (type=12) + RT_CURSOR (type=1) group from ole32.dll."""
    keys = sorted(k for k in resources if len(k) >= 2 and k[:2] == (12, group_id))
    if not keys:
        raise ValueError(f"Missing PE cursor group {group_id}")
    directory = resources[keys[0]]
    if len(directory) < 6:
        raise ValueError("Truncated PE cursor directory")
    reserved, res_type, count = struct.unpack_from("<HHH", directory, 0)
    if reserved != 0 or res_type != 2 or count <= 0 or 6 + count * 14 > len(directory):
        raise ValueError("Invalid PE cursor directory")

    by_size: dict[tuple[int, int], tuple[int, dict]] = {}
    for i in range(count):
        _, _, _, bpp_decl, _, cursor_id = struct.unpack_from("<HHHHIH", directory, 6 + i * 14)
        ckeys = sorted(k for k in resources if len(k) >= 2 and k[:2] == (1, cursor_id))
        if not ckeys:
            raise ValueError(f"Missing RT_CURSOR frame {cursor_id}")
        raw_cursor = resources.get((1, cursor_id, keys[0][-1]), resources[ckeys[0]])
        if len(raw_cursor) < 44:
            raise ValueError(f"Truncated RT_CURSOR frame {cursor_id}")
        xhot, yhot = struct.unpack_from("<HH", raw_cursor, 0)
        width, height, bpp, bgra = decode_cursor_bitmap(raw_cursor[4:])
        if xhot >= width or yhot >= height:
            raise ValueError(f"PE cursor hotspot ({xhot},{yhot}) outside {width}x{height}")
        eff_bpp = bpp or bpp_decl
        frame = {
            "nominal": nominal_size_for_canvas(width),
            "width": width,
            "height": height,
            "xhot": xhot,
            "yhot": yhot,
            "delay": 0,
            "bgra": bgra,
        }
        prev = by_size.get((width, height))
        if prev is None or eff_bpp > prev[0]:
            by_size[(width, height)] = (eff_bpp, frame)
    return [entry[1] for _, entry in sorted(by_size.items())]


def encode_xcursor(frames: list[dict]) -> bytes:
    """Serialize ordered cursor frames into an X11/Wayland Xcur binary."""
    if not frames:
        raise ValueError("Cannot encode empty XCursor")
    header_bytes = 16
    toc_bytes = 12 * len(frames)
    position = header_bytes + toc_bytes
    toc = bytearray()
    chunks = bytearray()
    for frame in frames:
        width = frame["width"]
        height = frame["height"]
        bgra = frame["bgra"]
        if len(bgra) != width * height * 4:
            raise ValueError("Invalid BGRA buffer length for XCursor")
        toc.extend(struct.pack("<III", XCURSOR_IMAGE_TYPE, frame["nominal"], position))
        chunk_header = struct.pack(
            "<9I",
            36,
            XCURSOR_IMAGE_TYPE,
            frame["nominal"],
            XCURSOR_IMAGE_VERSION,
            width,
            height,
            frame["xhot"],
            frame["yhot"],
            frame["delay"],
        )
        chunks.extend(chunk_header)
        chunks.extend(bgra)
        position += 36 + len(bgra)
    file_header = struct.pack("<4sIII", XCURSOR_MAGIC, header_bytes, XCURSOR_VERSION, len(frames))
    return bytes(file_header + toc + chunks)


def collect(source: Path) -> tuple[dict[str, tuple[bytes, dict]], dict[str, str], dict[str, str]]:
    inputs = read_cursor_inputs(source)
    if "Resources/Themes/aero.theme" in inputs:
        verify_aero_theme(inputs["Resources/Themes/aero.theme"])

    sources = {name: sha256(content) for name, content in sorted(inputs.items())}
    outputs: dict[str, tuple[bytes, dict]] = {}
    symlinks: dict[str, str] = {}

    index_theme = (
        "[Icon Theme]\n"
        "Name=Windows Modern 26H2\n"
        "Comment=Imported Windows 11 26H2 system cursors\n"
        "Inherits=Bibata-Modern-Ice,breeze_cursors\n"
    ).encode("utf-8")
    index_rel = f"{THEME_NAME}/index.theme"
    outputs[index_rel] = (
        index_theme,
        {"source": "metadata", "role": "index.theme", "sha256": sha256(index_theme)},
    )

    for cursor_name, (win_role, rel_path) in sorted(CURSOR_FILE_ROLES.items()):
        raw = inputs[rel_path]
        frames = parse_ani_frames(raw) if rel_path.lower().endswith(".ani") else parse_cur_frames(raw)
        xcur = encode_xcursor(frames)
        out_rel = f"{THEME_NAME}/cursors/{cursor_name}"
        nominals = sorted({f["nominal"] for f in frames})
        outputs[out_rel] = (
            xcur,
            {
                "source": rel_path,
                "role": win_role,
                "nominal_sizes": nominals,
                "frame_count": len(frames),
                "sha256": sha256(xcur),
            },
        )

    ole_resources = pe_resources(inputs["System32/ole32.dll"]) if "System32/ole32.dll" in inputs else None
    for cursor_name, (group_id, fallback_target) in sorted(OLE32_CURSOR_GROUPS.items()):
        if ole_resources is not None:
            frames = parse_pe_cursor_group(ole_resources, group_id)
            xcur = encode_xcursor(frames)
            out_rel = f"{THEME_NAME}/cursors/{cursor_name}"
            outputs[out_rel] = (
                xcur,
                {
                    "source": "System32/ole32.dll",
                    "role": f"ole32:{group_id}",
                    "nominal_sizes": sorted({f["nominal"] for f in frames}),
                    "frame_count": len(frames),
                    "sha256": sha256(xcur),
                },
            )
        else:
            symlinks[f"{THEME_NAME}/cursors/{cursor_name}"] = fallback_target

    for target, aliases in sorted(CURSOR_ALIASES.items()):
        resolved_target = symlinks.get(f"{THEME_NAME}/cursors/{target}", target)
        for alias in aliases:
            alias_rel = f"{THEME_NAME}/cursors/{alias}"
            if alias_rel in outputs or alias_rel in symlinks:
                raise ValueError("Conflicting cursor alias: " + alias)
            symlinks[alias_rel] = resolved_target

    return outputs, symlinks, sources


def verify_directory(root: Path) -> dict:
    """Verify an imported cursor-assets directory against its manifest and Xcur headers."""
    root = root.expanduser().resolve(strict=True)
    manifest_path = root / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("format") != MANIFEST_FORMAT:
        raise ValueError("Unsupported cursor asset manifest format")
    if manifest.get("theme") != THEME_NAME:
        raise ValueError("Unexpected cursor theme name")
    if manifest.get("importer_sha256") != importer_fingerprint():
        raise ValueError("Cursor asset importer changed")

    outputs = manifest.get("outputs", {})
    symlinks = manifest.get("symlinks", {})
    if not outputs or f"{THEME_NAME}/index.theme" not in outputs:
        raise ValueError("Incomplete cursor asset manifest")

    expected_entries = set(outputs) | set(symlinks) | {"manifest.json"}
    actual_entries = {
        p.relative_to(root).as_posix()
        for p in root.rglob("*")
        if p.is_file() or p.is_symlink()
    }
    if actual_entries != expected_entries:
        raise ValueError("Cursor asset file list mismatch")

    for rel, info in sorted(outputs.items()):
        parts = PurePosixPath(rel).parts
        if PurePosixPath(rel).is_absolute() or ".." in parts or not parts:
            raise ValueError("Unsafe cursor output path: " + rel)
        path = root / rel
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(root):
            raise ValueError("Invalid cursor output file: " + rel)
        content = path.read_bytes()
        if sha256(content) != info.get("sha256"):
            raise ValueError("Cursor output hash mismatch: " + rel)
        if rel != f"{THEME_NAME}/index.theme":
            if len(content) < 28 or content[:4] != XCURSOR_MAGIC:
                raise ValueError("Invalid Xcur binary: " + rel)

    cursors_dir = (root / THEME_NAME / "cursors").resolve(strict=True)
    for rel, target in sorted(symlinks.items()):
        parts = PurePosixPath(rel).parts
        if PurePosixPath(rel).is_absolute() or ".." in parts or "/" in target or target in ("", ".", ".."):
            raise ValueError("Unsafe cursor symlink: " + rel)
        link = root / rel
        if not link.is_symlink() or os.readlink(link) != target:
            raise ValueError("Changed cursor symlink: " + rel)
        resolved = (link.parent / target).resolve(strict=True)
        if resolved.parent != cursors_dir or not resolved.is_file():
            raise ValueError("Broken or external cursor symlink: " + rel)

    for required_alias in ("left_ptr", "xterm", "watch"):
        if not (cursors_dir / required_alias).exists():
            raise ValueError("Missing required XCursor entry: " + required_alias)

    return manifest


def install(source: Path, destination: Path, build: str) -> dict:
    source = source.expanduser().resolve(strict=True)
    destination = destination.expanduser().resolve()
    if (destination == source or destination in source.parents
            or (source.is_dir() and destination.is_relative_to(source))):
        raise ValueError("Keep cursor assets outside the original Windows directory")

    outputs, symlinks, sources = collect(source)
    if destination.exists():
        try:
            old = json.loads((destination / "manifest.json").read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            raise ValueError("Refusing to replace an unrelated output directory") from exc
        if old.get("format") != MANIFEST_FORMAT:
            raise ValueError("Refusing to replace an unrelated output directory")

    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".cursor-assets-", dir=destination.parent) as temp:
        stage = Path(temp) / "new"
        stage.mkdir(mode=0o755)
        for rel, (content, _) in sorted(outputs.items()):
            target = stage / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
        for rel, target_name in sorted(symlinks.items()):
            link = stage / rel
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(target_name)
        manifest = {
            "format": MANIFEST_FORMAT,
            "theme": THEME_NAME,
            "declared_source_build": build,
            "importer_sha256": importer_fingerprint(),
            "sources": sources,
            "outputs": {rel: record for rel, (_, record) in sorted(outputs.items())},
            "symlinks": dict(sorted(symlinks.items())),
        }
        (stage / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        verify_directory(stage)

        previous = Path(temp) / "previous"
        if destination.exists():
            destination.rename(previous)
        try:
            stage.rename(destination)
        except OSError:
            if previous.exists():
                previous.rename(destination)
            raise
    return manifest


def main() -> None:
    default_out = (
        Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
        / "windows-modern/cursor-assets"
    )
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, nargs="?", help="extracted Windows directory, parent volume, or ZIP/TAR archive")
    parser.add_argument("--build", default="26300.9974", help="numeric Windows build number of the source image")
    parser.add_argument("--output", type=Path, default=default_out, help="private output directory")
    parser.add_argument("--verify", action="store_true", help="verify an existing cursor-assets directory")
    args = parser.parse_args()

    if args.verify:
        target = args.source if args.source is not None else args.output
        try:
            manifest = verify_directory(target)
        except (OSError, ValueError, KeyError, TypeError) as exc:
            parser.exit(1, f"Cursor asset verification failed: {exc}\n")
        print(f"Verified {len(manifest['outputs']) - 1} original XCursor files and {len(manifest['symlinks'])} aliases.")
        return

    if args.source is None:
        parser.error("Provide an extracted Windows source path, or pass --verify.")
    if not re.fullmatch(r"\d+(?:\.\d+){0,3}", args.build):
        parser.error("--build must be a numeric Windows build number")
    try:
        manifest = install(args.source, args.output, args.build)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"Cursor asset import failed: {exc}\n")
    print(
        f"Imported {len(manifest['outputs']) - 1} original XCursor roles and "
        f"{len(manifest['symlinks'])} aliases from build {args.build} into {args.output}."
    )


if __name__ == "__main__":
    main()
