# SPDX-License-Identifier: GPL-3.0-or-later
import hashlib
import io
from pathlib import Path
import stat
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
import native_assets_input as assets


class AssetInputTests(unittest.TestCase):
    name = 'Fonts/SegoeIcons.ttf'
    content = b'synthetic test data'

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.wanted = {self.name}

    def make_zip(self, entries):
        path = self.root / 'resources.zip'
        with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            for name, content in entries:
                archive.writestr(name, content)
        return path

    def make_tar(self, entries):
        path = self.root / 'resources.tar.gz'
        with tarfile.open(path, 'w:gz') as archive:
            for name, content in entries:
                info = tarfile.TarInfo(name)
                info.size = len(content)
                archive.addfile(info, io.BytesIO(content))
        return path

    def test_zip_wrapped_windows(self):
        path = self.make_zip([('upload/Windows/' + self.name, self.content),
                              ('upload/Windows/unselected.bin', b'ignored')])
        self.assertEqual(assets.read_assets(path, self.wanted), {self.name: self.content})

    def test_tar_wrapped_windows(self):
        path = self.make_tar([('backup/Windows/' + self.name, self.content)])
        self.assertEqual(assets.read_assets(path, self.wanted), {self.name: self.content})

    def test_archive_without_windows_prefix(self):
        for make in (self.make_zip, self.make_tar):
            with self.subTest(make=make.__name__):
                self.assertEqual(assets.read_assets(make([(self.name, self.content)]), self.wanted),
                                 {self.name: self.content})

    def test_directory(self):
        path = self.root / 'Windows' / self.name
        path.parent.mkdir(parents=True)
        path.write_bytes(self.content)
        for source in (self.root, self.root / 'Windows'):
            self.assertEqual(assets.read_assets(source, self.wanted), {self.name: self.content})

    def test_duplicate_aliases(self):
        for make in (self.make_zip, self.make_tar):
            with self.subTest(make=make.__name__):
                path = make([(self.name, self.content), ('Windows/' + self.name, b'different')])
                with self.assertRaisesRegex(ValueError, 'Duplicate resource'):
                    assets.read_assets(path, self.wanted)

    def test_unsafe_selected_path(self):
        for make in (self.make_zip, self.make_tar):
            with self.subTest(make=make.__name__):
                path = make([('../Windows/' + self.name, self.content)])
                with self.assertRaisesRegex(ValueError, 'Unsafe member path'):
                    assets.read_assets(path, self.wanted)

    def test_missing(self):
        path = self.make_zip([('unselected.bin', b'ignored')])
        with self.assertRaisesRegex(ValueError, 'Missing resources'):
            assets.read_assets(path, self.wanted)

    def test_size_limit_all_input_types(self):
        path = self.root / self.name
        path.parent.mkdir()
        path.write_bytes(self.content)
        inputs = [self.root, self.make_zip([(self.name, self.content)]),
                  self.make_tar([(self.name, self.content)])]
        with patch.object(assets, 'MAX_RESOURCE_BYTES', 4):
            for source in inputs:
                with self.subTest(source=source):
                    with self.assertRaisesRegex(ValueError, 'Oversized resource'):
                        assets.read_assets(source, self.wanted)

    def test_zip_symlink(self):
        entry = zipfile.ZipInfo('Windows/' + self.name)
        entry.create_system = 3
        entry.external_attr = (stat.S_IFLNK | 0o777) << 16
        with self.assertRaisesRegex(ValueError, 'Non-regular resource'):
            assets.read_assets(self.make_zip([(entry, b'outside')]), self.wanted)

    def test_tar_symlink(self):
        path = self.root / 'resources.tar.gz'
        with tarfile.open(path, 'w:gz') as archive:
            info = tarfile.TarInfo('Windows/' + self.name)
            info.type = tarfile.SYMTYPE
            info.linkname = 'outside'
            archive.addfile(info)
        with self.assertRaisesRegex(ValueError, 'Non-regular resource'):
            assets.read_assets(path, self.wanted)

    def test_directory_escape(self):
        source = self.root / 'source'
        path = source / self.name
        path.parent.mkdir(parents=True)
        outside = self.root / 'outside'
        outside.write_bytes(self.content)
        path.symlink_to(outside)
        with self.assertRaisesRegex(ValueError, 'outside input directory'):
            assets.read_assets(source, self.wanted)

    def test_source_manifest(self):
        self.assertEqual(assets.source_manifest({self.name: self.content}), {
            self.name: {'sha256': hashlib.sha256(self.content).hexdigest(),
                        'bytes': len(self.content)}
        })


if __name__ == '__main__':
    unittest.main()
