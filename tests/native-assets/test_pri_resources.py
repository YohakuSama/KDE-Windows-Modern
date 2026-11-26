# SPDX-License-Identifier: GPL-3.0-or-later
import struct
import sys
from pathlib import Path
import unittest

SCRIPTS = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))
from native_pri_resources import embedded_resources, named_file_candidates


def make_pri(resource_name, payload, *, embedded=True):
    encoded = (resource_name + "\0").encode("utf-16le")
    schema = bytearray(68 + len(encoded))
    struct.pack_into("<HH", schema, 2, 0, 0)
    struct.pack_into("<II", schema, 20, 0, 1)
    struct.pack_into("<I", schema, 46, len(encoded) // 2)
    struct.pack_into("<HH", schema, 54, 0, 1)
    schema[68:] = encoded

    mapping = bytearray(60)
    struct.pack_into("<H", mapping, 4, 0)
    struct.pack_into("<HHH", mapping, 10, 1, 1, 1)
    struct.pack_into("<II", mapping, 16, 1, 1)
    struct.pack_into("<I", mapping, 28, 0)
    struct.pack_into("<I", mapping, 36, 2)
    struct.pack_into("<HH", mapping, 40, 0, 0)
    struct.pack_into("<HH", mapping, 44, 1, 0)
    struct.pack_into("<HH", mapping, 48, 0, 0)
    mapping[52] = 1 if embedded else 0
    mapping[53] = 0
    struct.pack_into("<HH", mapping, 56, 0, 2)

    data_item = bytearray(20 + len(payload))
    struct.pack_into("<HH", data_item, 4, 0, 1)
    struct.pack_into("<II", data_item, 12, 0, len(payload))
    data_item[20:] = payload

    entries = []
    sections = []
    offset = 0
    for section_id, content in (
        (b"[mrm_hschema]  \0", bytes(schema)),
        (b"[mrm_res_map__]\0", bytes(mapping)),
        (b"[mrm_dataitem] \0", bytes(data_item)),
    ):
        size = len(content) + 40
        entry = bytearray(32)
        entry[:16] = section_id
        struct.pack_into("<II", entry, 24, offset, size)
        entries.append(bytes(entry))
        sections.append(bytes(32) + content + bytes(8))
        offset += size

    header = bytearray(32)
    header[:8] = b"mrm_prif"
    struct.pack_into("<IIH", header, 16, 32, 128, 3)
    return bytes(header) + b"".join(entries) + b"".join(sections)


class PriEmbeddedResources(unittest.TestCase):
    def test_extracts_requested_embedded_svg(self):
        svg = b'<svg xmlns="http://www.w3.org/2000/svg"><path d="M0 0"/></svg>'
        source = make_pri("Files\\SystemSettings\\Assets\\Taskview_Light.svg", svg)
        self.assertEqual(
            embedded_resources(source, [
                "Files/SystemSettings/Assets/Taskview_Light.svg",
                "Files/SystemSettings/Assets/Taskview_Dark.svg",
            ]),
            [svg, None],
        )

    def test_path_matching_is_case_insensitive_and_accepts_suffix(self):
        payload = b"original-png-bytes"
        source = make_pri("Package\\Files\\SystemSettings\\Assets\\Taskview_Dark.svg", payload)
        self.assertEqual(
            embedded_resources(source, ["files/systemsettings/assets/taskview_dark.svg"]),
            [payload],
        )

    def test_named_layout_candidates_keep_exact_resource_identity(self):
        name = "Files\\Shell\\QuickSettings.XBF"
        payload = b"XBF\0synthetic-layout"
        source = make_pri(name, payload)
        self.assertEqual(list(named_file_candidates(source, (".xbf", ".xaml"))),
                         [(1, 0, name, payload)])
        self.assertEqual(list(named_file_candidates(source, (".svg",))), [])

    def test_named_layout_candidate_does_not_guess_external_data(self):
        name = "Files\\Shell\\QuickSettings.xbf"
        source = make_pri(name, b"not the selected candidate", embedded=False)
        self.assertEqual(list(named_file_candidates(source, (".xbf",))),
                         [(1, 0, name, None)])

    def test_rejects_non_pri_and_oversized_input(self):
        with self.assertRaisesRegex(ValueError, "Not a Windows PRI"):
            embedded_resources(b"not a PRI", ["asset.svg"])
        with self.assertRaisesRegex(ValueError, "size limit"):
            embedded_resources(b"x" * (128 * 1024 * 1024 + 1), ["asset.svg"])


if __name__ == "__main__":
    unittest.main()
