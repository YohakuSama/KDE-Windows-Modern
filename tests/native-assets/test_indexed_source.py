# SPDX-License-Identifier: GPL-3.0-or-later
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
from native_assets_index import IndexedResources


def sha(content):
    return hashlib.sha256(content).hexdigest()


class IndexedSourceTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.name = 'SystemResources/imageres.dll.mun'
        self.original = 'original/Windows/' + self.name
        self.preview = 'png/imageres.dll.mun/88-0409/frame.png'
        self.write(self.original, b'original bytes')
        self.write(self.preview, b'preview bytes')
        self.manifest = {
            'source_archive': {'sha256': 'test'},
            'original_files': [{'path': self.original, 'size_bytes': len(b'original bytes'),
                                'sha256': sha(b'original bytes')}],
            'groups': [{'module': 'imageres.dll.mun', 'group_id': 88,
                        'language_id': 1033, 'preview_png': self.preview,
                        'frames': [{'png': self.preview, 'png_sha256': sha(b'preview bytes'),
                                    'width': 64, 'height': 64}]}]
        }

    def write(self, path, data):
        p = self.root / path
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)

    def index(self):
        self.write('resource-manifest.json', json.dumps(self.manifest).encode())
        return IndexedResources(self.root)

    def test_indexed_original_and_preview(self):
        index = self.index()
        self.assertEqual(index.read_originals({self.name}), {self.name: b'original bytes'})
        self.assertEqual(index.numeric_group_ids('imageres.dll.mun'), [88])
        self.assertEqual(index.preview('imageres.dll.mun', 88), (b'preview bytes', (64, 64)))

    def test_original_mismatch(self):
        index = self.index()
        self.write(self.original, b'changed')
        with self.assertRaisesRegex(ValueError, 'Indexed original mismatch'):
            index.read_originals({self.name})

    def test_preview_mismatch(self):
        index = self.index()
        self.write(self.preview, b'changed')
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            index.preview('imageres.dll.mun', 88)

    def test_wrong_group_path(self):
        self.manifest['groups'][0]['preview_png'] = 'png/other/frame.png'
        with self.assertRaisesRegex(ValueError, 'not a frame'):
            self.index().preview('imageres.dll.mun', 88)

    def test_duplicate_group(self):
        self.manifest['groups'].append(self.manifest['groups'][0])
        with self.assertRaisesRegex(ValueError, 'Duplicate indexed icon group'):
            self.index()

    def test_missing_group(self):
        with self.assertRaisesRegex(ValueError, 'Missing indexed group'):
            self.index().preview('imageres.dll.mun', 89)
