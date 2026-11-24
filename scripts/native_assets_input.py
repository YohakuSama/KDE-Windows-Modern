# SPDX-License-Identifier: GPL-3.0-or-later
"""Read selected Windows resources without extracting archive members."""
import hashlib
from pathlib import PurePosixPath
import stat
import tarfile
import zipfile

MAX_RESOURCE_BYTES = 64 * 1024 * 1024


def resource_name(path, wanted):
    parts = PurePosixPath(path).parts
    if 'Windows' in parts:
        name = '/'.join(parts[parts.index('Windows') + 1:])
    else:
        name = '/'.join(parts)
    if name not in wanted:
        return None
    if '..' in parts or PurePosixPath(path).is_absolute():
        raise ValueError('Unsafe member path: ' + path)
    return name


def read_resource(stream, size, name):
    if size < 0 or size > MAX_RESOURCE_BYTES:
        raise ValueError('Oversized resource: ' + name)
    content = stream.read(size + 1)
    if len(content) != size:
        raise ValueError('Incorrect resource size: ' + name)
    return content


def read_assets(source, wanted):
    data = {}

    def add(name, size, stream):
        if name in data:
            raise ValueError('Duplicate resource: ' + name)
        data[name] = read_resource(stream, size, name)

    if source.is_dir():
        root = (source / 'Windows' if (source / 'Windows').is_dir() else source).resolve()
        for name in sorted(wanted):
            path = root / name
            if not path.resolve().is_relative_to(root):
                raise ValueError('Resource outside input directory: ' + name)
            if path.is_file():
                with path.open('rb') as stream:
                    add(name, path.stat().st_size, stream)
    elif zipfile.is_zipfile(source):
        with zipfile.ZipFile(source) as archive:
            for member in archive.infolist():
                name = resource_name(member.filename, wanted)
                if name is None:
                    continue
                mode = member.external_attr >> 16
                if member.is_dir() or stat.S_IFMT(mode) not in (0, stat.S_IFREG):
                    raise ValueError('Non-regular resource: ' + name)
                with archive.open(member) as stream:
                    add(name, member.file_size, stream)
    else:
        with tarfile.open(source, 'r|*') as archive:
            for member in archive:
                name = resource_name(member.name, wanted)
                if name is None:
                    continue
                if not member.isfile():
                    raise ValueError('Non-regular resource: ' + name)
                with archive.extractfile(member) as stream:
                    add(name, member.size, stream)
    missing = wanted - data.keys()
    if missing:
        raise ValueError('Missing resources: ' + ', '.join(sorted(missing)))
    return data


def source_manifest(data):
    return {name: {'sha256': hashlib.sha256(content).hexdigest(), 'bytes': len(content)}
            for name, content in sorted(data.items())}
