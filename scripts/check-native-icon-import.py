#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the complete local mapped icon set before replacing the installed theme."""
import hashlib
import json
from pathlib import Path
import sys


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_import(root, mapping_file):
    root = root.resolve()
    mapping_bytes = mapping_file.read_bytes()
    mapping = json.loads(mapping_bytes)
    manifest = json.loads((root / 'manifest.json').read_text(encoding='utf-8'))
    if manifest.get('mapping_sha256') != hashlib.sha256(mapping_bytes).hexdigest():
        raise ValueError('Local icon mapping is older than the theme checkout')
    optional = set(mapping.get('optional_glyphs', []))
    omitted = set(manifest.get('missing_optional_glyphs', []))
    if not omitted <= optional:
        raise ValueError('Unexpected omitted icon role')
    expected = {
        'icons/' + target + '.svg': source
        for source, targets in mapping['icons'].items() if source not in omitted
        for target in targets.split()
    }
    outputs = {path: value for path, value in manifest['outputs'].items()
               if path.startswith('icons/')}
    if set(outputs) != set(expected):
        raise ValueError('Local icon output list differs from the current mapping')
    actual = {p.relative_to(root).as_posix() for p in (root / 'icons').rglob('*')
              if p.is_file() or p.is_symlink()}
    if actual != set(expected):
        raise ValueError('Local icon directory has missing or unlisted files')
    for relative, source in expected.items():
        info = outputs[relative]
        path = root / relative
        if (not path.resolve().is_relative_to(root) or path.is_symlink()
                or not path.is_file() or info['source'] != source
                or info['sha256'] != digest(path)):
            raise ValueError('Local icon mismatch: ' + relative)
    return len(expected), sorted(omitted)


def main():
    try:
        count, omitted = verify_import(Path(sys.argv[1]), Path(sys.argv[2]))
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f'Native icon preflight: {exc}', file=sys.stderr)
        return 1
    print(f'Native icon preflight: {count} verified mapped SVGs')
    if omitted:
        print('Optional glyphs absent from owner font: ' + ', '.join(omitted))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
