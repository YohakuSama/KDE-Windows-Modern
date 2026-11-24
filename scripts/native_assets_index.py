# SPDX-License-Identifier: GPL-3.0-or-later
"""Consume a previously extracted resource index without re-extracting its ICOs."""
import hashlib
import json
from pathlib import PurePosixPath

from native_assets_input import read_assets, read_resource, source_manifest


def checked_path(root, relative):
    rel = PurePosixPath(relative)
    if rel.is_absolute() or '..' in rel.parts or not rel.parts:
        raise ValueError('Unsafe indexed path: ' + relative)
    path = root / relative
    if not path.resolve().is_relative_to(root.resolve()) or not path.is_file():
        raise ValueError('Missing or external indexed file: ' + relative)
    return path


def read_checked(root, relative, sha256):
    path = checked_path(root, relative)
    with path.open('rb') as stream:
        content = read_resource(stream, path.stat().st_size, relative)
    if hashlib.sha256(content).hexdigest() != sha256:
        raise ValueError('Indexed file hash mismatch: ' + relative)
    return content


class IndexedResources:
    def __init__(self, root):
        self.root = root.resolve()
        path = checked_path(self.root, 'resource-manifest.json')
        with path.open('rb') as stream:
            raw = read_resource(stream, path.stat().st_size, 'resource-manifest.json')
        self.index = json.loads(raw)
        self.manifest_sha256 = hashlib.sha256(raw).hexdigest()
        self.originals = {}
        for entry in self.index['original_files']:
            relative = entry['path']
            if relative in self.originals:
                raise ValueError('Duplicate indexed original: ' + relative)
            self.originals[relative] = entry
        self.groups = {}
        for group in self.index['groups']:
            key = (group['module'], group['group_id'], group['language_id'])
            if key in self.groups:
                raise ValueError('Duplicate indexed icon group: ' + str(key))
            self.groups[key] = group

    def read_originals(self, wanted):
        original = (self.root / 'original' / 'Windows').resolve()
        if not original.is_relative_to(self.root):
            raise ValueError('Original directory is outside resource checkout')
        data = read_assets(original, wanted)
        for name, actual in source_manifest(data).items():
            path = 'original/Windows/' + name
            entry = self.originals.get(path)
            if entry is None or entry['sha256'] != actual['sha256'] or entry['size_bytes'] != actual['bytes']:
                raise ValueError('Indexed original mismatch: ' + path)
        return data

    def numeric_group_ids(self, module):
        return sorted({key[1] for key in self.groups
                       if key[0] == module and isinstance(key[1], int)})

    def preview(self, module, group_id):
        keys = sorted(key for key in self.groups
                      if key[:2] == (module, group_id))
        if not keys:
            raise ValueError(f'Missing indexed group: {module}:{group_id}')
        group = self.groups[keys[0]]
        path = group['preview_png']
        frame = next((f for f in group['frames'] if f['png'] == path), None)
        if frame is None:
            raise ValueError('Preview is not a frame in its indexed group')
        rel = PurePosixPath(path)
        if rel.parts[:2] != ('png', module) or rel.suffix != '.png':
            raise ValueError('Unexpected preview path: ' + path)
        content = read_checked(self.root, path, frame['png_sha256'])
        return content, (frame['width'], frame['height'])
