# SPDX-License-Identifier: GPL-3.0-or-later
"""Unit tests for private Windows 11 26H2 cursor XCursor conversion and verification."""
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest
import sys

SCRIPTS = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location("cursor_assets", SCRIPTS / "import-cursor-assets.py")
cursors = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cursors)


def synthetic_cur_32bpp(width: int, height: int, xhot: int, yhot: int, rgba: tuple[int, int, int, int]) -> bytes:
    r, g, b, a = rgba
    xor_row = struct.pack("<BBBB", b, g, r, a) * width
    xor_bytes = xor_row * height
    and_stride = ((width + 31) // 32) * 4
    and_bytes = (b"\x00" * and_stride) * height
    bmi = struct.pack("<IiiHHIIiiII", 40, width, height * 2, 1, 32, 0, len(xor_bytes), 0, 0, 0, 0)
    img = bmi + xor_bytes + and_bytes
    w_byte = 0 if width == 256 else width
    h_byte = 0 if height == 256 else height
    header = struct.pack("<HHH", 0, 2, 1)
    entry = struct.pack("<BBBBHHII", w_byte, h_byte, 0, 0, xhot, yhot, len(img), 22)
    return header + entry + img


def synthetic_ani(frame_blobs: list[bytes], jiffies: int = 3, rates: list[int] | None = None, seq: list[int] | None = None) -> bytes:
    nsteps = len(seq) if seq is not None else len(frame_blobs)
    anih_body = struct.pack("<9I", 36, len(frame_blobs), nsteps, 0, 0, 32, 1, jiffies, 1)
    chunks = bytearray(b"anih" + struct.pack("<I", 36) + anih_body)
    if rates is not None:
        rbody = struct.pack(f"<{len(rates)}I", *rates)
        chunks.extend(b"rate" + struct.pack("<I", len(rbody)) + rbody)
    if seq is not None:
        sbody = struct.pack(f"<{len(seq)}I", *seq)
        chunks.extend(b"seq " + struct.pack("<I", len(sbody)) + sbody)
    fram = bytearray(b"fram")
    for blob in frame_blobs:
        fram.extend(b"icon" + struct.pack("<I", len(blob)) + blob)
        if len(blob) & 1:
            fram.append(0)
    chunks.extend(b"LIST" + struct.pack("<I", len(fram)) + fram)
    return b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"ACON" + bytes(chunks)


class CursorAssetTests(unittest.TestCase):
    def test_nominal_sizes_match_kde_dpi_buckets(self):
        self.assertEqual(cursors.nominal_size_for_canvas(32), 24)
        self.assertEqual(cursors.nominal_size_for_canvas(48), 36)
        self.assertEqual(cursors.nominal_size_for_canvas(64), 48)
        self.assertEqual(cursors.nominal_size_for_canvas(96), 72)
        self.assertEqual(cursors.nominal_size_for_canvas(128), 96)

    def test_straight_alpha_is_premultiplied_in_xcursor(self):
        cur = synthetic_cur_32bpp(32, 32, 6, 0, (223, 0, 0, 27))
        frames = cursors.parse_cur_frames(cur)
        self.assertEqual(len(frames), 1)
        self.assertEqual(frames[0]["nominal"], 24)
        self.assertEqual(frames[0]["xhot"], 6)
        self.assertEqual(frames[0]["yhot"], 0)
        b, g, r, a = struct.unpack_from("<BBBB", frames[0]["bgra"], 0)
        self.assertEqual((r, g, b, a), ((223 * 27 + 127) // 255, 0, 0, 27))
        self.assertLessEqual(r, a)

        xcur = cursors.encode_xcursor(frames)
        magic, hdr_len, ver, ntoc = struct.unpack_from("<4sIII", xcur, 0)
        self.assertEqual(magic, b"Xcur")
        self.assertEqual(hdr_len, 16)
        self.assertEqual(ver, 0x00010000)
        self.assertEqual(ntoc, 1)
        ctype, subtype, pos = struct.unpack_from("<III", xcur, 16)
        self.assertEqual(ctype, 0xFFFD0002)
        self.assertEqual(subtype, 24)
        self.assertEqual(pos, 28)

    def test_ani_sequence_and_jiffies_timing(self):
        f0 = synthetic_cur_32bpp(48, 48, 24, 24, (40, 140, 230, 200))
        f1 = synthetic_cur_32bpp(48, 48, 24, 24, (20, 80, 160, 200))
        ani = synthetic_ani([f0, f1], jiffies=3, rates=[3, 6, 3], seq=[0, 1, 0])
        frames = cursors.parse_ani_frames(ani)
        self.assertEqual(len(frames), 3)
        self.assertEqual([f["delay"] for f in frames], [50, 100, 50])
        self.assertTrue(all(f["nominal"] == 36 for f in frames))

    def test_full_install_and_tamper_verification(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            win = root / "Windows"
            (win / "Cursors").mkdir(parents=True)
            for _, rel in cursors.CURSOR_FILE_ROLES.values():
                target = win / rel
                if rel.endswith(".ani"):
                    target.write_bytes(synthetic_ani([synthetic_cur_32bpp(32, 32, 16, 16, (255, 255, 255, 255))]))
                else:
                    target.write_bytes(synthetic_cur_32bpp(32, 32, 0, 0, (255, 255, 255, 255)))
            dest = root / "cursor-assets"
            manifest = cursors.install(root, dest, "26300.9974")
            self.assertEqual(manifest["declared_source_build"], "26300.9974")
            verified = cursors.verify_directory(dest)
            self.assertEqual(verified["theme"], "Windows-Modern-26H2")

            (dest / "Windows-Modern-26H2/cursors/default").write_bytes(b"corrupt")
            with self.assertRaisesRegex(ValueError, "hash mismatch"):
                cursors.verify_directory(dest)


if __name__ == "__main__":
    unittest.main()
