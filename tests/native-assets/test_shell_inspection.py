# SPDX-License-Identifier: GPL-3.0-or-later
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location("shell_inspection", SCRIPTS / "inspect-shell-resources.py")
inspection = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(inspection)


class NamedResources(unittest.TestCase):
    def test_numeric_and_named_resources(self):
        from native_pe_resources import pe_resources
        data = bytearray(0x500)
        data[:2] = b'MZ'
        struct.pack_into('<I', data, 0x3c, 0x80)
        data[0x80:0x84] = b'PE\0\0'
        struct.pack_into('<H', data, 0x86, 1)
        struct.pack_into('<H', data, 0x94, 0xe0)
        struct.pack_into('<H', data, 0x98, 0x10b)
        struct.pack_into('<I', data, 0x98 + 96 + 16, 0x1000)
        struct.pack_into('<III', data, 0x178 + 12, 0x1000, 0x300, 0x200)
        base = 0x200

        def directory(rel, named_count, id_count, entries):
            struct.pack_into('<HH', data, base + rel + 12, named_count, id_count)
            for i, (name, child) in enumerate(entries):
                struct.pack_into('<II', data, base + rel + 16 + 8 * i, name, child)

        directory(0, 0, 1, [(14, 0x80000020)])
        directory(0x20, 1, 1, [(0x800000a0, 0x80000050), (7, 0x80000070)])
        directory(0x50, 0, 1, [(1033, 0xb0)])
        directory(0x70, 0, 1, [(0, 0xc0)])
        struct.pack_into('<H', data, base + 0xa0, 7)
        data[base + 0xa2:base + 0xb0] = 'Battery'.encode('utf-16le')
        struct.pack_into('<II', data, base + 0xb0, 0x1100, 3)
        struct.pack_into('<II', data, base + 0xc0, 0x1103, 3)
        data[0x300:0x306] = b'abcdef'
        self.assertEqual(pe_resources(data), {(14, 7, 0): b'def'})
        self.assertEqual(pe_resources(data, named=True),
                         {(14, 'Battery', 1033): b'abc', (14, 7, 0): b'def'})


class ShellAssetExtraction(unittest.TestCase):
    def png(self, width=24, height=24):
        return (b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR"
                + struct.pack(">II", width, height) + bytes((8, 6, 0, 0, 0)) + bytes(4))

    def test_search_icon_is_kept_as_original_png(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "source"
            output = root / "output"
            asset = source / "SystemApps/MicrosoftWindows.Client.Core/StartMenu/Assets/SearchIcons/SearchIconOnLight.scale-100.png"
            asset.parent.mkdir(parents=True)
            asset.write_bytes(self.png())
            self.assertEqual(inspection.scan(source, output), [])
            inventory = json.loads((output / "inventory.json").read_text())
            self.assertEqual(len(inventory["shell_assets"]), 1)
            record = inventory["shell_assets"][0]
            self.assertEqual(record["role"], "search-on-light")
            self.assertEqual((output / record["output"]).read_bytes(), self.png())
            self.assertEqual(record["sha256"], hashlib.sha256(self.png()).hexdigest())

    def test_rejects_invalid_search_png(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            output = root / "output"
            assets = []
            with self.assertRaisesRegex(ValueError, "Invalid original PNG"):
                inspection.write_shell_asset(
                    output, assets, "search-on-light", "SearchIconOnLight.png",
                    "shell/search/search-on-light.png", b"not a PNG", "png"
                )
            self.assertEqual(assets, [])

    def test_install_copies_only_hash_verified_shell_assets(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            output = root / "output"
            asset = output / "shell/search/search-on-light.png"
            asset.parent.mkdir(parents=True)
            raw = self.png()
            asset.write_bytes(raw)
            (output / "inventory.json").write_text(json.dumps({
                "shell_assets": [{
                    "role": "search-on-light",
                    "source": "Windows/SystemApps/SearchIconOnLight.scale-100.png",
                    "output": "shell/search/search-on-light.png",
                    "bytes": len(raw),
                    "sha256": hashlib.sha256(raw).hexdigest(),
                    "format": "png",
                }]
            }))
            data_home = root / "data"
            with patch.dict(os.environ, {"XDG_DATA_HOME": str(data_home)}):
                inspection.install_shell_assets(output)
            installed = data_home / "windows-modern/native-assets/shell/search/search-on-light.png"
            self.assertEqual(installed.read_bytes(), raw)
            manifest = json.loads((installed.parents[1] / "manifest.json").read_text())
            self.assertEqual(manifest["assets"][0]["sha256"], hashlib.sha256(raw).hexdigest())


class IconGroup(unittest.TestCase):
    def setUp(self):
        self.group = (14, "Battery", 1033)
        self.entry = struct.pack("<BBBBHHIH", 0, 0, 0, 0, 1, 32, 3, 42)
        self.resources = {self.group: struct.pack("<HHH", 0, 1, 1) + self.entry, (3, 42, 0): b"abc"}

    def test_single_language_fallback_preserves_frame(self):
        ico, frames = inspection.icon_group(self.resources, self.group)
        self.assertEqual(ico[22:], b"abc")
        self.assertEqual(struct.unpack_from("<I", ico, 18)[0], 22)
        self.assertEqual((frames[0]["width"], frames[0]["id"], frames[0]["language"]), (256, 42, 0))

    def test_exact_language_and_ambiguous_fallback(self):
        self.resources[(3, 42, 1041)] = b"def"
        with self.assertRaisesRegex(ValueError, "ambiguous"):
            inspection.icon_group(self.resources, self.group)
        self.resources[(3, 42, 1033)] = b"ghi"
        self.assertEqual(inspection.icon_group(self.resources, self.group)[0][22:], b"ghi")

    def test_size_mismatch(self):
        self.resources[(3, 42, 0)] = b"shorter than declared?"
        with self.assertRaisesRegex(ValueError, "length"):
            inspection.icon_group(self.resources, self.group)
