# SPDX-License-Identifier: GPL-3.0-or-later
"""Consume a previously extracted resource index without re-extracting its ICOs."""
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys

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


# The runtime branch reuses this exact full reference index for provenance.
REFERENCE_INDEX_BLOB = '93ffe12063b7c03ac964b4feb40c7174f581fc5b'


def verify_reference_index(raw):
    blob = hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()
    if blob != REFERENCE_INDEX_BLOB:
        raise ValueError('Resource index differs from reviewed reference')


def mapped_original_names(mapping, indexed=True):
    wanted = {'Fonts/SegoeIcons.ttf'}
    wanted.update(name for _, _, light, dark in mapping['wallpapers']
                  for name in (light, dark) if name)
    wanted.update('Media/' + name + '.wav' for name in mapping['sounds'])
    if not indexed:
        wanted.update('SystemResources/' + name for name in mapping['libraries'].values())
    return wanted


def selected_preview(group):
    path = group['preview_png']
    frame = next((f for f in group['frames'] if f['png'] == path), None)
    if frame is None:
        raise ValueError('Preview is not a frame in its indexed group')
    rel = PurePosixPath(path)
    if (rel.parts[:2] != ('png', group['module']) or rel.suffix != '.png'
            or '..' in rel.parts):
        raise ValueError('Unexpected preview path: ' + path)
    return frame


def mapped_resource_entries(index, mapping):
    """Exact files read by the indexed importer: relative path -> (hash, size)."""
    entries = {}

    def add(path, digest, size=None):
        rel = PurePosixPath(path)
        if (not rel.parts or rel.is_absolute() or '..' in rel.parts
                or not re.fullmatch(r'[0-9a-f]{64}', digest)):
            raise ValueError('Invalid indexed resource: ' + path)
        value = (digest, size)
        if path in entries and entries[path] != value:
            raise ValueError('Conflicting indexed resource: ' + path)
        entries[path] = value

    originals = {'original/Windows/' + n for n in mapped_original_names(mapping)}
    for entry in index['original_files']:
        if entry['path'] in originals:
            add(entry['path'], entry['sha256'], entry['size_bytes'])
    if not originals.issubset(entries):
        raise ValueError('Missing mapped originals in index: ' + ', '.join(sorted(originals - entries.keys())))
    groups = {}
    for group in index['groups']:
        key = (group['module'], group['group_id'], group['language_id'])
        if key in groups:
            raise ValueError('Duplicate indexed icon group: ' + str(key))
        groups[key] = group
    for source in mapping['icons']:
        if ':' not in source:
            continue
        lib, group_id = source.split(':', 1)
        keys = sorted(key for key in groups
                      if key[:2] == (mapping['libraries'][lib], int(group_id)))
        if not keys:
            raise ValueError('Missing indexed group: ' + source)
        frame = selected_preview(groups[keys[0]])
        add(frame['png'], frame['png_sha256'])
    return entries


def verify_runtime_directory(root, mapping, pin):
    if root.is_symlink() or any(p.is_symlink() for p in root.rglob('*')):
        raise ValueError('Unexpected symlink in runtime resources')
    if checked_path(root, 'RESOURCE-COMMIT').read_text().strip() != pin:
        raise ValueError('Runtime resource revision mismatch')
    raw = checked_path(root, 'resource-manifest.json').read_bytes()
    verify_reference_index(raw)
    entries = mapped_resource_entries(json.loads(raw), mapping)
    expected = set(entries) | {'resource-manifest.json', 'RESOURCE-COMMIT'}
    actual = {p.relative_to(root).as_posix() for p in root.rglob('*')
              if p.is_file() or p.is_symlink()}
    if actual != expected:
        raise ValueError('Runtime resource file list mismatch: missing ' +
                         str(sorted(expected - actual)) + ', extra ' + str(sorted(actual - expected)))
    for name, (digest, size) in entries.items():
        content = read_checked(root, name, digest)
        if size is not None and len(content) != size:
            raise ValueError('Indexed resource size mismatch: ' + name)
    return len(entries)


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
        frame = selected_preview(group)
        content = read_checked(self.root, frame['png'], frame['png_sha256'])
        return content, (frame['width'], frame['height'])


if __name__ == '__main__':
    if len(sys.argv) != 4:
        raise SystemExit('usage: native_assets_index.py MAPPING RUNTIME_DIRECTORY PIN')
    try:
        mapping = json.loads(Path(sys.argv[1]).read_text())
        count = verify_runtime_directory(Path(sys.argv[2]), mapping, sys.argv[3])
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise SystemExit('Runtime resource verification failed: ' + str(exc))
    print(f'Verified {count} mapped theme resources')
