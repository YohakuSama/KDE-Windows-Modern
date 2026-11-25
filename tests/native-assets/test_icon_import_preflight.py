# SPDX-License-Identifier: GPL-3.0-or-later
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / 'scripts/check-native-icon-import.py'
SPEC = importlib.util.spec_from_file_location('check_native_icon_import', SCRIPT)
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class IconImportPreflightTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name) / 'native-assets'
        self.icon = self.root / 'icons/status/wifi.svg'
        self.icon.parent.mkdir(parents=True)
        self.icon.write_bytes(b'<svg/>')
        self.mapping = Path(tmp.name) / 'mapping.json'
        self.mapping.write_text(json.dumps({'icons': {'e701': 'status/wifi',
                                                       'ffff': 'status/optional'},
                                             'optional_glyphs': ['ffff']}))
        self.manifest = {'mapping_sha256': CHECK.digest(self.mapping),
                         'importer_sha256': CHECK.importer_fingerprint(),
                         'missing_optional_glyphs': ['ffff'],
                         'outputs': {'icons/status/wifi.svg': {
                             'source': 'e701', 'sha256': CHECK.digest(self.icon)}}}
        self.write_manifest()

    def write_manifest(self):
        (self.root / 'manifest.json').write_text(json.dumps(self.manifest))

    def test_fresh(self):
        self.assertEqual(CHECK.verify_import(self.root, self.mapping), (1, ['ffff']))

    def test_mapping_changed(self):
        self.mapping.write_text('{}')
        with self.assertRaisesRegex(ValueError, 'older'):
            CHECK.verify_import(self.root, self.mapping)

    def test_importer_changed(self):
        self.manifest['importer_sha256'] = 'old'
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, 'importer is older'):
            CHECK.verify_import(self.root, self.mapping)

    def test_changed_svg(self):
        self.icon.write_bytes(b'<svg>modified</svg>')
        with self.assertRaisesRegex(ValueError, 'mismatch'):
            CHECK.verify_import(self.root, self.mapping)

    def test_unlisted_svg(self):
        (self.icon.parent / 'other.svg').write_bytes(b'<svg/>')
        with self.assertRaisesRegex(ValueError, 'unlisted'):
            CHECK.verify_import(self.root, self.mapping)

    def test_missing_svg(self):
        self.icon.unlink()
        with self.assertRaisesRegex(ValueError, 'missing'):
            CHECK.verify_import(self.root, self.mapping)
